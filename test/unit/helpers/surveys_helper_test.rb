require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/surveys_helper"

class SurveysHelperTest < ActionView::TestCase
  include SurveysHelper
  include TranslationsService
  include CommonAnswersHelper

  def setup
    super
    helper_setup
  end

  def test_survey_status_with_no_questions
    survey = surveys(:one)
    assert survey.survey_questions.empty?
    assert_match(/This survey does not have any questions yet/, survey_status_message(survey, :summary, 0))
    assert_no_match(/This survey does not have any questions yet/, survey_status_message(survey, :questions, 0))
    assert_match(/This survey does not have any questions yet/, survey_status_message(survey, :responses, 0))
  end

  def test_survey_status_with_overdue
    survey = surveys(:one)
    assert survey.survey_questions.empty?
    # update_attribute so as to skip validations
    survey.update_attribute :due_date, 2.days.ago
    assert survey.reload.overdue?

    # There are some questions
    create_survey_question({ :survey => survey})
    assert_match(/There were no responses/, survey_status_message(survey, :summary, 0))
    assert_match(/There were .*2 responses/, survey_status_message(survey, :questions, 2))
    assert_no_match(/The due date for this survey has passed/, survey_status_message(survey, :responses, 2))
  end

  def test_survey_status_overdue_but_no_questions
    survey = surveys(:one)
    assert survey.survey_questions.empty?
    # update_attribute so as to skip validations
    survey.update_attribute :due_date, 2.days.ago
    assert survey.reload.overdue?

    # There are no questions. But, we should get overdue message.
    # Not 'no questions' message.
    assert_match(/There were no responses/, survey_status_message(survey, :summary, 0))
    assert_match(/There were .*2 responses/, survey_status_message(survey, :questions, 2))
    assert_no_match(/response/, survey_status_message(survey, :responses, 2))
  end

  def test_show_create_survey_task_link
    survey = surveys(:two)
    @current_program = survey.program
    assert_no_match(/plan to start receiving responses/, survey_status_message(survey, :responses, 0))

    survey.program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    assert_match(/plan to start receiving responses/, survey_status_message(survey.reload, :responses, 0))
  end

  def test_get_survey_deletion_action
    survey = surveys(:one)

    action, content = get_survey_deletion_action(survey)
    assert_equal "/surveys/#{survey.id}", action[:url]
    assert_equal :delete, action[:method]
    assert_equal "Before deleting, please ensure that the survey <b>'#{survey.name}'</b> is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey will be deleted. Do you want to proceed?", action[:data][:confirm]
    assert_equal "", content

    survey.stubs(:tied_to_health_report?).returns(true)
    action, content = get_survey_deletion_action(survey)
    assert_equal "/surveys/#{survey.id}", action[:url]
    assert_equal :delete, action[:method]
    assert_equal "Before deleting, please ensure that the survey <b>'#{survey.name}'</b> is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey will be deleted. Also, deleting this will affect the Program Health Report. Do you want to proceed?", action[:data][:confirm]
    assert_equal "", content
  end

  def test_get_survey_deletion_action_for_engagement_type_survey
    engagement_survey = surveys(:two)
    view.stubs(:_program).returns("program")

    assert_false engagement_survey.has_associated_tasks_in_active_groups_or_templates?
    assert_false engagement_survey.tied_to_outcomes_report?
    assert_false engagement_survey.tied_to_health_report?
    action, content = get_survey_deletion_action(engagement_survey)
    assert_equal "/surveys/#{engagement_survey.id}", action[:url]
    assert_equal :delete, action[:method]
    assert_equal "Before deleting, please ensure that the survey <b>'#{engagement_survey.name}'</b> is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey will be deleted. Do you want to proceed?", action[:data][:confirm]
    assert_equal "", content

    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: engagement_survey.id)
    assert task.group.active?
    assert engagement_survey.has_associated_tasks_in_active_groups_or_templates?
    action, content = get_survey_deletion_action(engagement_survey)
    assert_equal "/surveys/#{engagement_survey.id}/destroy_prompt.js", action[:url]
    assert_equal true, action[:remote]
    assert_equal_hash( { toggle: "modal", target: "#modal_survey-#{engagement_survey.id}-destroy" }, action[:data])
    assert_match /Delete Survey/, content

    engagement_survey.stubs(:has_associated_tasks_in_active_groups_or_templates?).returns(false)
    Group.stubs(:closed).returns(Group.where(id: task.group_id))
    action, content = get_survey_deletion_action(engagement_survey)
    assert_equal "/surveys/#{engagement_survey.id}", action[:url]
    assert_equal :delete, action[:method]
    assert_equal "Before deleting, please ensure that the survey <b>'#{engagement_survey.name}'</b> is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey and the tasks associated to the survey in closed mentoring connections will be deleted. Do you want to proceed?", action[:data][:confirm]
    assert_equal "", content
    engagement_survey.stubs(:tied_to_outcomes_report?).returns(true)
    action, content = get_survey_deletion_action(engagement_survey)
    assert_equal "Before deleting, please ensure that the survey <b>'#{engagement_survey.name}'</b> is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey and the tasks associated to the survey in closed mentoring connections will be deleted. Also, deleting this will affect the Program Outcomes Report. Do you want to proceed?", action[:data][:confirm]
    engagement_survey.stubs(:tied_to_health_report?).returns(true)
    action, content = get_survey_deletion_action(engagement_survey)
    assert_equal "Before deleting, please ensure that the survey <b>'#{engagement_survey.name}'</b> is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey and the tasks associated to the survey in closed mentoring connections will be deleted. Also, deleting this will affect the Program Health Report and Program Outcomes Report. Do you want to proceed?", action[:data][:confirm]
    assert_empty content
    engagement_survey.stubs(:tied_to_outcomes_report?).returns(false)
    action, content = get_survey_deletion_action(engagement_survey)
    assert_equal "Before deleting, please ensure that the survey <b>'#{engagement_survey.name}'</b> is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey and the tasks associated to the survey in closed mentoring connections will be deleted. Also, deleting this will affect the Program Health Report. Do you want to proceed?", action[:data][:confirm]
    assert_empty content
  end

  def test_render_survey_header_bar_engagement_survey
    survey = surveys(:two)
    program = survey.program
    assert survey.engagement_survey?
    assert_false program.mentoring_connections_v2_enabled?
    actions, rendered_html = render_survey_header_bar(survey)
    assert_false actions.any? { |action| action[:label].match("Add to").present? }
    assert_false actions.any? { |action| action[:label].match("Make a Copy").present? }
    assert actions.any? { |action| action[:label].match("Edit").present? }
    assert actions.any? { |action| action[:label].match("Delete").present? }
    assert actions.any? { |action| action[:label].match("Export Survey Questions").present? }

    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    actions, rendered_html = render_survey_header_bar(survey.reload)
    assert actions.any? { |action| action[:label].match("Add to").present? }
    assert actions.any? { |action| action[:label].match("Make a Copy").present? }
    assert actions.any? { |action| action[:label].match("Edit").present? }
    assert actions.any? { |action| action[:label].match("Delete").present? }
    assert actions.any? { |action| action[:label].match("Export Survey Questions").present? }
  end

  def test_survey_received_responses_text
    survey = surveys(:two)
    response_rate_hash = {:responses_count=>0, :users_responded=>0, :users_responded_groups_or_meetings_count=>0, :overdue_responses_count=>2, :users_overdue=>2, :users_overdue_groups_meetings_count=>2, :response_rate=>nil, :percentage_error=>nil}
    assert_equal survey_received_responses_text(survey, response_rate_hash), "feature.survey.responses.fields.users_connections_responses_html".translate(users: response_rate_hash[:users_responded], connections: response_rate_hash[:users_responded_groups_or_meetings_count], :mentoring_connections => _mentoring_connections, tooltip: embed_icon(TOOLTIP_IMAGE_CLASS,'', :id => "users_connections_responses_received_text"))

    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    assert_equal survey_received_responses_text(survey, response_rate_hash), "feature.survey.responses.fields.members_meetings_responses_html".translate(users_count: response_rate_hash[:users_responded], meetings_count: response_rate_hash[:users_responded_groups_or_meetings_count], :_meetings => _meetings, tooltip: embed_icon(TOOLTIP_IMAGE_CLASS,'', :id => "users_connections_responses_received_text"))
  end

  def test_survey_overdue_responses_text
    survey = surveys(:two)
    response_rate_hash = {:responses_count=>0, :users_responded=>0, :users_responded_groups_or_meetings_count=>0, :overdue_responses_count=>2, :users_overdue=>2, :users_overdue_groups_or_meetings_count=>2, :response_rate=>nil, :percentage_error=>nil}
    assert_equal survey_overdue_responses_text(survey, response_rate_hash), "feature.survey.responses.fields.users_connections_responses_html".translate( users: response_rate_hash[:users_overdue], connections: response_rate_hash[:users_overdue_groups_or_meetings_count], :mentoring_connections => _mentoring_connections, tooltip: embed_icon(TOOLTIP_IMAGE_CLASS,'', :id => "users_connections_overdue_responses_text")) 
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)  
    assert_equal survey_overdue_responses_text(survey, response_rate_hash), "feature.survey.responses.fields.members_meetings_responses_html".translate(users_count: response_rate_hash[:users_overdue], meetings_count: response_rate_hash[:users_overdue_groups_or_meetings_count], :_meetings => _meetings, tooltip: embed_icon(TOOLTIP_IMAGE_CLASS,'', :id => "users_connections_overdue_responses_text"))
  end

  def test_render_survey_header_bar_program_and_meeting_feedback_survey
    survey = surveys(:one)
    assert survey.program_survey?
    actions, rendered_html = render_survey_header_bar(survey)
    assert_false actions.any? { |action| action[:label].match("Add to").present? }
    assert actions.any? { |action| action[:label].match("Make a Copy").present? }
    assert actions.any? { |action| action[:label].match("Edit").present? }
    assert actions.any? { |action| action[:label].match("Delete").present? }

    survey = programs(:albers).surveys.find_by(name: "Meeting Feedback Survey For Mentees")
    assert survey.meeting_feedback_survey?
    actions, rendered_html = render_survey_header_bar(survey)
    assert_false actions.any? { |action| action[:label].match("Add to").present? }
    assert_false actions.any? { |action| action[:label].match("Make a Copy").present? }
    assert_false actions.any? { |action| action[:label].match("Export Survey Questions").present? }
    assert actions.any? { |action| action[:label].match("Edit").present? }
    assert_false actions.any? { |action| action[:label].match("Delete").present? }
  end

  def test_render_user_survey_answer
    survey = surveys(:two)
    multi_string_question = common_questions(:q2_name)
    single_choice_question = common_questions(:q2_from)

    # without answer
    content = set_response_text(render_user_survey_answer(multi_string_question, nil))
    assert_select "h4", :text => multi_string_question.question_text
    assert_select "div", :text => "Not Specified"
  end

  def test_render_user_survey_matrix_answer
    choice_q = create_survey_question({
      :question_text => "Single Line",
        :question_type => CommonQuestion::Type::STRING })

    matrix_rating_q = create_matrix_survey_question

    answer=SurveyAnswer.create!(
      {:answer_text => "My answer",
        :user => users(:f_mentor),
        :last_answered_at => Time.now.utc,
        :survey_question => choice_q}
    )

    # without answer
    content = set_response_text(render_user_survey_matrix_answer(matrix_rating_q,answer))
    
    assert_select "strong", :text => "Leadership"
    assert_select "strong", :text =>  "Team Work"
    assert_select "strong", :text =>  "Communication"
    assert_select "span", :text => "Not Specified"
  end

  def test_render_background_color
    percentage = 38
    content = set_response_text(render_background_color(percentage))

    assert_equal "color-31-40",content

    percentage = 0.25
    content = set_response_text(render_background_color(percentage))

    assert_equal "color-1-10",content

    percentage = 10.5
    content = set_response_text(render_background_color(percentage))

    assert_equal "color-11-20",content

  end 

  def test_render_class_for_matrix_rating_question
    mq = create_matrix_survey_question
    content = set_response_text(render_class_for_matrix_rating_question(mq))
    assert_equal "matrix_report_table",content
  end

  def test_render_choice_answers_count
    percent = 33.3
    total_count = 3

    content = set_response_text(render_choice_answers_count(percent,total_count))
    assert_equal 1,content
  end

  def test_survey_matrix_rating_question_container
      content = set_response_text(survey_matrix_rating_question_container("good","bad"))
      assert_select "strong", :text => "good"
      assert_select "div", :text => "bad"
  end

  def test_set_survey_role_check_box_tag_value
    survey = {recipient_role_names: ["mentor"]}
    role_name = "mentor"
    content = set_response_text(set_survey_role_check_box_tag_value(survey,role_name))
    assert_equal true,content

    survey = {recipient_role_names: ["mentee"]}
    role_name = "mentor"
    content = set_response_text(set_survey_role_check_box_tag_value(survey,role_name))
    assert_equal false,content

    survey = {}
    role_name = "mentor"
    content = set_response_text(set_survey_role_check_box_tag_value(survey,role_name))
    assert_equal false,content
  end

  def test_populate_survey_response_column_options_for_default_columns
    survey = surveys(:progress_report)
    optgroup = SurveysController::SurveyResponseColumnGroup::DEFAULT

    assert_match /<option selected=\"selected\" value=\"default:name\">Name<\/option>/, populate_survey_response_column_options(survey, optgroup)
    assert_match /<option selected=\"selected\" value=\"default:date\">Date of response<\/option>/, populate_survey_response_column_options(survey, optgroup)
    assert_match /<option selected=\"selected\" value=\"default:surveySpecific\">Mentoring Connection<\/option>/, populate_survey_response_column_options(survey, optgroup)

    survey.survey_response_columns.find_by(column_key: SurveyResponseColumn::Columns::SenderName).destroy

    assert_match /<option value=\"default:name\">Name<\/option>/, populate_survey_response_column_options(survey, optgroup)
    assert_match /<option selected=\"selected\" value=\"default:date\">Date of response<\/option>/, populate_survey_response_column_options(survey, optgroup)
    assert_match /<option selected=\"selected\" value=\"default:surveySpecific\">Mentoring Connection<\/option>/, populate_survey_response_column_options(survey, optgroup)
  end

  def test_populate_survey_response_column_options_for_survey_question_columns
    survey = surveys(:progress_report)
    optgroup = SurveysController::SurveyResponseColumnGroup::SURVEY
    survey_question_1 = survey.survey_questions.first
    survey_question_2 = survey.survey_questions.last

    assert_equal "<option selected=\"selected\" value=\"survey:#{survey_question_1.id}\">#{survey_question_1.question_text}</option>\n<option selected=\"selected\" value=\"survey:#{survey_question_2.id}\">#{survey_question_2.question_text}</option>", populate_survey_response_column_options(survey, optgroup)

    survey.survey_response_columns.of_survey_questions.first.destroy

    assert_equal "<option selected=\"selected\" value=\"survey:#{survey_question_2.id}\">#{survey_question_2.question_text}</option>\n<option value=\"survey:#{survey_question_1.id}\">#{survey_question_1.question_text}</option>", populate_survey_response_column_options(survey, optgroup)
  end

  def test_populate_survey_response_column_options_for_profile_question_columns
    survey = surveys(:progress_report)
    optgroup = SurveysController::SurveyResponseColumnGroup::PROFILE
    profile_questions = survey.program.profile_questions_for(survey.survey_answers.collect(&:user).map{|u| u.role_names}.flatten.uniq, {default: true, skype: false, fetch_all: true}).select{|q| !q.name_type? && !q.email_type?}
    profile_question = profile_questions.first

    survey.survey_response_columns.create!(:survey_id => survey.id, :position => survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)

    assert_match /<option selected=\"selected\" value=\"profile:#{profile_question.id}\">#{profile_question.question_text}<\/option>/, populate_survey_response_column_options(survey, optgroup)

    profile_questions[1..-1].each do |pq|
      assert_match /<option value=\"profile:#{pq.id}\">#{pq.question_text}<\/option>/, populate_survey_response_column_options(survey, optgroup)
    end

    survey.survey_response_columns.of_profile_questions.destroy_all

    profile_questions.each do |pq|
      assert_match /<option value=\"profile:#{pq.id}\">#{pq.question_text}<\/option>/, populate_survey_response_column_options(survey, optgroup)
    end
  end

  def test_survey_response_edit_column_mapper
    assert_equal "default:name", survey_response_edit_column_mapper("name", "default")
  end

  def test_get_selected_columns
    survey = surveys(:progress_report)

    assert_equal get_selected_columns(survey, SurveysController::SurveyResponseColumnGroup::DEFAULT), survey.survey_response_columns.of_default_columns.collect(&:key)
    assert_equal get_selected_columns(survey, SurveysController::SurveyResponseColumnGroup::SURVEY), survey.survey_response_columns.of_survey_questions.collect(&:survey_question)
    assert_equal get_selected_columns(survey, SurveysController::SurveyResponseColumnGroup::PROFILE), survey.profile_questions_to_display
  end

  def test_get_all_columns
    survey = surveys(:progress_report)

    assert_equal get_all_columns(survey, SurveysController::SurveyResponseColumnGroup::DEFAULT), survey.get_default_survey_response_column_keys
    assert_equal get_all_columns(survey, SurveysController::SurveyResponseColumnGroup::SURVEY), survey.survey_questions
    assert_equal get_all_columns(survey, SurveysController::SurveyResponseColumnGroup::PROFILE), survey.program.profile_questions_for(survey.survey_answers.includes(user: :roles).collect(&:user).map{|u| u.role_names}.flatten.uniq, {default: true, skype: false, fetch_all: true}).select{|q| !q.name_type? && !q.email_type?}
  end

  def test_get_selected_column_keys
    survey = surveys(:progress_report)
    defaults_columns = ["name", "date", "surveySpecific"]
    survey_columns = survey.survey_questions

    assert_equal get_selected_column_keys(defaults_columns, SurveysController::SurveyResponseColumnGroup::DEFAULT), defaults_columns

    assert_equal get_selected_column_keys(survey_columns, SurveysController::SurveyResponseColumnGroup::SURVEY), survey_columns.collect(&:id).map{|id| id.to_i}
  end

  def test_get_column_key
    survey = surveys(:progress_report)

    assert_equal get_column_key("name", SurveysController::SurveyResponseColumnGroup::DEFAULT), "name"
    assert_equal get_column_key(survey.survey_questions.first, SurveysController::SurveyResponseColumnGroup::SURVEY), survey.survey_questions.first.id
  end

  def test_title_for_column
    survey = surveys(:progress_report)

    assert_equal title_for_column(survey, "name", SurveysController::SurveyResponseColumnGroup::DEFAULT), SurveyResponseColumn.get_default_title("name", survey)
    assert_equal title_for_column(survey, survey.survey_questions.first, SurveysController::SurveyResponseColumnGroup::SURVEY), survey.survey_questions.first.question_text
  end

  def test_link_to_responses_in_last_week
    survey = surveys(:progress_report)

    survey.survey_answers.update_all(:last_answered_at => 2.weeks.ago)
    assert_nil link_to_responses_in_last_week(survey)

    survey.survey_answers.update_all(:last_answered_at => 2.days.ago)
    assert_equal "(<a class=\"light_green_link\" href=\"/surveys/#{survey.id}/responses?last_week_response=true\">#{survey.survey_answers.pluck(:response_id).uniq.count} new responses this week</a>)", link_to_responses_in_last_week(survey)
  end

  def test_get_select2_options
    survey = surveys(:progress_report)
    program = survey.program
    choices = program.roles.select{|r| !r.administrative}.map{|role| {:id => role.name, :text => program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name).term}}

    content = get_select2_options(survey, choices, false)
    assert_equal "<div id=\"filter_survey_report_by_role_container\"><div class=\"controls \"><label for=\"role_choice\" class=\"sr-only\">Select value for user role filter.</label><input type=\"hidden\" name=\"roles_filter\" id=\"role_choice\" value=\"\" class=\"col-xs-12 no-padding\" data-placeholder=\"Select Choices\" /></div></div><script>\n//<![CDATA[\nReportFilters.displaySelect2Choices('mentor,student', 'Mentor,Student', ',', 'role_choice')\n//]]>\n</script>", content
  end

  def test_get_role_select2_choices
    program = programs(:no_mentor_request_program)
    roles = program.roles.select{|r| !r.administrative}

    assert_equal [{:id => "mentor", :text => "Mentor"}, {:id => "student", :text => "Student"}], get_role_select2_choices(roles, program)
  end

  def test_get_question_choices_for_select2
    survey_questions = [common_questions(:q3_from), common_questions(:q3_name)]

    id_hash, text_hash = get_question_choices_for_select2(survey_questions)

    expected_id_hash = {"answers#{common_questions(:q3_from).id}" => question_choices(:q3_from_1, :q3_from_2, :q3_from_3).collect(&:id).join(CommonQuestion::SELECT2_SEPARATOR)}
    expected_text_hash = {"answers#{common_questions(:q3_from).id}" => question_choices(:q3_from_1, :q3_from_2, :q3_from_3).collect(&:text).join(CommonQuestion::SELECT2_SEPARATOR)}
    assert_equal_hash expected_id_hash, id_hash
    assert_equal_hash expected_text_hash, text_hash

    profile_questions = [profile_questions(:multi_choice_q), profile_questions(:private_q), profile_questions(:student_single_choice_q)]

    id_hash, text_hash = get_question_choices_for_select2(profile_questions)

    expected_id_hash = {"column#{profile_questions(:multi_choice_q).id}"=>question_choices(:multi_choice_q_1, :multi_choice_q_2, :multi_choice_q_3).collect(&:id).join(CommonQuestion::SELECT2_SEPARATOR), "column#{profile_questions(:student_single_choice_q).id}" => question_choices(:student_single_choice_q_1, :student_single_choice_q_2, :student_single_choice_q_3).collect(&:id).join(CommonQuestion::SELECT2_SEPARATOR)}

    expected_text_hash = {"column#{profile_questions(:multi_choice_q).id}"=>question_choices(:multi_choice_q_1, :multi_choice_q_2, :multi_choice_q_3).collect(&:text).join(CommonQuestion::SELECT2_SEPARATOR), "column#{profile_questions(:student_single_choice_q).id}" => question_choices(:student_single_choice_q_1, :student_single_choice_q_2, :student_single_choice_q_3).collect(&:text).join(CommonQuestion::SELECT2_SEPARATOR)}

    assert_equal_hash expected_id_hash, id_hash
    assert_equal_hash expected_text_hash, text_hash
  end

  def test_options_for_select_for_questions
    questions = [profile_questions(:multi_choice_q), profile_questions(:private_q), profile_questions(:student_single_choice_q), profile_questions(:mentor_file_upload_q)]
    assert_equal "<option value=\"\">Select...</option>\n<option class=\"cjs_choice_based_question\" value=\"column#{profile_questions(:multi_choice_q).id}\">What is your name</option>\n<option class=\"cjs_text_question\" value=\"column#{profile_questions(:private_q).id}\">What is your favorite location stop</option>\n<option class=\"cjs_choice_based_question\" value=\"column#{profile_questions(:student_single_choice_q).id}\">What is your hobby</option>\n<option class=\"cjs_file_question\" value=\"column#{profile_questions(:mentor_file_upload_q).id}\">Upload your Resume</option>", options_for_select_for_questions(questions, false)

    questions = [common_questions(:common_questions_1), common_questions(:common_questions_2), common_questions(:common_questions_3)]
    assert_equal "<option value=\"\">Select...</option>\n<option class=\"cjs_choice_based_question\" value=\"answers#{common_questions(:common_questions_1).id}\">How was your overall meeting experience?</option>\n<option class=\"cjs_choice_based_question\" value=\"answers#{common_questions(:common_questions_2).id}\">What was discussed in your meeting?</option>\n<option class=\"cjs_choice_based_question\" value=\"answers#{common_questions(:common_questions_3).id}\">Why was the meeting cancelled?</option>", options_for_select_for_questions(questions, true)
  end

  def test_questions_container_operator_options
    assert_equal [["Select...", ""], ["Contains", SurveyResponsesDataService::Operators::CONTAINS, {:class=>"cjs_additional_text_box"}], ["Does not contain", SurveyResponsesDataService::Operators::NOT_CONTAINS, {:class=>"cjs_additional_text_box cjs_choice_based_operator"}], ["Filled", SurveyResponsesDataService::Operators::FILLED], ["Not Filled", SurveyResponsesDataService::Operators::NOT_FILLED]], questions_container_operator_options
  end

  def test_render_user_survey_answer_for_groups_listing_page
    question = common_questions(:common_questions_1)
    ans = CommonAnswer.create!(answer_value: {answer_text: 'Very useful', question: question}, common_question: question, user: users(:f_student))
    assert_equal "-", render_user_survey_answer_for_groups_listing_page(question, {})
    assert_equal "Very useful", render_user_survey_answer_for_groups_listing_page(question, {question.id => ans})
    question = create_matrix_survey_question
    rq1, rq2, rq3 = question.rating_questions
    ans1 = CommonAnswer.create!(answer_value: {answer_text: 'Very Good', question: rq1}, common_question: rq1, user: users(:f_student))
    ans2 = CommonAnswer.create!(answer_value: {answer_text: 'Good', question: rq2}, common_question: rq2, user: users(:f_student))
    ans3 = CommonAnswer.create!(answer_value: {answer_text: 'Poor', question: rq3}, :common_question => rq3, :user => users(:f_student))
    assert_equal "<div>Leadership - <i class=\"text-muted\">Not specified</i></div><div>Team Work - <i class=\"text-muted\">Not specified</i></div><div>Communication - <i class=\"text-muted\">Not specified</i></div>", render_user_survey_answer_for_groups_listing_page(question, {})
    assert_equal "<div>Leadership - Very Good</div><div>Team Work - Good</div><div>Communication - Poor</div>", render_user_survey_answer_for_groups_listing_page(question, {rq1.id => ans1, rq2.id => ans2, rq3.id => ans3})
  end

  def test_get_survey_type_for_ga
    assert_equal "EngagementSurvey", get_survey_type_for_ga(EngagementSurvey.first)
    MeetingFeedbackSurvey.any_instance.stubs(:role_name).returns('mentor')
    assert_equal "MentorMeetingFeedbackSurvey", get_survey_type_for_ga(MeetingFeedbackSurvey.first)
  end

  def test_get_survey_question_condition_options
    assert_equal [["Always", 0], ["If meeting is completed", 1], ["If meeting is cancelled", 2]], get_survey_question_condition_options
  end

  def test_last_question_of_completed_or_cancelled_type_error_flash
    assert_equal "At least one question which is shown 'Always' or 'If meeting is completed' needs to be present.", last_question_of_completed_or_cancelled_type_error_flash(SurveyQuestion::Condition::COMPLETED)
    assert_equal "At least one question which is shown 'Always' or 'If meeting is cancelled' needs to be present.", last_question_of_completed_or_cancelled_type_error_flash(SurveyQuestion::Condition::CANCELLED)
  end

  def test_render_surveys_title
    content = render_surveys_title("Program", "ProgramSurvey")
    assert_select_helper_function_block "h5", content, text: "Program Surveys" do
      assert_select "span[data-toggle=\"tooltip\"]" do
        assert_select "i.fa.fa-info-circle"
      end
    end
    assert_select_helper_function "a.cjs_new_survey_button", content, text: "New Survey"

    content = render_surveys_title("Meeting", "MeetingFeedbackSurvey")
    assert_select_helper_function_block "h5", content, text: "Meeting Surveys" do
      assert_select "span[data-toggle=\"tooltip\"]" do
        assert_select "i.fa.fa-info-circle"
      end
    end
    assert_select_helper_function "a.cjs_new_survey_button", content, text: "New Survey", count: 0
  end

  def test_render_progress_report_checkbox
    survey = surveys(:progress_report)
    content = render_progress_report_checkbox(survey, {wrapper_class: "wrapper_class", class: "inner_class"})
    assert_select_helper_function_block "div#engagement_survey_options.wrapper_class", content do
      assert_select "div#progress_report.col-sm-offset-3.col-sm-9.inner_class" do
        assert_select "label.checkbox", text: "Allow respondent to share the response with other mentoring connection members" do
          assert_select "input[type='checkbox'][name='survey[progress_report]']"
        end
      end
    end
  end

  def test_render_share_progress_report_checkbox
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    survey.expects(:can_share_progress_report?).returns(true)
    content = render_share_progress_report_checkbox(survey, group)
    assert_select_helper_function_block "div.well", content do
      assert_select "label.checkbox", text: "Send a copy of my response to others in the mentoring connection" do
        assert_select "input[type='checkbox'][name='share_progress_report'][checked='checked']"
      end
    end
  end

  def test_get_survey_info
    group = groups(:no_mreq_group)
    meeting = meetings(:f_mentor_mkr_student)
    assert_equal "Meeting: Arbit Topic", get_survey_info(nil, meeting)
    assert_equal "Mentoring Connection: <a href=\"/groups/#{group.id}\">No mentor request group</a>", get_survey_info(group, nil)
    assert_nil get_survey_info(nil, nil)
  end

  def test_get_class_for_profile_question_filter_options
    question = ProfileQuestion.new(question_type: 2)
    assert_equal "cjs_choice_based_question", self.send(:get_class_for_profile_question_filter_options, question, false)
    question.question_type = 5
    assert_equal "cjs_file_question", self.send(:get_class_for_profile_question_filter_options, question, false)
    question.question_type = 20
    assert_equal "cjs_date_question", self.send(:get_class_for_profile_question_filter_options, question, false)
    assert_equal "cjs_text_question", self.send(:get_class_for_profile_question_filter_options, question, true)
    question.question_type = 0
    assert_equal "cjs_text_question", self.send(:get_class_for_profile_question_filter_options, question, false)
  end

  def test_get_question_text
    question = common_questions(:common_questions_1)
    assert_equal "<i class=\"fa fa-comments-o fa-fw m-r-xs\"></i>How was your overall meeting experience?", get_question_text(question)
    assert_equal "How was your overall meeting experience?", get_question_text(question, pdf_view: true)
  end

  private

  def _mentoring_connection
    "mentoring connection"
  end

  def _mentoring_connections
    "mentoring connections"
  end

  def _Program
    "Program"
  end

  def _meeting
    "meeting"
  end

  def _Meeting
    "Meeting"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end
end