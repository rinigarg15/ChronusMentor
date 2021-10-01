require_relative './../../custom_sql_query.rb'
require_relative './../cache/refresh.rb'

module Matching
  FIELDS = CustomSqlQuery::SelectColumns::ANSWER_MAP
  #
  # Provides services for keeping the matching data store updated with changes
  # to the application data
  #
  class Indexer
    class << self

      def perform_program_delta_index(program_id)
        program = Matching.fetch_program(program_id)
        return [[], []] unless program.present?

        mentor_documents = {}
        student_documents = {}

        MatchingDocument.where(program_id: program_id).each do |document|
          if document.mentor?
            mentor_documents.merge!(document.record_id => document)
          else
            student_documents.merge!(document.record_id => document)
          end
        end
        return index_users(mentor_documents, student_documents, program)
      end

      def perform_users_delta_index(user_ids, program_id, options = {})
        program, users = Matching.fetch_program_and_users(user_ids, program_id)
        return unless program.present?

        user_ids_for_cache_refresh = []
        users.find_each do |user|
          perform_cache_refresh = perform_user_delta_index(user, options)
          user_ids_for_cache_refresh << user.id if perform_cache_refresh
        end
        return user_ids_for_cache_refresh
      end

      def get_index_by_answer(index_data)
        index_data.group_by{|data| data[FIELDS["profile_answers.id"]]}
      end

      def process_each_pair!(index_by_answer, new_data_fields = [], options = {})
        index_by_answer.each_pair do |_answer_id, profile_answer_data|
          answer_data, question_type, question_text, mentor_question_id, student_question_id = get_common_data(profile_answer_data[0])
          if((mentor_question_id && student_question_id) || options[:supplementary_matching_pair])
            if question_type == ProfileQuestion::Type::LOCATION
              add_location_field(new_data_fields, question_text, answer_data)
            elsif [ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION].include?(question_type)
              add_education_field(new_data_fields, question_text, profile_answer_data)
            elsif [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE].include?(question_type)
              add_experience_field(new_data_fields, question_text, profile_answer_data)
            else
              add_other_fields(new_data_fields, question_type, question_text, profile_answer_data, answer_data)
            end
          end
        end
      end

      private

      # Convert array of data_field object to array of hash of elements to store in db
      def modify_data_fields_for_storing(data_fields)
        data_fields.collect do |data_field|
          { name: data_field.name, value: Matching::AbstractType.to_mysql_type(data_field.value) }
        end
      end

      def index_users(mentor_documents, student_documents, program)
        mentor_role_id = program.get_role(RoleConstants::MENTOR_NAME).id
        student_role_id = program.get_role(RoleConstants::STUDENT_NAME).id
        mentor_ids = refresh_users_documents(mentor_documents, RoleConstants::MENTOR_NAME, program, mentor_role_id, true)
        student_ids = refresh_users_documents(student_documents, RoleConstants::STUDENT_NAME, program, student_role_id, false)
        return [mentor_ids, student_ids]
      end

      #
      # documents - mongodb documents hash
      # role_name - RoleConstants::MENTOR_NAME or RoleConstants::STUDENT_NAME
      # program_id - program id
      # is_mentor - true or false
      #
      def refresh_users_documents(documents, role_name, program, role_id, is_mentor = false)
        program_id = program.id
        manager_tree = {}
        manager_tree = compute_managers_tree(program) if program.prevent_manager_matching && !is_mentor # When manager feature is disabled
        past_mentors = compute_past_matches(program) if program.prevent_past_mentor_matching && !is_mentor

        index_data_query = CustomSqlQuery::INDEX_DATA.call(CustomSqlQuery::SelectColumns::ANSWERS_FIELDS, program_id, role_name, role_id)
        # This below statement will fetch users.id and users.member_id in an array as mentioned below
        # eg. [[1,2], [2,3] ..]
        # data[0] is users.id, so, fundamentally(since "basically" is a cliche:) ) group_by user_id
        index_data = ActiveRecord::Base.connection.execute(index_data_query).to_a.group_by { |data| data[FIELDS["users.id"]] }
        index_data.each_pair do |user_id, user_data|
          document = documents[user_id]
          document ||= MatchingDocument.new(record_id: user_id, program_id: program_id, mentor: is_mentor)
          refresh_document_raw(document, user_id, user_data, is_mentor, manager_tree, past_mentors, program)
        end
        return index_data.keys
      end

      def refresh_document_raw(document, user_id, index_data, is_mentor, manager_tree, past_mentors, program)
        new_data_fields = []
        index_by_answer = get_index_by_answer(index_data)
        process_each_pair!(index_by_answer, new_data_fields)

        if program.prevent_manager_matching
          managee_id = index_data.first[FIELDS["users.member_id"]].to_i
          manager_value = is_mentor ? managee_id : manager_tree[managee_id]
          new_data_fields << get_manager_datafield(program, is_mentor, manager_value)
        end

        if program.prevent_past_mentor_matching
          user_id = index_data.first[FIELDS["users.id"]].to_i
          past_mentors_value = is_mentor ? user_id : (past_mentors[user_id].presence || [])
          new_data_fields << get_past_mentors_datafield(program, is_mentor, past_mentors_value)
        end

        # Set new data fields for the document. 
        document.data_fields = modify_data_fields_for_storing(new_data_fields)
        document.save!
      end

      #
      # Refresh the document corresponding to the +user+ for mentor/student role
      # based on +is_mentor+, where +questions+ gives the
      #
      # Params: *<tt>user</tt>: the User whose matching document must be
      # refreshed *<tt>is_mentor</tt>: whether to refresh mentor or student role
      # document of the User *<tt>questions</tt>: Array of questions, whose
      # answers by +user+ should be used for indexing.
      #
      def refresh_user(user, is_mentor, questions)
        document = MatchingDocument.find_or_initialize_by(:program_id => user.program.id, :mentor => is_mentor, :record_id => user.id)

        refresh_document(document, user, questions)
      end

      #
      # Refresh the given +document+ with the new answers.
      #
      # Params: *<tt>user</tt>: the User whose matching document must be
      # refreshed *<tt>is_mentor</tt>: whether to refresh mentor or student role
      # document of the User *<tt>questions</tt>: Array of questions, whose
      # answers by +user+ should be used for indexing.
      #
      def refresh_document(document, user, profile_questions)
        new_data_fields = []

        all_qusetion_id_ans_map = {}
        user.member.profile_answers.each do |answer|
          all_qusetion_id_ans_map[answer.profile_question_id] = answer
        end

        question_answer_map = {}
        profile_questions.each do |question|
          value = all_qusetion_id_ans_map[question.id]
          next unless value

          question_answer_map[question] = value
        end

        # Add all answers by the user for the questions in the match
        # configuration.
        question_answer_map.each_pair do |question, answer|
          if question.location?
            new_data_fields << Matching::Persistence::DataField.construct_from_field_spec(
              [RoleQuestion, question.question_text],
              Matching::ChronusLocation.new(
                [answer.location.try(:lat), answer.location.try(:lng)]
              )
            )
          elsif question.education?
            edu_answers = answer.educations
            new_data_fields << Matching::Persistence::DataField.construct_from_field_spec(
            [RoleQuestion, question.question_text],
            Matching::ChronusEducations.new(
              edu_answers.collect{|edu|
              {:school_name => remove_braces_and_downcase(edu.school_name), :major => remove_braces_and_downcase(edu.major)}}
              )
            )
          elsif question.experience?
            exp_answers = answer.experiences
            new_data_fields << Matching::Persistence::DataField.construct_from_field_spec(
            [RoleQuestion, question.question_text],
            Matching::ChronusExperiences.new(
              exp_answers.collect{|exp|
              {:job_title => remove_braces_and_downcase(exp.job_title), :company => remove_braces_and_downcase(exp.company)}}
              )
            )
          else
            answer = answer.answer_value
            if answer.present?
              answer = answer.is_a?(String) ? remove_braces_and_downcase(answer) : (answer.is_a?(Array) ? answer.map{|ele| remove_braces_and_downcase(ele)} : answer)
            end
            new_data_fields << Matching::Persistence::DataField.construct_from_field_spec(
              [RoleQuestion, question.question_text],
              RoleQuestion::MatchType.match_type_for(question.question_type).new(answer)
            )
          end
        end

        if user.program.prevent_manager_matching
          managee_id = user.member_id
          if user.is_mentor?
            manager_value = managee_id
            new_data_fields << get_manager_datafield(user.program, user.is_mentor?, manager_value)
          end
          if user.is_student?
            manager_value = get_manager_tree(managee_id, user.program.manager_matching_level)
            new_data_fields << get_manager_datafield(user.program, !user.is_student?, manager_value)
          end
        end

        if user.program.prevent_past_mentor_matching
          user_id = user.id
          if user.is_mentor?
            past_mentors_value = user_id
            new_data_fields << get_past_mentors_datafield(user.program, user.is_mentor?, past_mentors_value)
          end
          if user.is_student?
            past_mentors_value = get_past_mentors(user_id)
            new_data_fields << get_past_mentors_datafield(user.program, !user.is_student?, past_mentors_value)
          end
        end

        # Set new data fields for the document.
        document.data_fields = modify_data_fields_for_storing(new_data_fields) 
        document.save!
      end

      # Removes all braces if any before matching the text
      def remove_braces_and_downcase(text)
        text.present? ? text.remove_braces_and_downcase : text
      end

      def get_indexed_answer(answer_text, question_type)
        answer_val =
          (if question_type == ProfileQuestion::Type::MULTI_STRING
            (answer_text || "").split(ProfileAnswer::MULTILINE_SEPERATOR)
          else
            answer_text
          end)
        answer_val
      end

      def compute_managers_tree(program)
        managers_hash = get_manager_hash(program)
        managers_hash.keys.inject(Hash.new([])) do |manager_tree, managee_id|
          manager_tree[managee_id] = get_manager_tree(managee_id, program.manager_matching_level, managers_hash)
          manager_tree
        end
      end

      def get_manager_hash(program)
        manager_scope= user_manager_scope.where("users.program_id = ?", program.id)
        ActiveRecord::Base.connection.select_all(manager_scope).inject({}) do |hash, entry|
          hash[entry["managee_id"]] = entry["manager_id"]
          hash
        end
      end

      def get_manager_tree(member_id, max_level, managers_hash=false)
        get_manager_tree_rec(member_id, max_level, 0, managers_hash, [])
      end

      def get_manager_tree_rec(member_id, max_level, cur_level, managers_hash, parent_array)
        return parent_array if max_level == cur_level
        if managers_hash
          manager_id = managers_hash[member_id]
        else
          manager_id = user_manager_scope.where("users.member_id = ?", member_id).first.try(:manager_id)
        end
        if manager_id.nil? || parent_array.include?(manager_id)
          parent_array
        else
          parent_array += [manager_id]
          get_manager_tree_rec(manager_id, max_level, cur_level+1, managers_hash, parent_array)
        end
      end

      def user_manager_scope
        ProfileQuestion.joins(:role_questions => {:role => {:users => {:profile_answers => :manager}}}).where("profile_questions.question_type = ?", ProfileQuestion::Type::MANAGER).select("users.member_id as managee_id, managers.member_id as manager_id")
      end

      # Computes hash of past mentors list for every student
      #{ student1_id => [mentor1_id, mentor2_id], student2_id => [mentor2_id]}
      def compute_past_matches(program)
        mentors_list = {}
        mentors_list.default = []
        user_ids = program.users.pluck(:id)

        mentors_list_of_users = Connection::MenteeMembership.select('connection_memberships.user_id, GROUP_CONCAT(mentor_memberships_groups.user_id) as mentor_ids').joins(:group => :mentor_memberships).where(:user_id => user_ids).where("groups.status = ? ", Group::Status::CLOSED).where("groups.program_id = ? ", program.id).group('connection_memberships.user_id')

        mentors_list_of_users.each do |membership|
          mentors_list[membership.user_id] = mentors_list[membership.user_id] + membership.mentor_ids.split(",").map(&:to_i)
        end
        mentors_list
      end

      # Fetches past mentors list for a particular student
      def get_past_mentors(user_id)
        User.find(user_id).studying_groups.closed.collect(&:mentor_ids).flatten
      end

      # role is true if mentor and false if student
      def get_manager_datafield(program, role, manager_value)
        question_text = role ? "Manager Question Mentor" : "Manager Question Mentee"
        Matching::Persistence::DataField.construct_from_field_spec(
          [Manager, question_text], Matching::ChronusMisMatch.new(manager_value)
        )
      end

      # role is true if mentor and false if student
      def get_past_mentors_datafield(program, role, past_mentors_value)
        question_text = role ? "Past Mentors Question Mentor" : "Past Mentors Question Mentee"
        Matching::Persistence::DataField.construct_from_field_spec(
          [User, question_text], Matching::ChronusMisMatch.new(past_mentors_value)
        )
      end

      def matching_needed?(program, profile_questions_for_matching, updated_profile_question_ids)
        return true if updated_profile_question_ids.blank?
        profile_questions_for_matching += program.organization.profile_questions.manager_questions if program.prevent_manager_matching

        updated_profile_question_ids.collect!(&:to_i)
        return (profile_questions_for_matching.collect(&:id) & updated_profile_question_ids).any?
      end

      def get_common_data(profile_answer_data)
        answer_data = profile_answer_data
        question_type = answer_data[FIELDS["profile_questions.question_type"]]
        question_text = answer_data[FIELDS["profile_question_translations.question_text"]]
        mentor_question_id = answer_data[FIELDS["A_match_configs.mentor_question_id"]]
        student_question_id = answer_data[FIELDS["A_match_configs.student_question_id"]]
        [answer_data, question_type, question_text, mentor_question_id, student_question_id]
      end

      def add_location_field(new_data_fields, question_text, answer_data)
        new_data_fields << Matching::Persistence::DataField.construct_from_field_spec(
          [RoleQuestion, question_text], Matching::ChronusLocation.new([answer_data[FIELDS["locations.lat"]], answer_data[FIELDS["locations.lng"]]]))
      end

      def add_education_field(new_data_fields, question_text, profile_answer_data)
        edu_answers = profile_answer_data.collect{|edu| [edu[FIELDS["educations.school_name"]], edu[FIELDS["educations.major"]]].compact}.flatten
        edu_answer = (edu_answers.present? ? profile_answer_data.collect{|edu| 
          {:school_name => remove_braces_and_downcase(edu[FIELDS["educations.school_name"]]),
           :major => remove_braces_and_downcase(edu[FIELDS["educations.major"]])}
        } : [])
        new_data_fields << Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, question_text], Matching::ChronusEducations.new(edu_answer))
      end

      def add_experience_field(new_data_fields, question_text, profile_answer_data)
        exp_answers = profile_answer_data.collect{|exp| [exp[FIELDS["experiences.job_title"]], exp[FIELDS["experiences.company"]]].compact}.flatten
        exp_answer = (exp_answers.present? ?
          profile_answer_data.collect{|exp|
            {:job_title => remove_braces_and_downcase(exp[FIELDS["experiences.job_title"]]), :company => remove_braces_and_downcase(exp[FIELDS["experiences.company"]])}
          } : [])
        new_data_fields << Matching::Persistence::DataField.construct_from_field_spec(
          [RoleQuestion, question_text], Matching::ChronusExperiences.new(exp_answer)
        )
      end

      def add_other_fields(new_data_fields, question_type, question_text, profile_answer_data, answer_data)
        if ProfileQuestion::Type.choice_based_types.include?(question_type)
          answer_text = profile_answer_data.collect{|choice| choice[FIELDS["question_choice_translations.text"]]}.compact
        else
          answer_text = answer_data[FIELDS["profile_answers.answer_text"]]
        end
        answer = get_indexed_answer(answer_text, question_type)
        if answer.present?
          answer = get_answer(answer)
        end
        new_data_fields << Matching::Persistence::DataField.construct_from_field_spec(
          [RoleQuestion, question_text], RoleQuestion::MatchType.match_type_for(question_type).new(answer)
        )
      end

      def get_answer(answer)
        answer.is_a?(String) ? remove_braces_and_downcase(answer) : (answer.is_a?(Array) ? answer.map{|ele| remove_braces_and_downcase(ele)}.uniq : answer)
      end

      def perform_user_delta_index(user, options = {})
        return Matching.remove_user(user.id, user.program_id) if user.suspended? || !user.is_mentor_or_student?

        program = user.program
        match_configs = program.match_configs
        cache_refresh_needed = false
        if user.is_mentor?
          mentor_profile_questions = match_configs.collect(&:mentor_question).collect(&:profile_question)
          if matching_needed?(program, mentor_profile_questions, options[:profile_question_ids])
            refresh_user(user, true, mentor_profile_questions)
            cache_refresh_needed = true
          end
        end
        if user.is_student?
          student_profile_questions = match_configs.collect(&:student_question).collect(&:profile_question)
          if matching_needed?(program, student_profile_questions, options[:profile_question_ids])
            refresh_user(user, false, student_profile_questions)
            cache_refresh_needed = true
          end
        end
        return cache_refresh_needed
      end
    end
  end
end