class SurveyResponsesXlsDataService
  ANSWER_SEPARATOR = "`|`|`"
  QUESTION_ID_ANSWER_SEPARATOR = "^~^~^"

  USER_NAME_FIELDS = Proc.new{["feature.survey.survey_report.Username_v1".translate, "feature.survey.survey_report.Email".translate]}
  TIMESTAMP_FIELDS = Proc.new{["feature.survey.survey_report.Timestamp_v1".translate]}
  MEETING_FIELDS = Proc.new{["feature.survey.survey_report.Topic".translate, "feature.survey.survey_report.Description".translate, "feature.survey.survey_report.Other_people".translate]}
  ENGAGEMENT_FIELDS = Proc.new{|connection_tern| ["feature.survey.survey_report.Group_name".translate(:_Mentoring_Connection => connection_tern), "feature.survey.survey_report.Task_name".translate]}

  attr_accessor :survey, :program, :organization, :response_ids, :default_column_keys

  def initialize(survey, program, organization, locale, response_ids, options = {})
    @survey = survey
    @program = program
    @organization = organization
    @response_ids = response_ids
    @locale = locale
    @default_column_keys = get_default_column_keys(survey)
    @default_column_keys += options[:additional_column_keys] if options[:additional_column_keys].present?
  end

  def build_xls_data_for_survey(options = {})
    GlobalizationUtils.run_in_locale(@locale) do
      @mentoring_connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
      survey_questions = survey.survey_questions.select([:id, :question_type, :allow_other_option, :matrix_question_id, :matrix_position]).includes(:translations, {question_choices: [:translations, :answer_choices]})
      book = options[:book] || Spreadsheet::Workbook.new
      header_format = Spreadsheet::Format.new(:size => 10, :weight => :bold, :horizontal_align => :merge)

      populate_responses_data(book, header_format, survey_questions, options)
      populate_aggrigate_data(book, header_format, survey_questions) unless options[:aggrigate_not_needed]

      data = StringIO.new ''
      book.write data
      data.string
    end
  end

  private

  def get_default_column_keys(survey)
    survey.survey_response_columns.of_default_columns.pluck(:column_key)
  end

  def show_user_name_data
    survey.has_the_default_column?(SurveyResponseColumn::Columns::SenderName)
  end

  def show_timeline
    survey.has_the_default_column?(SurveyResponseColumn::Columns::ResponseDate)
  end

  def show_roles
    survey.has_the_default_column?(SurveyResponseColumn::Columns::Roles)
  end

  def show_survey_specific_data
    survey.has_the_default_column?(SurveyResponseColumn::Columns::SurveySpecific)
  end

  def populate_aggrigate_data(book, header_format, survey_questions)
    sheet = book.create_worksheet
    sheet.name = "feature.survey.survey_report.Grouped_by_question".translate
    # 3 is the number of columns
    3.times do |i|
      sheet.row(0).set_format(i, header_format)
    end

    sheet.row(0).push "feature.survey.survey_report.Question".translate, "feature.survey.survey_report.No_of_responses".translate, "feature.survey.survey_report.Details".translate
    push_question_associated_survey_answers(sheet, survey_questions)
  end

  def push_question_associated_survey_answers(sheet, survey_questions)
    row_number = 1
    survey.get_report({:survey_questions => survey_questions, :export => true, :response_ids => response_ids}).question_responses.each do |question, resp|
      if resp.is_a?(Survey::Report::MatrixQuestionResponse)
        resp.rating_question_responses.each do |rqr|
          add_row_data_to_sheet(sheet, row_number, rqr.survey_question.question_text_for_display, rqr)
          row_number += 1
        end
      else
        add_row_data_to_sheet(sheet, row_number, question.question_text, resp)
        row_number += 1
      end
    end
  end

  def populate_responses_data(book, header_format, survey_questions, options = {})
    sheet = options[:sheet] || book.create_worksheet
    sheet.name = "feature.survey.survey_report.Grouped_by_member".translate unless options[:sheet]
    survey_questions_to_display = survey.get_questions_from_response_columns_for_display
    profile_questions_to_display = survey.profile_questions_to_display

    push_responses_data_headers(sheet, header_format, survey_questions_to_display, profile_questions_to_display) unless options[:headers_not_needed]
    push_user_associated_survey_answers(sheet, survey_questions_to_display.collect(&:id), survey_questions_to_display, profile_questions_to_display, options) if survey_questions.present?
  end

  def push_responses_data_headers(sheet, header_format, survey_questions_to_display, profile_questions_to_display)
    default_column_keys.each do |column_key|
      default_headers =
      case column_key
      when SurveyResponseColumn::Columns::SenderName
        USER_NAME_FIELDS.call
      when SurveyResponseColumn::Columns::Roles
        "feature.survey.survey_report.filters.header.user_role".translate
      when SurveyResponseColumn::Columns::SurveySpecific
        survey.meeting_feedback_survey? ? MEETING_FIELDS.call : ENGAGEMENT_FIELDS.call(@mentoring_connection_term)
      when SurveyResponseColumn::Columns::ResponseDate
        TIMESTAMP_FIELDS.call
      when SurveyResponseColumn::Columns::Program
        organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term
      end
      sheet.row(0).push(*default_headers)
    end

    survey_questions_to_display.each { |ques| sheet.row(0).push ques.question_text_for_display }
    profile_questions_to_display.each { |ques| sheet.row(0).push ques.question_text }

    sheet.column_count.times { |i| sheet.row(0).set_format(i, header_format) }
  end

  def push_user_associated_survey_answers(sheet, survey_question_ids, survey_questions_to_display, profile_questions_to_display, options = {})
    show_meeting_data = survey.meeting_feedback_survey? && show_survey_specific_data
    show_engagement_data = survey.engagement_survey? && show_survey_specific_data

    survey_questions = SurveyQuestion.where(:id => survey_question_ids).includes(question_choices: :translations).index_by(&:id)
    grouped_answers = survey.get_answers_and_user_names(survey_question_ids, QUESTION_ID_ANSWER_SEPARATOR, ANSWER_SEPARATOR, program.id, is_engagement_survey: show_engagement_data, response_ids: response_ids)
    role_name_custom_term_map = RoleConstants.program_roles_mapping(program)
    get_meeting_details_for_export if show_meeting_data
    get_profile_details_for_export(grouped_answers, profile_questions_to_display) if profile_questions_to_display.any?

    all_responses = ActiveRecord::Base.connection.select_all(grouped_answers)
    sorted_responses = response_ids.present? ? response_ids.collect {|response_id| all_responses.select {|response| response["response_id"] ==  response_id}.first} : all_responses

    row_number = options[:row_number] || 1
    sorted_responses.each do |user_answer|
      default_column_keys.each do |column_key|
        case column_key
        when SurveyResponseColumn::Columns::SenderName
          fill_user_data(sheet, row_number, user_answer)
        when SurveyResponseColumn::Columns::Roles
          fill_roles_data(sheet, row_number, user_answer, role_name_custom_term_map)
        when SurveyResponseColumn::Columns::SurveySpecific
          survey.meeting_feedback_survey? ? fill_meeting_data(sheet, row_number, user_answer) : fill_engagement_data(sheet, row_number, user_answer)
        when SurveyResponseColumn::Columns::ResponseDate
          fill_timeline(sheet, row_number, user_answer)
        when SurveyResponseColumn::Columns::Program
          sheet.row(row_number).push program.name
        end
      end

      fill_answers_data(sheet, row_number, user_answer, survey_question_ids, survey_questions, survey_questions_to_display.collect(&:id)) if survey_question_ids.present?
      fill_profile_data(sheet, row_number, user_answer, profile_questions_to_display) if profile_questions_to_display.any?
      row_number += 1
    end
  end

  def get_meeting_details_for_export
    answered_member_meetings = survey.survey_answers.with_response_ids_in(response_ids).select(:member_meeting_id).pluck(:member_meeting_id).uniq
    @meetings = program.meetings.unscoped.joins(:member_meetings).where("member_meetings.id IN (?)", answered_member_meetings).select("member_meetings.id AS member_meeting_id, meetings.id AS meeting_id, topic, description").index_by(&:member_meeting_id)
    meeting_ids = @meetings.values.collect(&:meeting_id)
    @meeting_members = MemberMeeting.where(meeting_id: meeting_ids).select("meeting_id, GROUP_CONCAT(member_id) as meeting_members").group(:meeting_id).index_by(&:meeting_id)
    members_of_meeting = MemberMeeting.where(meeting_id: meeting_ids).pluck(:member_id)
    @member_names = organization.members.where(id: members_of_meeting).select("CONCAT(first_name, ' ', last_name) AS name, id").index_by(&:id)
  end

  def get_profile_details_for_export(grouped_answers, profile_questions_to_display)
    member_ids = grouped_answers.map {|ga| ga["member_id"]}
    @profile_answers_hash = Member.prepare_answer_hash(member_ids, profile_questions_to_display.collect(&:id))
  end

  def fill_user_data(sheet, row_number, user_answer)
    sheet.row(row_number).push user_answer["name"], user_answer["email"]
  end

  def fill_roles_data(sheet, row_number, user_answer, role_name_custom_term_map)
    roles =
      if user_answer["user_roles"].blank?
        "-"
      else
        role_names = user_answer["user_roles"].split(COMMA_SEPARATOR)
        role_names.map { |role_name| role_name_custom_term_map[role_name] }.sort.join(COMMON_SEPARATOR)
      end
    sheet.row(row_number).push roles
  end

  def fill_timeline(sheet, row_number, user_answer)
    sheet.row(row_number).push DateTime.localize(user_answer["timestamp"].in_time_zone(Time.zone), format: :short_date_short_time)
  end

  def fill_meeting_data(sheet, row_number, user_answer)
    meeting = @meetings[user_answer["member_meeting_id"]]
    sheet.row(row_number).push meeting.topic
    sheet.row(row_number).push meeting.description
    members = @meeting_members[meeting["meeting_id"]]["meeting_members"].split(",").map{|member_id| @member_names[member_id.to_i]["name"]}
    other_people = members - [user_answer["name"]]
    sheet.row(row_number).push other_people.join(", ")
  end

  def fill_engagement_data(sheet, row_number, user_answer)
    group_name = program.groups.find_by(id: user_answer["group_id"].to_i).try(:name) || ""
    task_title = program.mentoring_model_tasks.find_by(id: user_answer["task_id"].to_i).try(:title) || ""
    sheet.row(row_number).push group_name
    sheet.row(row_number).push task_title
  end

  def fill_answers_data(sheet, row_number, user_answer, survey_question_ids, survey_questions, survey_question_ids_to_display)
    choices_hash = get_answered_choices(user_answer["choices"])
    answer = populate_question_answer_hash(user_answer)
    survey_question_ids.each do |question_id|
      if answer[question_id].present?
        question = survey_questions[question_id]
        if survey_question_ids_to_display.include?(question_id)
          answer_val = get_answer_text(question, answer[question_id], choices_hash[question_id] || [])
          sheet.row(row_number).push(answer_val)
        end
      else
        sheet.row(row_number).push "" if survey_question_ids_to_display.include?(question_id)
      end
    end
  end

  def fill_profile_data(sheet, row_number, user_answer, profile_questions_to_display)
    member_id = user_answer["member_id"]
    profile_questions_to_display.each do |pq|
      answer = @profile_answers_hash[member_id][pq.id].try(:first)
      sheet.row(row_number).push pq.format_profile_answer_for_xls(answer)
    end
  end

  def add_row_data_to_sheet(sheet, row_number, question_text, resp)
    sheet.row(row_number).push question_text, resp.csv_line[0], (resp.csv_line[1].gsub "\n", ", ")
  end

  def get_answered_choices(choices)
    choices_hash = {}
    (choices || "").split(ANSWER_SEPARATOR).each do |question_with_choice|
      question_with_choice = question_with_choice.split(QUESTION_ID_ANSWER_SEPARATOR)
      question_id = question_with_choice[0].to_i
      choices_hash[question_id] ||= []
      choices_hash[question_id] << question_with_choice[1].to_i
    end
    choices_hash
  end

  def get_answer_text(question, answer, choices_list)
    if question.choice_based?
      question = question.matrix_question if question.matrix_question_id.present?
      question.question_choices.select{|qc| choices_list.include?(qc.id)}.collect(&:text).join_by_separator(CommonAnswer::SEPERATOR)
    else
      answer
    end
  end

  def populate_question_answer_hash(user_answer)
    individual_answers = user_answer["answers"].split(ANSWER_SEPARATOR)
    answer = {}
    individual_answers.each do |question_answer|
      question_answer_split = question_answer.split(QUESTION_ID_ANSWER_SEPARATOR)
      answer[question_answer_split[0].to_i] = question_answer_split[1]
    end
    return answer
  end
end