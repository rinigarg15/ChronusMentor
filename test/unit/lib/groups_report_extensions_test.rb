require_relative "./../../test_helper.rb"

class GroupsReportExtensionsTest < ActiveSupport::TestCase
  include GroupsReportExtensions
  include GroupsReportHelper

  TEMP_CSV_FILE = "test/fixtures/files/groups_report_test_file.csv"

  def setup
    super
    @program = programs(:psg)
    @u1 = users(:psg_mentor)
    @u2 = users(:psg_mentor1)
    @u3 = users(:psg_mentor2)
    @u4 = users(:psg_mentor3)
    @u5 = users(:psg_student1)
    @u6 = users(:psg_student2)

    groups(:multi_group).destroy
    @group = create_group(name: "Group", mentors: [@u2, @u3], students: [@u5], program: @program)
    @troop = create_group(name: "Troop", mentors: [@u1], students: [@u6], program: @program)
    @batch = create_group(name: "Batch", mentors: [@u4], students: [@u5, @u6], program: @program)
    @groups = @program.groups

    @start_time = @program.created_at.beginning_of_day
  end

  def test_sort_by_group_name
    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::GROUP, "asc", @start_time, Time.now.utc)
    assert_equal ["Batch", "Group", "Troop"], sorted_groups.collect(&:name)
  end

  def test_sort_by_started_on
    sleep 1
    @squad = create_group(name: "Squad", mentors: [@u1], students: [@u5], program: @program)
    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::STARTED_ON, "desc", @start_time, Time.now.utc)
    assert_equal "Squad", sorted_groups.first.name
  end

  def test_sort_by_close_date
    @troop.auto_terminate_due_to_inactivity!
    @troop = @troop.reload
    @batch.change_expiry_date(users(:f_admin), @batch.expiry_time+3.months, "Peace")
    @batch = @batch.reload
    expected_order = ["Troop", "Group", "Batch"]
    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::CLOSE_DATE, "asc", @start_time, Time.now.utc)
    assert_equal expected_order, sorted_groups.collect(&:name)
  end


  def test_role_sort_by_name
    sorted_by_mentors = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTORS, "desc", @start_time, Time.now.utc)
    assert_equal ["PSG mentorc"], sorted_by_mentors.first.mentors.collect(&:name)
    assert_equal ["Batch", "Group", "Troop"], sorted_by_mentors.collect(&:name)

    sorted_by_students = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTEES, "asc", @start_time, Time.now.utc)
    assert_equal "studa psg", sorted_by_students.first.students.collect(&:name)[0]
  end

  def test_sort_by_messages_count
    create_scrap(group: @troop)
    create_scrap(group: @troop)
    create_scrap(group: @batch)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT, "asc", @start_time, Time.now.utc)
    assert_equal ["Group", "Batch", "Troop"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT, "desc", @start_time, Time.now.utc)
    assert_equal ["Troop", "Batch", "Group"], sorted_groups.collect(&:name)
  end

  def test_role_sort_by_messages_count
    create_scrap(group: @group, :sender => @u2.member)
    create_scrap(group: @group, :sender => @u3.member)
    create_scrap(group: @troop, :sender => @u1.member)
    time_traveller(1.day.from_now) do
      create_scrap(group: @troop, :sender => @u6.member)
      create_scrap(group: @troop, :sender => @u6.member)
      create_scrap(group: @batch, :sender => @u5.member)
    end
    create_scrap(group: @batch, :sender => @u6.member)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT, "asc", @start_time, Time.now.utc)
    assert_equal ["Batch", "Troop", "Group"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT, "desc", 1.hour.from_now, 2.days.from_now)
    assert_equal ["Troop", "Batch", "Group"], sorted_groups.collect(&:name)
  end

  def test_sort_by_tasks_count
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: @u3, completed_date: Time.now.utc.to_date)
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: @u5, completed_date: Time.now.utc.to_date)
    create_mentoring_model_task(group: @troop, status: MentoringModel::Task::Status::DONE, user: @u6, completed_date: Time.now.utc.to_date)
    create_mentoring_model_task(group: @troop, status: MentoringModel::Task::Status::DONE, user: @u6, completed_date: 2.days.from_now.to_date)
    create_mentoring_model_task(group: @batch, status: MentoringModel::Task::Status::TODO, user: @u6)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::TASKS_COUNT, "asc", @start_time, Time.now.utc)
    assert_equal ["Batch", "Troop", "Group"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::TASKS_COUNT, "desc", @start_time, Time.now.utc)
    assert_equal ["Group", "Troop", "Batch"], sorted_groups.collect(&:name)
  end

  def test_role_sort_by_tasks_count
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: @u5, completed_date: Time.now.utc.to_date)
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: @u5, completed_date: 1.day.from_now.to_date)
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: @u3, completed_date: 1.day.from_now.to_date)
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: @u3, completed_date: 1.day.from_now.to_date)
    create_mentoring_model_task(group: @troop, status: MentoringModel::Task::Status::DONE, user: @u1, completed_date: 20.minutes.from_now.to_date)
    create_mentoring_model_task(group: @batch, status: MentoringModel::Task::Status::DONE, user: @u5, completed_date: 3.days.from_now.to_date)
    create_mentoring_model_task(group: @batch, status: MentoringModel::Task::Status::TODO, user: @u6)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT, "desc", @start_time, 5.days.from_now)
    assert_equal ["Group", "Batch", "Troop"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT, "asc", @start_time, 5.days.from_now.to_date)
    assert_equal ["Batch", "Troop", "Group"], sorted_groups.collect(&:name)
  end

  def test_sort_by_current_status
    @troop.update_attributes!(status: Group::Status::INACTIVE)
    group = @batch
    group.status = Group::Status::CLOSED
    group.closed_at = Time.now
    group.closed_by = users(:psg_only_admin)
    group.termination_mode = Group::TerminationMode::ADMIN
    group.closure_reason_id = group.get_auto_terminate_reason_id
    group.save!

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::CURRENT_STATUS, "asc", @start_time, Time.now.utc)
    assert_equal ["Group", "Batch", "Troop"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::CURRENT_STATUS, "desc", @start_time, Time.now.utc)
    assert_equal ["Troop", "Batch", "Group"], sorted_groups.collect(&:name)
  end

  def test_sort_by_survey_responses_count
    survey = create_engagement_survey(:name => "Test Survey", :program => @program)
    create_survey_question({survey: survey, program: @program})

    survey1 = create_engagement_survey(:name => "Test Survey1", :program => @program)
    create_survey_question({survey: survey1, program: @program})

    response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    
    task = create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::TODO, user: @u2, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    task2 = create_mentoring_model_task(group: @troop, status: MentoringModel::Task::Status::TODO, user: @u1, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey1.id)
    task3 = create_mentoring_model_task(group: @batch, status: MentoringModel::Task::Status::TODO, user: @u4, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey1.id)

    task.action_item.survey_questions.each do |ques|
      ans = task.survey_answers.new(:user => @u2, :response_id => response_id, :answer_text => "Good", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
    response_id2 = SurveyAnswer.maximum(:response_id).to_i + 1
    task2.action_item.survey_questions.each do |ques|
      ans1 = task2.survey_answers.new(:user => @u1, :response_id => response_id2, :answer_text => "Poor", :last_answered_at => Time.now.utc, group_id: @troop.id, group: @troop)
      ans1.survey_question = ques
      ans1.save!
    end

    task.action_item.survey_questions.each do |ques|
      ans2 = task.survey_answers.new(:user => @u5, :response_id => response_id, :answer_text => "Very Good", :last_answered_at => Time.now.utc)
      ans2.survey_question = ques
      ans2.save!
    end

    response_id3 = SurveyAnswer.maximum(:response_id).to_i + 1

    task3.action_item.survey_questions.each do |ques|
      ans1 = task2.survey_answers.new(:user => @u4, :response_id => response_id3, :answer_text => "Poor", :last_answered_at => Time.now.utc, group_id: @batch.id, group: @batch, is_draft: true)
      ans1.survey_question = ques
      ans1.save!
    end

    task3.action_item.survey_questions.each do |ques|
      ans1 = task2.survey_answers.new(:user => @u5, :response_id => response_id3, :answer_text => "Poor", :last_answered_at => Time.now.utc, group_id: @batch.id, group: @batch, is_draft: true)
      ans1.survey_question = ques
      ans1.save!
    end
      
    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT, "desc", @start_time, 5.days.from_now)
    assert_equal ["Group", "Troop", "Batch"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT, "asc", @start_time, 5.days.from_now)
    assert_equal ["Batch", "Troop", "Group"], sorted_groups.collect(&:name)
  end

  def test_role_sort_by_survey_responses_count
    survey = create_engagement_survey(:name => "Test Survey", :program => @program)
    create_survey_question({survey: survey, program: @program})

    survey1 = create_engagement_survey(:name => "Test Survey1", :program => @program)
    create_survey_question({survey: survey1, program: @program})

    response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    
    task = create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::TODO, user: @u2, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    task2 = create_mentoring_model_task(group: @troop, status: MentoringModel::Task::Status::TODO, user: @u1, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey1.id)
    task3 = create_mentoring_model_task(group: @batch, status: MentoringModel::Task::Status::TODO, user: @u6, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey1.id)

    task.action_item.survey_questions.each do |ques|
      ans = task.survey_answers.new(:user => @u2, :response_id => response_id, :answer_text => "Good", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
    response_id2 = SurveyAnswer.maximum(:response_id).to_i + 1
    task2.action_item.survey_questions.each do |ques|
      ans1 = task2.survey_answers.new(:user => @u1, :response_id => response_id2, :answer_text => "Poor", :last_answered_at => Time.now.utc, group_id: @troop.id, group: @troop)
      ans1.survey_question = ques
      ans1.save!
    end

    student_response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    task.action_item.survey_questions.each do |ques|
      ans2 = task.survey_answers.new(:user => @u3, :response_id => response_id, :answer_text => "Very Good", :last_answered_at => Time.now.utc)
      ans2.survey_question = ques
      ans2.save!
    end

    task3.action_item.survey_questions.each do |ques|
      ans2 = task3.survey_answers.new(:user => @u6, :response_id => student_response_id, :answer_text => "Very Good", :last_answered_at => Time.now.utc)
      ans2.survey_question = ques
      ans2.save!
    end

    task3.action_item.survey_questions.each do |ques|
      ans2 = task3.survey_answers.new(:user => @u5, :response_id => student_response_id, :answer_text => "Very Good", :last_answered_at => Time.now.utc)
      ans2.survey_question = ques
      ans2.save!
    end

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT, "desc", @start_time, 5.days.from_now)
    assert_equal ["Group", "Troop", "Batch"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT, "asc", @start_time, 5.days.from_now)
    assert_equal ["Batch", "Troop", "Group"], sorted_groups.collect(&:name)
  end

  def test_sort_by_posts_count
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    group_topic, troop_topic, batch_topic = create_topics_for_groups

    create_post(topic: group_topic, user: @u2)
    create_post(topic: group_topic, user: @u3)
    create_post(topic: troop_topic, user: @u1)
    create_post(topic: batch_topic, user: @u4)
    create_post(topic: batch_topic, user: @u5)
    create_post(topic: batch_topic, user: @u6)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::POSTS_COUNT, "asc", @start_time, Time.now.utc)
    assert_equal ["Troop", "Group", "Batch"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::POSTS_COUNT, "desc", @start_time, Time.now.utc)
    assert_equal ["Batch", "Group", "Troop"], sorted_groups.collect(&:name)
  end

  def test_role_sort_by_posts_count
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    group_topic, troop_topic, batch_topic = create_topics_for_groups

    create_post(topic: group_topic, user: @u2)
    create_post(topic: group_topic, user: @u3)
    create_post(topic: troop_topic, user: @u1)
    create_post(topic: troop_topic, user: @u1)
    create_post(topic: troop_topic, user: @u1)
    create_post(topic: batch_topic, user: @u4)
    create_post(topic: batch_topic, user: @u5)
    create_post(topic: batch_topic, user: @u6)
    create_post(topic: troop_topic, user: @u6)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT, "asc", @start_time, Time.now.utc)
    assert_equal ["Group", "Troop", "Batch"], sorted_groups.collect(&:name)

    sorted_groups = sort_by_groups_report_column(@groups, ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT, "desc", @start_time, Time.now.utc)
    assert_equal ["Troop", "Group", "Batch"], sorted_groups.collect(&:name)
  end

  def test_update_groups_report_view
    report_view_columns = @program.report_view_columns.for_groups_report
    assert_equal ["group", "mentors", "mentees", "started_on", "close_date", "messages_count", "total_activities", "current_status"], report_view_columns.collect(&:column_key)

    update_groups_report_view!(@program, ["mentee_tasks_count", "group", "mentors"])
    assert_equal ["mentee_tasks_count", "group", "mentors"], report_view_columns.reload.collect(&:column_key)
  end

  def test_export_groups_report_to_stream
    custom_term_options = {
      :Mentor => "Mentor",
      :Mentee => "Mentee",
      :Mentors => "Mentors",
      :Mentees => "Mentees",
      :Meetings => "Meetings",
      :Mentoring_Connection => "Engagement"
    }
    @troop.auto_terminate_due_to_inactivity!
    @troop = @troop.reload
    report_view_columns = @program.report_view_columns.for_groups_report
    groups_report = GroupsReport.new(@program, report_view_columns.pluck(:column_key), {start_time: @start_time, end_time: Time.now.utc})
    groups_report.compute_data_for_table_row_or_csv
    body = Enumerator.new { |stream| export_groups_report_to_stream(stream, groups_report, @groups, report_view_columns, custom_term_options) }
    csv_array = CSV.parse(body.to_a.join)
    started_on = [@group, @troop, @batch].collect {|grp| format_date_for_view(grp.published_at) }
    close_date = [format_date_for_view(@group.expiry_time), format_date_for_view(@troop.closed_at), format_date_for_view(@batch.expiry_time)]
    assert_equal ["Engagement", "Mentors", "Mentees", "Started on", "Close date", "Messages", "Total Activities", "Current Status"], csv_array[0]
    assert_equal ["Group", "PSG mentora and PSG mentorb", "studa psg"] + [started_on[0], close_date[0], "0", "0", "active"], csv_array[1]
    assert_equal ["Troop", "mental mentor", "studb psg"] + [started_on[1], close_date[1], "0", "0", "closed"], csv_array[2]
    assert_equal ["Batch", "PSG mentorc", "studa psg and studb psg"] + [started_on[2], close_date[2], "0", "0", "active"], csv_array[3]
  end

  def test_get_groups_report_eager_loadables
    report_view_columns = @program.report_view_columns.for_groups_report
    assert_equal_unordered [{:mentors=>[:roles, :member]}, {:students=>[:roles, :member]}], get_groups_report_eager_loadables(report_view_columns.pluck(:column_key))

    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT)
    assert_equal_unordered [{:mentors=>[:roles, :member]}, {:students=>[:roles, :member]}, {:program=>[:disabled_db_features, :enabled_db_features, {:organization=>:enabled_db_features}]}],
      get_groups_report_eager_loadables(report_view_columns.reload.pluck(:column_key))
  end

  private

  def create_topics_for_groups
    [@group, @troop, @batch].collect do |group|
      forum = create_forum(name: "Forum for #{group.name}", description: "Discussion Board", group_id: group.id)
      create_topic(forum: forum, user: group.mentors.first)
    end
  end

  def setup_memberships
    @group.memberships.where(user_id: @u2.id).first.update_attributes!(login_count: 2)
    @group.memberships.where(user_id: @u3.id).first.update_attributes!(login_count: 2)
    @group.memberships.where(user_id: @u5.id).first.update_attributes!(login_count: 2)
    @troop.memberships.where(user_id: @u1.id).first.update_attributes!(login_count: 2)
    @troop.memberships.where(user_id: @u6.id).first.update_attributes!(login_count: 3)
    @batch.memberships.where(user_id: @u4.id).first.update_attributes!(login_count: 3)
  end
end