require "populator"
require "faker"
class DataPopulator

  class << self
    def benchmark_wrapper(name)
      newline
      start_time = Time.now
      print_and_flush "[#{start_time.to_s}] Starting #{name}" 
      yield
      end_time = Time.now
      time_diff = end_time - start_time
      newline
      print_and_flush "[#{end_time.to_s}] Completed #{name} in #{formatted_populator_time_display(time_diff)}" 
      newline
    end

    def formatted_populator_time_display(elapsed_time)
      elapsed_time_to_i = elapsed_time.to_i
      h = elapsed_time_to_i / 3600
      m = (elapsed_time_to_i % 3600)/60
      s = elapsed_time_to_i % 60
      str = ""
      str += "#{h}h " if h > 0
      str += "#{m}m " if m > 0 || str.presence
      str += "#{s}s" if s > 0 || str.presence
      str = "0s" if str.length.zero?
      str
    end

    def print_and_flush(msg)
      print msg
      $stdout.flush
    end

    def printline_and_flush(msg)
      print_and_flush(msg)
      newline
    end

    def display_populated_count(count, object)
      newline
      print_and_flush("#{count} #{object} Populated") 
    end

    def display_deleted_count(count, object)
      newline
      print_and_flush("#{count} #{object} Deleted") 
    end

    def newline
      print_and_flush("\n") 
    end

    def dot
      print_and_flush(".") 
    end

    def pick_random_answer(question_choices, randomizer)
      question_choices.sample(randomizer.sample).uniq
    end

    def random_string(factor = 36)
      rand(36**factor).to_s(36)
    end

    def append_locale_to_string(string, locale)
      return "#{string} - #{locale}"
    end

    def lucky?
      [true, false].sample
    end

    def generate_random_question_info(random_number = 3..10)
      Populator.words(random_number).split(" ").uniq
    end

    def random_role_names
      [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].sample([1,2].sample)
    end

    def populate_default_contents(program)
      if program.is_a?(Program)
        # create default contents( have been removed from program observer)
        create_default_forums(program) unless program.forums.present?
        create_default_surveys(program) unless (program.surveys.of_engagement_type.present? ||  program.surveys.of_program_type.present?)
        create_default_tips(program) unless program.mentoring_tips.present?
        create_resource_publications_for_non_default_resources(program)
      else
        organization = program
        # create default contents( have been removed from organization observer)
        create_non_default_resources!(organization) unless organization.resources.non_default.present?
      end
    end


    # create default forums for the program
    def create_default_forums(program)
      student_forum = program.forums.new(:name => "app_constant.default_name.mentee_forum".translate(Mentee: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term))
      student_forum.access_role_names = RoleConstants::STUDENT_NAME
      student_forum.save!

      mentor_forum = program.forums.new(:name => "app_constant.default_name.mentor_forum".translate(Mentor: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term))
      mentor_forum.access_role_names = RoleConstants::MENTOR_NAME
      mentor_forum.save!
    end

    #
    # Creates default surveys for the program
    #
    def create_default_surveys(program)
      program.create_survey(SurveyConstants::DEFAULT_SURVEY_QUESTIONS)
      program.create_survey(SurveyConstants::HEALTH_SURVEY_QUESTIONS)
      program.create_survey(SurveyConstants::CLOSURE_SURVEY_QUESTIONS)
      program.create_survey(SurveyConstants::MENTOR_SURVEY_QUESTIONS, nil, SurveyConstants::MENTOR_SURVEY_NAME.call(program), ProgramSurvey.name)
      program.create_survey(SurveyConstants::MENTEE_SURVEY_QUESTIONS, nil, SurveyConstants::MENTEE_SURVEY_NAME.call(program), ProgramSurvey.name)
      program.create_survey(SurveyConstants::DEFAULT_FEEDBACK_QUESTIONS, Survey::EditMode::MULTIRESPONSE, SurveyConstants::FEEDBACK_SURVEY_NAME.call(program), EngagementSurvey.name, nil, true)
    end

    def create_default_tips(program)
      # SUB_FORUM
      FacilitationMessageConstants::MentoringTips::MenteeTips.all.each do |mentee_tip|
        tip = program.mentoring_tips.build(:message => mentee_tip)
        tip.program = program
        tip.enabled = false
        tip.role_names = [RoleConstants::STUDENT_NAME]
        tip.save!
      end
      FacilitationMessageConstants::MentoringTips::MentorTips.all.each do |mentor_tip|
        tip = program.mentoring_tips.build(:message => mentor_tip)
        tip.program = program
        tip.enabled = false
        tip.role_names = [RoleConstants::MENTOR_NAME]
        tip.save!
      end
    end

    #
    # Create default resources when program is created
    #
    def create_non_default_resources!(organization)
      mentor_url_content = "<a href='#{FacilitationMessageConstants::MENTOR_HANDBOOK}'>#{'feature.resources.content.mentor_default_handbook_content_label'.translate}</a>"
      mentor_handbook_resource = organization.resources.new({:title => "feature.resources.content.mentor_default_handbook_title".translate(:mentor => organization.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term),
        :content => "feature.resources.content.mentor_default_handbook_content_html".translate(:mentor_handbook_url =>  mentor_url_content.html_safe)})
      mentor_handbook_resource.save!

      mentee_url_content = "<a href='#{FacilitationMessageConstants::MENTEE_HANDBOOK}'>#{'feature.resources.content.mentee_default_handbook_content_label'.translate}</a>"
      mentee_handbook_resource = organization.resources.new({:title => "feature.resources.content.mentee_default_handbook_title".translate(:mentee => organization.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term),
        :content => "feature.resources.content.mentee_default_handbook_content_html".translate(:mentee_handbook_url => mentee_url_content.html_safe)})
      mentee_handbook_resource.save!
    end

    def create_resource_publications_for_non_default_resources(program)
      program.organization.reload.resources.non_default.each do |resource|
        next if resource.resource_publications.where(program_id: program.id).present?
        resource.resource_publications.create!(program_id: program.id)
      end
    end
  end

  def assign_owner!(programs, owner)
    programs.each do |program|
      program.owner = owner
      program.save!
    end
  end

  def enable_features!(organization, features_list = [])
    self.class.benchmark_wrapper "Features" do
      features = features_list.presence || FeatureName.all
      features.each do |feature_name| 
        organization.enable_feature(feature_name)
        self.class.dot
      end
    end
  end

  def populate_forums(program, forum_count)
    self.class.benchmark_wrapper "Forums" do
      forum_count.times do
        forum = program.forums.build(
          name: Populator.words(8..12),
          description: Populator.sentences(3..5)
        )  
        forum.access_role_names = self.class.random_role_names
        self.class.dot
      end
      program.save!
    end
  end

  def populate_program_events(program, admin_user, program_events_count)
    self.class.benchmark_wrapper "Program Events" do
      start_time = program.created_at
      randomizer = [*1..1000]
      admin_view_ids = program.admin_views.pluck(:id)
      program_events_count.times do
        event_start_time = (start_time + randomizer.sample.days).beginning_of_day + 8.hours
        program_event = program.program_events.build(
          title: Populator.words(10..16), status: [ProgramEvent::Status::PUBLISHED, ProgramEvent::Status::PUBLISHED, ProgramEvent::Status::DRAFT].sample, 
          start_time: event_start_time, end_time: event_start_time + 2.hours,
          user: admin_user, email_notification: false, description: Populator.sentences(4..8),
          location: Populator.words(6..9),
          admin_view_id: admin_view_ids.sample
        )
        program_event.role_names = Array([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].sample)
        self.class.dot
      end
      program.save!
    end
  end

  def populate_additional_roles(program, limit = 100)
    self.class.benchmark_wrapper "Additional Roles" do
      mentor_users = program.mentor_users.active.first(limit)
      student_users = program.student_users.active.first(limit)
      assign_roles!(mentor_users, RoleConstants::MENTOR_NAME, [RoleConstants::STUDENT_NAME]*5 + [RoleConstants::ADMIN_NAME])
      assign_roles!(student_users, RoleConstants::STUDENT_NAME, [RoleConstants::MENTOR_NAME]*5 + [RoleConstants::ADMIN_NAME])
      self.class.dot
    end
  end

  def assign_roles!(users, role, roles_array, randomize = true)
    users.each do |user|
      role_names = [role] + (randomize ? roles_array.sample(1) : roles_array)
      user.role_names = role_names.uniq
      user.save!
    end
  end

  def populate_announcements(program, admin_user, announcements_count, options = {})
    self.class.benchmark_wrapper "Announcements" do
      announcement_status = [Announcement::Status::PUBLISHED, Announcement::Status::PUBLISHED, Announcement::Status::PUBLISHED, Announcement::Status::PUBLISHED, Announcement::Status::DRAFTED]
      announcements_count.times do
        announcement = program.announcements.build(
          title: Populator.words(10..16),
          user_id: admin_user.id, body: Populator.sentences(4..8),
          status: announcement_status.sample
        )
        unless options[:skip_file_upload] || self.class.lucky?
          announcement.attachment = fixture_file_upload(File.join('test/fixtures/files', 'test_pic.png'), 'image/png')
        end
        announcement.recipient_role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].sample([1,2].sample)
        self.class.dot
      end
      program.save!
    end
  end

  def populate_programs(organization, count, options = {})
    new_programs = []
    self.class.benchmark_wrapper "Additional Programs" do 
      count.times do
        program = organization.programs.build
        program.name = options[:name] || "Mentoring at #{Populator.words(4..5)}"
        program.description = options[:description] || Populator.paragraphs(2..3)
        program.organization = organization
        program.mentor_request_style = options[:mentor_request_style] || [Program::MentorRequestStyle::MENTEE_TO_MENTOR, Program::MentorRequestStyle::MENTEE_TO_ADMIN, Program::MentorRequestStyle::NONE].sample
        program.engagement_type = options[:engagement_type] || Program::EngagementType::CAREER_BASED_WITH_ONGOING
        program.allow_one_to_many_mentoring = true
        program.created_at = 21.days.ago
        program.root = organization.get_next_program_root(program)
        program.save!
        DataPopulator.populate_default_contents(program)
        new_programs << program
        self.class.dot
      end
    end
    new_programs
  end

  def populate_profile_questions(organization, count)
    new_profile_questions = []
    self.class.benchmark_wrapper "Profile Questions Creation" do
      section_ids = organization.sections.pluck(:id)
      allowed_question_types = ProfileQuestion::Type.all - [ProfileQuestion::Type::NAME, ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::SKYPE_ID, ProfileQuestion::Type::RATING_SCALE, ProfileQuestion::Type::LOCATION]
      temp_question_types = allowed_question_types.dup
      count.times do
        if temp_question_types.size.zero?
          temp_question_types = allowed_question_types.dup
        end
        pq = organization.profile_questions.build
        pq.question_text = Populator.words(4)
        pq.question_type = temp_question_types.shift
        pq.section_id = section_ids.sample
        random_options_number = 3..10
        if pq.question_type == ProfileQuestion::Type::ORDERED_OPTIONS
          pq.options_count = [*3..5].sample 
          random_options_number = pq.options_count + 5
        end
        if (pq.choice_based? || pq.ordered_options_type?)
          question_choices = self.class.generate_random_question_info(random_options_number)
          question_choices.each_with_index do |qc, index|
            pq.question_choices.build(text: qc, position: index + 1)
          end
        end
        new_profile_questions << pq
        self.class.dot
      end
      organization.save!
      self.class.display_populated_count(count, "Profile Questions")
    end
    [organization.profile_questions, new_profile_questions]
  end

  def populate_role_questions(program, new_profile_questions, options = {})
    self.class.benchmark_wrapper "Populating Role Questions" do
      roles = options[:roles] || program.roles.with_name([RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME])
      new_profile_questions.each do |question|
        get_roles(roles).each do |role|
          role_ques = RoleQuestion.new(
            :required => [false, true].sample, :filterable => true, 
            :private => (RoleQuestion::PRIVACY_SETTING.all + [RoleQuestion::PRIVACY_SETTING::ALL, RoleQuestion::PRIVACY_SETTING::RESTRICTED] * 2).sample,
            :available_for => (RoleQuestion::AVAILABLE_FOR.all + [RoleQuestion::AVAILABLE_FOR::BOTH, RoleQuestion::AVAILABLE_FOR::BOTH]).sample,
            :profile_question => question,
            :skip_match_index => true
          )
          role_ques.role = role
          role_ques.privacy_settings.build((RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(program).sample)[:privacy_setting]) if role_ques.restricted?
          role_ques.save!
        end
        self.class.dot
      end
    end
  end

  def populate_connection_questions(program, connection_questions_count)
    self.class.benchmark_wrapper "Connection Questions" do
      program_id = program.id
      iterator = 0
      Connection::Question.populate connection_questions_count do |common_question|
        common_question.type = Connection::Question.to_s
        common_question.program_id = program.id
        common_question.question_text = Populator.words(5..8)
        common_question.question_type = [CommonQuestion::Type::STRING, CommonQuestion::Type::TEXT, CommonQuestion::Type::SINGLE_CHOICE].sample
        common_question.position = iterator += 1
        common_question.required = [false, false, true].sample
        common_question.is_admin_only = [false, false, false, true].sample
        common_question.allow_other_option = [false, false, true].sample
        common_question.help_text = Populator.words(3..5)

        Connection::Question::Translation.populate 1 do |translation|
          translation.common_question_id = common_question.id
          translation.question_text = common_question.question_text
          translation.help_text = common_question.help_text
          translation.locale = "en"
        end
        if common_question_choice_based?(common_question.question_type)
          choices =  self.class.generate_random_question_info
          qc_iterator = 0
          QuestionChoice.populate choices.size do |question_choice|
            question_choice.ref_obj_id = common_question.id
            question_choice.ref_obj_type = CommonQuestion.name
            qc_iterator += 1
            question_choice.position = qc_iterator
            question_choice.text =  choices.shift
            question_choice.is_other = false
            QuestionChoice::Translation.populate 1 do |translation|
              translation.question_choice_id = question_choice.id
              translation.text = question_choice.text
              translation.locale = "en"
            end
          end
        end
        self.class.dot
      end
    end
  end

  def populate_connection_answers(program)
    self.class.benchmark_wrapper "Connection Answers" do
      group_ids = program.groups.active.pluck(:id)
      group_ids_size = group_ids.size
      questions = program.connection_questions.where("question_type != #{CommonQuestion::Type::FILE}")

      questions.each do |connection_question|
        temp_group_ids = group_ids.dup
        Connection::Answer.populate(group_ids_size, per_query: 5_000) do |connection_answer|
          connection_answer.type = Connection::Answer.to_s
          connection_answer.common_question_id = connection_question.id
          connection_answer.group_id = temp_group_ids.shift
          set_common_answer_text!(connection_question, connection_answer)
          self.class.dot
        end
      end
    end
  end

  def populate_project_requests(program, request_count)
    return unless program.project_based?
    student_ids = program.student_users.pluck(:id).sample(request_count)
    group_ids = program.groups.pending.pluck(:id).sample(request_count)
    student_role_id = program.find_role(RoleConstants::STUDENT_NAME).id
    temp_group_ids = group_ids.dup

    self.class.benchmark_wrapper "Project Requests" do
      ProjectRequest.populate request_count do |req|
        req.sender_id = student_ids.shift
        req.program_id = program.id
        req.group_id = temp_group_ids.shift
        if req.group_id.nil?
          temp_group_ids = group_ids.dup
          req.group_id = temp_group_ids.shift
        end
        req.message = Populator.words(8..10)
        req.status = [AbstractRequest::Status::NOT_ANSWERED]
        req.sender_role_id = student_role_id

        self.class.dot
      end
    end
  end

  def populate_activity(program, user_ids, activity, count)
    temp_user_ids = user_ids * count
    ActivityLog.populate (count * user_ids.size) do |activity_log|
      activity_log.program_id = program.id
      activity_log.user_id = temp_user_ids.shift
      activity_log.activity = activity
    end
  end
  
  protected 

  def common_question_choice_based?(question_type)
    [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE].include?(question_type)
  end

  def set_common_answer_text!(common_question, common_answer)
    case common_question.question_type
    when CommonQuestion::Type::MULTI_CHOICE
      choices = self.class.pick_random_answer(default_question_choices(common_question), (3..7).to_a)
    when CommonQuestion::Type::SINGLE_CHOICE
      choices = self.class.pick_random_answer(default_question_choices(common_question), [1])
    when CommonQuestion::Type::STRING
      common_answer.answer_text = Populator.words(2..4)
    when CommonQuestion::Type::TEXT
      common_answer.answer_text = Populator.sentences(1..2)
    when CommonQuestion::Type::RATING_SCALE
      choices = self.class.pick_random_answer(default_question_choices(common_question), [1])
    when CommonQuestion::Type::MULTI_STRING
      common_answer.answer_text = Populator.words(1..4).split(" ").uniq.join(CommonAnswer::MULTILINE_SEPERATOR)
    end
    populate_answer_choices(common_question, common_answer, choices)
  end

  def is_choice_based_question?(question_type, ref_obj_type)
    if ref_obj_type == ProfileQuestion.name
      [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::RATING_SCALE, ProfileQuestion::Type::ORDERED_SINGLE_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS].include?(question_type)
    elsif ref_obj_type == CommonQuestion.name
      common_question_choice_based?(question_type)
    end
  end

  def populate_question_choices(question, ref_obj_type, translation_locales)
    if is_choice_based_question?(question.question_type, ref_obj_type)
      choice_position = 0
      choices = self.class.generate_random_question_info
      QuestionChoice.populate choices.size do |question_choice|
        choice_position += 1
        question_choice.position = choice_position
        question_choice.is_other = false
        question_choice.ref_obj_id = question.id
        question_choice.ref_obj_type = ref_obj_type
        populate_question_choice_translations(question_choice, choices.shift, translation_locales)
      end
    end
  end

  def populate_question_choice_translations(question_choice, choice_text, translation_locales)
    locales = translation_locales.dup
    QuestionChoice::Translation.populate translation_locales.count do |translation|
      translation.question_choice_id = question_choice.id
      translation.text = choice_text
      translation.locale = locales.pop
    end
  end

  def populate_answer_choices(common_question, common_answer, choices)
    return unless choices.present?
    choices = Array(choices)
    question_choices = default_question_choices(common_question, true)
    common_answer.answer_text = choices.dup.join(",")
    AnswerChoice.populate(choices.size) do |answer_choice|
      answer_choice.ref_obj_id = common_answer.id
      answer_choice.question_choice_id = question_choices[choices.shift].id
      answer_choice.ref_obj_type = CommonAnswer.name
      answer_choice.position = 0
    end
  end

  def default_question_choices(common_question, indexed = false)
    question = common_question.matrix_question if common_question.try(:matrix_question_id).present?
    question ||= common_question
    return question.default_question_choices.index_by(&:text) if indexed.present?
    return question.default_question_choices.collect(&:text)
  end
end
