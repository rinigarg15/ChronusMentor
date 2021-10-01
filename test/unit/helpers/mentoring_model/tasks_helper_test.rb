require_relative './../../../test_helper.rb'

class MentoringModel::TasksHelperTest < ActionView::TestCase

  def test_new_task_action_item_options
    group = groups(:mygroup)

    expects(:manage_mm_meetings_at_end_user_level?).at_least_once.with(group).returns(false)
    expects(:manage_mm_goals_at_end_user_level?).at_least_once.with(group).returns(false)
    assert_equal [["Select...", 0]], new_task_action_item_options(group)

    expects(:manage_mm_meetings_at_end_user_level?).with(group).returns(true)
    expects(:manage_mm_goals_at_end_user_level?).with(group).returns(false)
    assert_equal [["Select...", 0], ["Set up a meeting", 1]], new_task_action_item_options(group)

    expects(:manage_mm_meetings_at_end_user_level?).with(group).returns(false)
    expects(:manage_mm_goals_at_end_user_level?).with(group).returns(true)
    assert_equal [["Select...", 0], ["Create Goal Plan", 2]], new_task_action_item_options(group)

    expects(:manage_mm_meetings_at_end_user_level?).with(group).returns(true)
    expects(:manage_mm_goals_at_end_user_level?).with(group).returns(true)
    assert_equal [["Select...", 0], ["Set up a meeting", 1], ["Create Goal Plan", 2]], new_task_action_item_options(group)
  end

  def test_get_snippet_color
    status = :overdue
    options = {modified_task_bar: true}
    assert_nil get_snippet_color(status, options)

    status = :overdue
    assert_equal "text-danger", get_snippet_color(status, {})
  end

  def test_generate_mentoring_model_filter_class
    group = groups(:mygroup)
    assert_nil set_response_text(generate_mentoring_model_filter_class(nil))
    t1 = create_mentoring_model_task(group_id: group.id)
    assert_equal "cjs-mentoring-model-filter-for-task-and-meetings-#{t1.user.try(:id)}", set_response_text(generate_mentoring_model_filter_class(t1))
  end

  def test_get_assignee_container_select_box
    group = groups(:multi_group)
    task = group.mentoring_model_tasks.new(status: MentoringModel::Task::Status::TODO, required: false)
    user = group.mentor_memberships.first.user

    # new with group mentoring
    assert user.program.allow_one_to_many_mentoring?
    content = get_assignee_container_select_box(task, group, user)
    assert_select_helper_function "select#mentoring_model_task_connection_membership_id", content, class: "form-control", name: "mentoring_model_task[connection_membership_id]"
    assert_select_helper_function "optgroup", content, label: "Mentoring Connection Members"
    assert_select_helper_function "optgroup", content, label: "Students"
    assert_select_helper_function "optgroup", content, label: "Mentors"
    assert_select_helper_function "option", content, value: MentoringModel::TasksHelper::FOR_ALL_USERS, text: "All Users (New task for every current user)"
    assert_select_helper_function "option", content, value: "#{MentoringModel::TasksHelper::FOR_ALL_ROLE_ID}#{group.program.roles.find_by(name: RoleConstants::MENTOR_NAME).id}", text: "All Users (New task for every current user)"
    assert_select_helper_function "option", content, value: "#{MentoringModel::TasksHelper::FOR_ALL_ROLE_ID}#{group.program.roles.find_by(name: RoleConstants::STUDENT_NAME).id}", text: "All Users (New task for every current user)"
    group.memberships.each { |membership| assert_select_helper_function "option", content, value: membership.id.to_s, text: membership.user.name }

    # new with 1:1 mentoring
    user.program.allow_one_to_many_mentoring = false
    content = get_assignee_container_select_box(task, group, user)
    assert_nil content.match(/optgroup/)
    assert_nil content.match(/New task for every current/)
    group.memberships.each { |membership| assert_select_helper_function "option", content, value: membership.id.to_s, text: membership.user.name }

    # edit case
    task.expects(:new_record?).returns(false)
    content = get_assignee_container_select_box(task, group, user)
    assert_nil content.match(/optgroup/)
    assert_nil content.match(/New task for every current/)
    group.memberships.each { |membership| assert_select_helper_function "option", content, value: membership.id.to_s, text: membership.user.name }
  end

  def test_display_tasks_progress_bar_tasks_snippet
    group = groups(:mygroup)
    t1 = create_mentoring_model_task(group_id: group.id)
    t1.update_attributes!(status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(group_id: group.id)
    create_mentoring_model_task(group_id: group.id)
    t2 = create_mentoring_model_task(group_id: group.id, required: true, due_date: Date.today - 2.days)
    create_mentoring_model_task(group_id: group.id, required: true, due_date: Date.today + 2.days)

    set_response_text(display_tasks_progress_bar(group.reload.mentoring_model_tasks.all))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar-black"
      assert_select "div.progress-bar-danger"
      assert_select "div.progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span", text: "1 Task Completed"
      assert_select "span.text-danger", text: "1 Task Overdue"
      assert_select "span.text-muted", text: "3 Tasks Pending"
    end

    t2.update_attributes!(status: MentoringModel::Task::Status::DONE)

    set_response_text(display_tasks_progress_bar(group.reload.mentoring_model_tasks.all))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar-black"
      assert_no_select "div.progress-bar-danger"
      assert_select "div.progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span", text: "2 Tasks Completed"
      assert_select "span.text-danger", text: "0 Tasks Overdue"
      assert_select "span.text-muted", text: "3 Tasks Pending"
    end

    group.mentoring_model_tasks.each do |task|
      task.update_attributes!(status: MentoringModel::Task::Status::DONE)
    end

    set_response_text(display_tasks_progress_bar(group.reload.mentoring_model_tasks.all))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar-black"
      assert_no_select "progress-bar-danger"
      assert_no_select "progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span", text: "5 Tasks Completed"
      assert_select "span.text-danger", text: "0 Tasks Overdue"
      assert_select "span.text-muted", text: "0 Tasks Pending"
    end
  end

  def test_display_tasks_progress_bar_tasks_snippet_for_goals
    group = groups(:mygroup)
    g1 = create_mentoring_model_goal
    t1 = create_mentoring_model_task(group_id: group.id, goal_id: g1.id, required: true)
    t1.update_attributes!(status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(group_id: group.id, goal_id: g1.id, required: true)
    create_mentoring_model_task(group_id: group.id, goal_id: g1.id, required: true)
    t2 = create_mentoring_model_task(group_id: group.id, required: true, due_date: Date.today - 2.days, goal_id: g1.id)
    create_mentoring_model_task(group_id: group.id, required: true, due_date: Date.today + 2.days)

    set_response_text(display_tasks_progress_bar(g1.reload.mentoring_model_tasks, {goal_status: g1.completion_percentage(group.mentoring_model_tasks.required), connection_and_reports_page: true, from_goals: true}))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar-black"
      assert_select "div.progress-bar-danger"
      assert_select "div.progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span.font-bold", text: "Tasks:"
      assert_select "span", text: "1 Completed"
      assert_select "span.text-success", text: ""
      assert_select "span.text-danger", text: "1 Overdue"
      assert_select "span.text-muted", text: "2 Pending"
    end

    t2.update_attributes!(status: MentoringModel::Task::Status::DONE)

    set_response_text(display_tasks_progress_bar(g1.reload.mentoring_model_tasks, {goal_status: g1.completion_percentage(group.mentoring_model_tasks.required), connection_and_reports_page: false, from_goals: true}))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar-black"
      assert_no_select "div.progress-bar-danger"
      assert_select "div.progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span.font-bold", text: "Tasks:"
      assert_select "span", text: "2 Completed"
      assert_select "span.text-success", text: "50% Complete"
      assert_select "span.text-danger", text: "0 Overdue"
      assert_select "span.text-muted", text: "2 Pending"
    end

    group.mentoring_model_tasks.each do |task|
      task.update_attributes!(status: MentoringModel::Task::Status::DONE)
    end

    set_response_text(display_tasks_progress_bar(g1.reload.mentoring_model_tasks, {goal_status: g1.completion_percentage(group.mentoring_model_tasks.required), connection_and_reports_page: true, from_goals: true}))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar-black"
      assert_no_select "div.progress-bar-danger"
      assert_no_select "div.progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span.font-bold", text: "Tasks:"
      assert_select "span.text-success", text: ""
      assert_select "span", text: "4 Completed"
      assert_select "span.text-danger", text: "0 Overdue"
      assert_select "span.text-muted", text: "0 Pending"
    end

    set_response_text(display_tasks_progress_bar(g1.reload.mentoring_model_tasks, {goal_status: g1.completion_percentage(group.mentoring_model_tasks.required), connection_and_reports_page: false, reports_page: true}))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar"
      assert_no_select "div.progress-bar-black"
      assert_no_select "div.progress-bar-danger"
      assert_no_select "div.progress-bar-dark-gray"
    end

    assert_no_select "div.tasks_snippet"

    set_response_text(display_tasks_progress_bar(g1.reload.mentoring_model_tasks, {goal_status: g1.completion_percentage(group.mentoring_model_tasks.required), connection_and_reports_page: true, modified_task_bar: true}))

    assert_select "div.progress-small" do
      assert_select "div.progress-bar"
      assert_no_select "div.progress-bar-black"
      assert_no_select "div.progress-bar-danger"
      assert_no_select "div.progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span", text: "Completed: 4"
      assert_select "span", text: "Overdue: 0"
      assert_select "span", text: "Pending: 0"
    end
  end

  def test_display_tasks_progress_bar_with_modified_task_bar
    group = groups(:mygroup)
    g1 = create_mentoring_model_goal
    create_mentoring_model_task(group_id: group.id, goal_id: g1.id, required: true)
    create_mentoring_model_task(group_id: group.id, goal_id: g1.id, required: true)
    create_mentoring_model_task(group_id: group.id, goal_id: g1.id, required: true)
    create_mentoring_model_task(group_id: group.id, required: true, due_date: Date.today - 2.days, goal_id: g1.id)
    create_mentoring_model_task(group_id: group.id, required: true, due_date: Date.today + 2.days)

    set_response_text(display_tasks_progress_bar(g1.reload.mentoring_model_tasks, {goal_status: g1.completion_percentage(group.mentoring_model_tasks.required), connection_and_reports_page: true, modified_task_bar: true}))

    assert_select "div.progress-small" do
      assert_no_select "div.progress-bar-black"
      assert_no_select "div.progress-bar-danger"
      assert_select "div.progress-bar-dark-gray"
    end

    assert_select "div.tasks_snippet" do
      assert_select "span", text: "Completed: 0"
      assert_select "span", text: "Overdue: 1"
      assert_select "span", text: "Pending: 3"
    end
  end

  def test_get_date_for_required_task_else_default_date
    group = groups(:mygroup)
    t1 = create_mentoring_model_task(group_id: group.id, required: true, due_date: 2.days.from_now.to_date)

    content = get_date_for_required_task_else_default_date(t1)
    set_response_text(content)
    assert_equal content, DateTime.localize(t1.due_date, format: :full_display_no_time)

    t2 = create_mentoring_model_task(group_id: group.id)
    content = get_date_for_required_task_else_default_date(t2)
    set_response_text(content)
    assert_equal content, DateTime.localize(Date.today + 7.days, format: :full_display_no_time)
  end

  def test_reports_page_or_modified_tasks(options={})
    options = {reports_page: true}
    assert reports_page_or_modified_tasks(options)

    assert_false reports_page_or_modified_tasks({})

    options = {modified_task_bar: true}
    assert reports_page_or_modified_tasks(options)

    options = {reports_page: true , modified_task_bar: true}
    assert reports_page_or_modified_tasks(options)
  end

  def test_get_progress_bar_class
    status = :completed
    options = {reports_page: true}
    assert_nil get_progress_bar_class(status, options)

    status = :overdue
    options = {reports_page: true}
    assert_equal "progress-bar-dark-gray", get_progress_bar_class(status, options)

    status = :overdue
    options = {}
    assert_equal "progress-bar-danger", get_progress_bar_class(status, options)

    status = :completed
    options = {}
    assert_equal "progress-bar-black", get_progress_bar_class(status, options)
  end

  def test_get_task_count_per_status
    status = "completed"
    tasks_count = 1
    options = {modified_task_bar: true}

    assert_match "Completed: 1", get_task_count_per_status(status, tasks_count, options)

    status = "completed"
    tasks_count = 2
    options = {}
    get_task_count_per_status(status, tasks_count, options)
    assert_match "2 Tasks Completed", get_task_count_per_status(status, tasks_count, options)
  end

  def test_can_show_task_user
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    task1 = create_mentoring_model_task(required: true, due_date: Date.today + 3.days)
    assert can_show_task_user?(task1)
    task2 = create_mentoring_model_task(required: true, due_date: Date.today + 3.days, from_template: true,unassigned_from_template: true)
    assert_false can_show_task_user?(task2)
    task3 = create_mentoring_model_task(required: true, due_date: Date.today + 3.days, from_template: true,unassigned_from_template: false, connection_membership_id: nil)
    assert_false can_show_task_user?(task3)
  end

  private

  def _Meeting
    "Meeting"
  end

  def _a_meeting
    "a meeting"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end
end