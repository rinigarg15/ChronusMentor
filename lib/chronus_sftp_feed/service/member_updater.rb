module ChronusSftpFeed
  module Service
    class MemberUpdater < ChronusSftpFeed::Service::BaseUpdater
      module ProfileFields
        EDUCATION = [:school_name, :degree, :major, :graduation_year]
        EXPERIENCE = [:job_title, :company, :start_month, :start_year, :end_month, :end_year, :current_job]
      end

      def initialize(config, options = {})
        super(config, options)
        initialize_mapping
      end

      private

      def update_record(record, record_index)
        primary_key = get_primary_key(record)
        member = @members_map[primary_key]

        begin
          raise "Primary key missing" if primary_key.blank?
          raise "Duplicate record" if @duplicate_keys.include?(primary_key)

          if member.present?
            unless @config.prevent_name_override
              member.first_name = record[ChronusSftpFeed::Constant::FIRST_NAME]
              member.last_name = record[ChronusSftpFeed::Constant::LAST_NAME]
            end
            member.email = record[ChronusSftpFeed::Constant::EMAIL]
            save_record!(member, build_login_identifiers(record, member))
          else
            member = @organization.members.new(
              first_name: record[ChronusSftpFeed::Constant::FIRST_NAME],
              last_name: record[ChronusSftpFeed::Constant::LAST_NAME],
              email: record[ChronusSftpFeed::Constant::EMAIL],
              state: Member::Status::DORMANT,
              imported_at: Time.now
            )
            build_login_identifiers(record, member)
            member.save!
            @created = true

            if @config.allow_import_question && @imported_profile_question
              profile_answer = member.profile_answers.build(profile_question: @imported_profile_question)
              profile_answer.answer_value = ChronusSftpFeed::Constant::IMPORT_QUESTION_ANSWER
              save_record!(profile_answer)
            end
          end

          if member.present?
            handle_suspend_and_reactivate(record, member)
          end
        rescue => error
          if error.message == "Primary key missing"
            @error_data << [record_index, "#{primary_key}", "", "", "#{@config.primary_key_header} - #{error.message}"]
            ChronusSftpFeed::Migrator.logger "#{@error_data.last.join(", ")}\n"
          elsif member.present? && member.errors.count > 0
            member.errors.messages.each do |field, message_array|
              message_array.each do |error_message|
                @error_data << [record_index, "#{primary_key}", Member.human_attribute_name(field), member[field], member.errors.full_message(field, error_message)]
                ChronusSftpFeed::Migrator.logger "#{@error_data.last.join(", ")}\n"
              end
            end
          else
            @error_data << [record_index, "#{primary_key}", "", "", error.message.gsub(/Validation failed: /,'')]
            ChronusSftpFeed::Migrator.logger "#{@error_data.last.join(", ")}\n"
          end
        end

        # checking member.id instead of member (if we are creating new member and member creation fails, then member will be present but with a nil id. we dont want to update profile_answers in that case)
        if member.present? && member.id.present?
          update_profile_answers(member, record, record_index)
          import_user_tags(member, record, record_index) if @config.allow_user_tags_import?(@header)
          push_logger_data(member, record_index)
        end
      end

      def import_user_tags(member, record, record_index)
        begin
          program_root = get_mapped_value(record, @config.program_name_header)
          program = @program_root_map[program_root]
          return unless program.present?

          user = @user_member_map[member.id].find {|user| user.program_id == program.id} if @user_member_map[member.id].present?
          return unless user.present?

          user.tag_list = record[@config.user_tags_header]
          user.save!
        rescue => error
          @error_data << [record_index, "#{record[@config.primary_key_header]}", "#{@config.user_tags_header}", "#{record[@config.user_tags_header]}", error.message.gsub(/Validation failed: /,'')]
          ChronusSftpFeed::Migrator.logger "#{@error_data.last.join(", ")}\n"
        end
      end

      def update_profile_answers(member, record, record_index)
        @questions_map.each do |key, question|
          begin
            if question.education?
              update_educations(record, member, question)
            elsif question.experience?
              update_experiences(record, member, question)
            elsif question.publication?
              # TODO
            else
              update_answer(record, member, question)
            end
          rescue => error
            @error_data << [record_index, "#{record[@config.primary_key_header]}", "#{key}", "#{record[key]}", error.message.gsub(/Validation failed: /,'')]
            ChronusSftpFeed::Migrator.logger "#{@error_data.last.join(", ")}\n"
          end
        end
      end

      def initialize_questions_map
        @questions_map = {}
        profile_questions = @organization.profile_questions.joins(:translations).includes(question_choices: :translations).where("profile_question_translations.question_text IN (?) AND question_type NOT IN (?) AND profile_question_translations.locale = ?", @header + @config.supplement_questions_map.keys, @config.secondary_questions_map.keys, I18n.default_locale.to_s)
        profile_questions.each do |question|
          @questions_map[question.question_text] = question
        end
        profile_questions
      end

      def initialize_answers_map(member_ids, profile_questions)
        @answers_map = {}
        PerfUtils.table_for_join("temp_members", member_ids) do |temp_table|
          answers_scope = ProfileAnswer.includes(:answer_choices).joins("RIGHT JOIN #{temp_table} ON profile_answers.ref_obj_id = #{temp_table}.id").where(ref_obj_type: Member.name, profile_question_id: profile_questions.collect(&:id))
          answers_scope.find_each do |answer|
            @answers_map[answer.ref_obj_id] = @answers_map[answer.ref_obj_id] || {}
            @answers_map[answer.ref_obj_id][answer.profile_question_id] = answer
          end
        end
      end

      def initialize_mapping
        members_scope = initialize_members_map
        member_ids = members_scope.map(&:id)
        profile_questions = initialize_questions_map
        initialize_answers_map(member_ids, profile_questions)

        if @config.allow_import_question
          @imported_profile_question = @organization.profile_questions.joins(:translations).
            where("profile_question_translations.question_text = ? AND locale = ?", @config.import_question_text, I18n.default_locale.to_s).first
        end

        if @config.allow_user_tags_import?(@header)
          @program_root_map = @organization.programs.index_by(&:root)
          @user_member_map = User.where(program_id: @organization.program_ids, member_id: member_ids).group_by(&:member_id)
        end
      end

      def update_educations(record, member, question)
        multi_educations = record[question.question_text].split(ChronusSftpFeed::Constant::MULTIPLE_ANSWER_DELIMITER).collect {|education| education.split(",")}

        education_answers = {}
        ProfileFields::EDUCATION.each_with_index do |field, index|
          education_answers[field] = multi_educations.collect{|fields| fields[index].to_s.strip}
        end

        profile_answer = (@answers_map[member.id] && @answers_map[member.id][question.id])
        if education_answers[:school_name].present? && education_answers[:school_name].any?(&:present?)
          @first_valid_year ||= ProfileConstants.valid_graduation_years.first
          profile_answer ||= member.profile_answers.build(profile_question: question)

          education_answers[:school_name].each_with_index do |_, index|
            options = {}
            education_answers.each{|key, values| options[key] = values[index] }
            if options[:school_name].present?
              options[:graduation_year] = @first_valid_year if options[:graduation_year].present? && options[:graduation_year] != "0" && options[:graduation_year].to_i < @first_valid_year
              education = profile_answer.educations.where(school_name: options[:school_name]).find{|education| education.degree.to_s.strip == options[:degree]}
              education ||= profile_answer.educations.build
              education.attributes = options
              education.profile_answer = profile_answer
              save_record!(education)
            end
            save_record!(profile_answer)
          end
          if profile_answer.present?
            educations = profile_answer.educations
            educations_to_destroy = []
            educations.each do |education|
              do_not_destroy = false
              education_answers[:school_name].each_with_index do |_, index|
                do_not_destroy ||= [:school_name, :degree].all? {|field| education_answers[field][index] == education.send(field).to_s.strip}
              end
              educations_to_destroy << education unless do_not_destroy
            end

            if educations_to_destroy.size > 0
              educations_to_destroy.collect(&:destroy)
              @updated = true
            end
          end
        elsif profile_answer.present?
          profile_answer.destroy
          @updated = true
        end
      end

      def update_experiences(record, member, question)
        multi_experiences = record[question.question_text].split(ChronusSftpFeed::Constant::MULTIPLE_ANSWER_DELIMITER).collect {|experience| experience.split(",")}

        experience_answers = {}
        ProfileFields::EXPERIENCE.each_with_index do |field, index|
          experience_answers[field] = multi_experiences.collect{|fields| fields[index].to_s.strip}
        end

        profile_answer = (@answers_map[member.id] && @answers_map[member.id][question.id])
        if experience_answers[:company].present? && experience_answers[:company].any?(&:present?)
          @first_valid_year ||= ProfileConstants.valid_years.first
          profile_answer ||= member.profile_answers.build(profile_question: question)

          experience_answers[:company].each_with_index do |_, index|
            options = {}
            experience_answers.each{|key, values| options[key] = values[index] }
            if options[:company].present?
              options[:start_year] = @first_valid_year if options[:start_year].present? && options[:start_year] != "0" && options[:start_year].to_i < @first_valid_year
              options[:start_month] = options[:start_month].presence || 0
              options[:end_month] = options[:end_month].presence || 0
              experience = profile_answer.experiences.where(company: options[:company], start_year: options[:start_year].presence, start_month: options[:start_month]).find{|exp| exp.job_title.to_s.strip == options[:job_title]}
              experience ||= profile_answer.experiences.build
              experience.attributes = options
              experience.profile_answer = profile_answer
              save_record!(experience)
            end
            save_record!(profile_answer)
          end
          destroy_not_applicable_experiences(profile_answer, experience_answers)
        elsif profile_answer.present?
          profile_answer.destroy
          @updated = true
        end
      end

      def destroy_not_applicable_experiences(profile_answer, experience_answers)
        return unless profile_answer.present?
        experiences_to_destroy = []
        profile_answer.experiences.each do |experience|
          do_not_destroy = false
          experience_answers[:company].each_with_index do |_, index|
            do_not_destroy ||= is_newly_created_experience?(experience, experience_answers, index)
          end
          experiences_to_destroy << experience unless do_not_destroy
        end
        return if experiences_to_destroy.empty?
        experiences_to_destroy.collect(&:destroy)
        @updated = true
      end

      def is_newly_created_experience?(experience, experience_answers, index)
        [:company, :job_title, :start_month, :start_year].all? do |field|
          new_value = experience_answers[field][index]
          value_from_db = experience.send(field)
          if field.in?([:start_month, :start_year])
            new_value.presence.try(:to_i) == value_from_db
          else
            new_value == value_from_db.to_s.strip
          end
        end
      end

      def update_answer(record, member, question)
        answer_value = get_mapped_value(record, question.question_text)
        profile_answer = (@answers_map[member.id] && @answers_map[member.id][question.id])
        return if profile_answer.blank? && answer_value.blank?

        profile_answer ||= member.profile_answers.build(profile_question: question)
        answer_value = answer_value.split(",") if question.question_type == ProfileQuestion::Type::MULTI_STRING
        profile_answer.answer_value = { answer_text: answer_value, question: question, from_import: true }
        profile_answer.handle_date_answer(question, answer_value)
        save_record!(profile_answer)
      end

      def build_login_identifiers(record, member)
        return if @config.login_identifier_header.blank?

        identifier = record[@config.login_identifier_header]
        return if identifier.blank?

        member.build_login_identifiers_for_custom_auths(identifier)
        member.login_identifiers.any?(&:changed?)
      end

      def can_suspend_member_based_on_logic_map?(record, member)
        return false if member.suspended?
        return false if @config.suspend_logic_map.blank?
        return false if record[@config.suspend_logic_map.keys.first].blank?
        return @config.suspend_logic_map.values.first.include?(record[@config.suspend_logic_map.keys.first])
      end

      def can_reactivate_member_based_on_logic_map?(record, member)
        return false unless member.suspended?
        return false if @config.reactivate_logic_map.blank?
        return false if record[@config.reactivate_logic_map.keys.first].blank?
        return @config.reactivate_logic_map.values.first.include?(record[@config.reactivate_logic_map.keys.first])
      end

      def handle_suspend_and_reactivate(record, member)
        if can_suspend_member_based_on_logic_map?(record, member)
          member.suspend!(@config.mentor_admin, "Suspended by #{@config.custom_term_for_admin}")
          @suspended = true
        elsif can_reactivate_member_based_on_logic_map?(record, member)
          member.reactivate!(@config.mentor_admin, false)
          @updated = true
        elsif @config.reactivation_required? && member.suspended?
          @updated = true
        end
      end
    end
  end
end