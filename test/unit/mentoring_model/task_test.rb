require_relative './../../test_helper.rb'

class MentoringModel::TaskTest < ActiveSupport::TestCase
  def test_validations
    assert_multiple_errors([ { field: :group_id }, { field: :title }, { field: :required }, { field: :status } ]) do
      MentoringModel::Task.create!(unassigned_from_template: true)
    end
    mentoring_model_task = MentoringModel::Task.new(unassigned_from_template: true)
    mentoring_model_task.valid?
    assert_equal ["can't be blank"], mentoring_model_task.errors[:from_template]

    mentoring_model_task = MentoringModel::Task.new
    mentoring_model_task.valid?
    assert_empty mentoring_model_task.errors[:from_template]

    mentoring_model_task = MentoringModel::Task.new(required: true, due_date: nil, from_template: true)
    mentoring_model_task.valid?
    assert_equal ["can't be blank"], mentoring_model_task.errors[:due_date]
    assert_equal ["is not a number"], mentoring_model_task.errors[:template_version]

    mentoring_model_task.skip_due_date_validation = true
    mentoring_model_task.template_version = 1
    mentoring_model_task.valid?
    assert_empty mentoring_model_task.errors[:due_date]

    mentoring_model_task.update_attributes(due_date: 3.weeks.from_now)
    mentoring_model_task.valid?
    assert_empty mentoring_model_task.errors[:due_date]
  end

  def test_update_positions_create_new_with_due_date
    t0, t1, t2, t3, t4 = setup_for_update_position_tests
    tc1 = create_mentoring_model_task(required: true, due_date: Time.new(2002))
    MentoringModel::Task.update_positions(groups(:mygroup).mentoring_model_tasks, tc1)
    assert_equal  [0, 1, 2, 3, 4, 5], [t0, t1, t2, tc1, t3, t4].collect(&:reload).map(&:position)
    tc2 = create_mentoring_model_task(required: true, due_date: Time.new(2007))
    MentoringModel::Task.update_positions(groups(:mygroup).reload.mentoring_model_tasks, tc2)
    assert_equal  [0, 1, 2, 3, 4, 5, 6], [t0, t1, t2, tc1, t3, tc2, t4].collect(&:reload).map(&:position)
  end

  def test_update_positions_create_new_without_due_date
    t0, t1, t2, t3, t4 = setup_for_update_position_tests
    tc1 = create_mentoring_model_task(required: false, due_date: nil)
    MentoringModel::Task.update_positions(groups(:mygroup).mentoring_model_tasks, tc1)
    assert_equal  [0, 1, 2, 3, 4, 5], [t0, t1, t2, t3, t4, tc1].collect(&:reload).map(&:position)
  end

  def test_update_positions_edit_from_without_due_date_to_due_date
    t0, t1, t2, t3, t4 = setup_for_update_position_tests
    t1.required = true; t1.due_date = Time.new(2007); t1.save; t1.reload
    MentoringModel::Task.update_positions(groups(:mygroup).reload.mentoring_model_tasks, t1)
    assert_equal  [0, 1, 2, 3, 4], [t0, t2, t3, t1, t4].collect(&:reload).map(&:position)
  end

  def test_update_positions_edit_from_with_due_date_to_without_due_date
    t0, t1, t2, t3, t4 = setup_for_update_position_tests
    t3.required = false; t3.due_date = nil; t3.save; t3.reload
    MentoringModel::Task.update_positions(groups(:mygroup).reload.mentoring_model_tasks, t3)
    assert_equal  [0, 1, 2, 3, 4], [t0, t1, t2, t3, t4].collect(&:reload).map(&:position)
  end

  def test_belongs_to_mentoring_model_goal
    g1 = create_mentoring_model_goal
    t1 = create_mentoring_model_task(due_date: Time.new(2000), goal_id: g1.id)
    t2 = create_mentoring_model_task(due_date: Time.new(2003))

    assert_equal g1, t1.mentoring_model_goal
    assert_nil t2.mentoring_model_goal
  end

  def test_required_scope_for_mentoring_model_goal
    g1 = create_mentoring_model_goal
    t1 = create_mentoring_model_task(due_date: Time.new(2000), required: true, goal_id: g1.id)
    t2 = create_mentoring_model_task(due_date: Time.new(2003), required: true, goal_id: g1.id)
    t3 = create_mentoring_model_task(due_date: Time.new(2001), goal_id: g1.id)
    t4 = create_mentoring_model_task(due_date: Time.new(2002), required: true, goal_id: g1.id)

    assert_equal [t1, t4, t2], g1.mentoring_model_tasks.required
  end

  def test_user
    task = create_mentoring_model_task
    assert_equal task.connection_membership.user, task.user
    task = create_mentoring_model_task(connection_membership_id: nil)
    assert_nil task.user
    assert_nil task.connection_membership
  end

  def test_is_owned_by
    task = create_mentoring_model_task
    owner = task.user
    non_owner = users(:f_admin)
    assert_false (task.user.id == non_owner.id)
    assert task.is_owned_by?(owner)
    assert_false task.is_owned_by?(non_owner)
    task = create_mentoring_model_task(connection_membership_id: nil)
    assert_false task.is_owned_by?(owner)
  end

  def test_is_meeeting_action_item
    task = create_mentoring_model_task
    assert_false task.is_meeting_action_item?
    task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING})
    assert task.is_meeting_action_item?
  end

  def test_done
    task = create_mentoring_model_task
    assert_false task.done?
    task.update_attributes!({status: MentoringModel::Task::Status::DONE})
    assert task.done?
  end

  def test_todo
    task = create_mentoring_model_task
    assert task.todo?
    task.update_attributes!({status: MentoringModel::Task::Status::DONE})
    assert_false task.todo?
  end

  def test_get_complete_tasks
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE)
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago)
    t2 = create_mentoring_model_task(required: true, due_date: 1.week.from_now)
    assert_equal [t0], MentoringModel::Task.get_complete_tasks([t0, t1, t2])
  end

  def test_get_pending_tasks
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE)
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago)
    t2 = create_mentoring_model_task(required: true, due_date: 1.week.from_now, status: MentoringModel::Task::Status::TODO)
    assert_equal [t2], MentoringModel::Task.get_pending_tasks([t0, t1, t2])
  end

  def test_overdue
    assert MentoringModel::Task.overdue.blank?
    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE)
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago)
    assert_equal [t1], MentoringModel::Task.overdue
    t2 = create_mentoring_model_task(required: true, due_date: 1.week.from_now)
    assert_equal [t1], MentoringModel::Task.overdue
  end

  def test_get_overdue_tasks
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE)
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago)
    t2 = create_mentoring_model_task(required: true, due_date: 1.week.from_now)
    assert_equal [t1], MentoringModel::Task.get_overdue_tasks([t0, t1, t2])
  end

  def test_overdue_in_last
    assert_empty MentoringModel::Task.overdue_in_last(1.week)
    assert_empty MentoringModel::Task.overdue_in_last(2.days)

    task_1 = create_mentoring_model_task(required: true, due_date: 3.days.ago)
    task_2 = create_mentoring_model_task(required: true, due_date: 1.day.ago)
    create_mentoring_model_task(required: true, due_date: 1.day.ago, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 2.days.ago, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 8.days.from_now)

    assert_equal [task_1, task_2], MentoringModel::Task.overdue_in_last(1.week)
    assert_equal [task_2], MentoringModel::Task.overdue_in_last(2.days)
  end

  def test_overdue_before
    assert_empty MentoringModel::Task.overdue_before(1.week)
    assert_empty MentoringModel::Task.overdue_before(2.days)

    task_1 = create_mentoring_model_task(required: true, due_date: 3.days.ago)
    task_2 = create_mentoring_model_task(required: true, due_date: 15.days.ago)
    create_mentoring_model_task(required: true, due_date: 1.day.ago, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 2.days.ago, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 8.days.from_now)

    assert_equal [task_1, task_2], MentoringModel::Task.overdue_before(2.days)
    assert_equal [task_2], MentoringModel::Task.overdue_before(10.days)
  end

  def test_completed_within
    task = create_mentoring_model_task
    assert_false task.completed_within?
    task.update_attributes!({status: MentoringModel::Task::Status::DONE, completed_date: Date.today})
    assert task.completed_within?
    task.update_attributes!({completed_date: 2.week.ago})
    assert_false task.completed_within?
  end

  def test_pending_scope
    pending_tasks_size = MentoringModel::Task.pending.size
    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE)
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago)
    assert_equal pending_tasks_size, MentoringModel::Task.pending.size

    t2 = create_mentoring_model_task(required: true, due_date: 1.week.from_now)
    assert MentoringModel::Task.pending.include?(t2)
    assert_equal pending_tasks_size + 1, MentoringModel::Task.pending.size

    t3 = create_mentoring_model_task(required: false, status: MentoringModel::Task::Status::DONE)
    t4 = create_mentoring_model_task(required: false, status: MentoringModel::Task::Status::TODO)
    assert MentoringModel::Task.pending.include?(t4)
    assert_equal pending_tasks_size + 2, MentoringModel::Task.pending.size
  end

  def test_for_the_survey_id_scope
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:two)
    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id}

    t1 = create_mentoring_model_task(options)
    t2 = create_mentoring_model_task(options)

    tasks = MentoringModel::Task.for_the_survey_id(survey.id)

    assert_equal [t1, t2], tasks
  end

  def test_due_date_in
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:two)
    options = {:due_date => 2.weeks.ago, :created_at => "July 04, 2016", :action_item_id => survey.id, :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true}
    t1 = create_mentoring_model_task(options)
    t2 = create_mentoring_model_task(options)
    start_date = 3.weeks.ago
    end_date = 1.week.ago

    tasks = MentoringModel::Task.due_date_in(start_date, end_date)

    assert_equal [t1, t2], tasks
  end

  def test_of_groups_with_ids
    g1 = Group.first
    g2 = Group.last
    t1 = create_mentoring_model_task(group: g1, user: g1.members.first)
    t2 = create_mentoring_model_task(group: g1, user: g1.members.first)
    t3 = create_mentoring_model_task(group: g1, user: g1.members.first)
    t4 = create_mentoring_model_task(group: g2, user: g2.members.first)
    t5 = create_mentoring_model_task(group: g2, user: g2.members.first)

    assert_equal_unordered [t1, t2, t3].collect(&:id), MentoringModel::Task.of_groups_with_ids([g1.id]).pluck(:id)
    assert_equal_unordered [t1, t2, t3, t4, t5].collect(&:id), MentoringModel::Task.of_groups_with_ids([g1.id, g2.id]).pluck(:id)
  end

  def test_of_engagement_survey_type
    t = create_mentoring_model_task
    assert_equal [], groups(:mygroup).mentoring_model_tasks.of_engagement_survey_type

    t.update_attributes!(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id)
    assert_equal [t], groups(:mygroup).mentoring_model_tasks.of_engagement_survey_type
  end

  def test_owned_by_users_with_ids
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:two)
    options = {:due_date => "October 8, 2016", :created_at => "July 04, 2016", :action_item_id => survey.id, :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true}
    t1 = create_mentoring_model_task(options)
    t2 = create_mentoring_model_task(options)
    user_ids = users(:f_mentor).id

    tasks = MentoringModel::Task.owned_by_users_with_ids(user_ids)
     assert_equal [t1.id, t2.id], tasks
  end

  def test_upcoming
    assert MentoringModel::Task.upcoming(7).blank?
    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago.utc, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 1.week.ago.utc)
    create_mentoring_model_task(required: true, due_date: 1.day.ago.utc)
    t1 = create_mentoring_model_task(required: true, due_date: Time.now.utc.at_beginning_of_day)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc)
    t3 = create_mentoring_model_task(required: true, due_date: 6.days.from_now.utc)
    t4 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 15.days.from_now.utc)
    create_mentoring_model_task(required: true, due_date: 17.days.from_now.utc)
    assert_equal [t1, t2, t3], MentoringModel::Task.upcoming(MentoringModel::Task::SPAN_OF_DAYS_FOR_UPCOMING_TASKS)
    assert_equal [t1, t2, t3], MentoringModel::Task.upcoming
  end

  def test_upcoming
    t1 = create_mentoring_model_task(required: true, due_date: Time.now.utc.at_beginning_of_day)
    assert t1.upcoming?
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc, status: MentoringModel::Task::Status::DONE)
    assert_false t2.upcoming?
  end

  def test_get_upcoming_tasks
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    assert MentoringModel::Task.upcoming(MentoringModel::Task::SPAN_OF_DAYS_FOR_UPCOMING_TASKS).blank?
    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago.utc, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 1.week.ago.utc)
    create_mentoring_model_task(required: true, due_date: 1.day.ago.utc)
    t1 = create_mentoring_model_task(required: true, due_date: Time.now.utc.at_beginning_of_day)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc)
    t3 = create_mentoring_model_task(required: true, due_date: 16.days.from_now.utc)
    t4 = create_mentoring_model_task(required: false, status: MentoringModel::Task::Status::TODO)
    assert_equal [t1, t2], MentoringModel::Task.get_upcoming_tasks([t0, t1, t2, t3, t4])
  end

  def test_get_other_pending_tasks
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago.utc, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(required: true, due_date: 1.week.ago.utc)
    create_mentoring_model_task(required: true, due_date: 1.day.ago.utc)
    t1 = create_mentoring_model_task(required: true, due_date: Time.now.utc.at_beginning_of_day)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc)
    t3 = create_mentoring_model_task(required: true, due_date: 16.days.from_now.utc)
    t4 = create_mentoring_model_task(required: false, status: MentoringModel::Task::Status::TODO)

    assert_equal [t3, t4], MentoringModel::Task.get_other_pending_tasks([t0, t1, t2, t3, t4])
  end

  def test_completed
    assert MentoringModel::Task.completed(7).blank?
    t0 = create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE, completed_date: 1.day.ago)
    create_mentoring_model_task(required: true, due_date: 1.week.ago)
    create_mentoring_model_task(required: true, due_date: 1.day.ago)
    t1 = create_mentoring_model_task(required: true, due_date: Date.today.at_beginning_of_day, status: MentoringModel::Task::Status::DONE, completed_date: 1.day.ago)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now)
    t3 = create_mentoring_model_task(required: true, due_date: 6.days.from_now)
    t4 = create_mentoring_model_task(required: true, due_date: 3.days.from_now, status: MentoringModel::Task::Status::DONE, completed_date: 1.day.ago)
    create_mentoring_model_task(required: true, due_date: 7.days.from_now)
    create_mentoring_model_task(required: true, due_date: 9.days.from_now)
    assert_equal [t0, t1, t4], MentoringModel::Task.completed(7)
  end

  def test_completed_in_date_range_scope
    create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE, completed_date: 2.days.from_now)

    assert_equal 0, MentoringModel::Task.completed_in_date_range(Time.now.utc..1.day.from_now).count
    assert_equal 1, MentoringModel::Task.completed_in_date_range(Time.now.utc..3.days.from_now).count
  end

  def test_required_and_owned_by_user
    MentoringModel::Task.destroy_all
    assert_equal 0, MentoringModel::Task.completed_in_date_range(Time.now.utc..1.day.from_now).count
    create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE, completed_date: 2.days.from_now)
    task1 = MentoringModel::Task.completed_in_date_range(Time.now.utc..3.days.from_now).first
    assert_equal task1, MentoringModel::Task.required_and_owned_by_user(task1.connection_membership.user).first
  end

  def test_required
    assert MentoringModel::Task.required.blank?
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago)
    assert_equal [t1], MentoringModel::Task.overdue
    t2 = create_mentoring_model_task(required: false)
    assert_equal [t1], MentoringModel::Task.overdue
  end

  def test_owned_by
    user = users(:f_mentor)
    assert MentoringModel::Task.owned_by(user).blank?
    create_mentoring_model_task(user: users(:mkr_student))
    t1 = create_mentoring_model_task(user: user)
    assert_equal [t1], MentoringModel::Task.owned_by(user)
  end

  def test_optional
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago)
    assert_false t1.optional?
    t1.required = false; t1.save
    assert t1.optional?
  end

  def test_overdue_instance
    t1 = create_mentoring_model_task
    assert_false t1.required
    assert_nil t1.due_date
    assert_equal MentoringModel::Task::Status::TODO, t1.status

    # past optional incomplete
    t1.required, t1.due_date, t1.status = false, 1.week.ago, MentoringModel::Task::Status::TODO
    assert_false t1.overdue?

    # past optional complete
    t1.required, t1.due_date, t1.status = false, 1.week.ago, MentoringModel::Task::Status::DONE
    assert_false t1.overdue?

    # past required incomplete
    t1.required, t1.due_date, t1.status = true, 1.week.ago, MentoringModel::Task::Status::TODO
    assert t1.overdue?

    # past required complete
    t1.required, t1.due_date, t1.status = true, 1.week.ago, MentoringModel::Task::Status::DONE
    assert_false t1.overdue?

    # future optional incomplete
    t1.required, t1.due_date, t1.status = false, 1.week.from_now, MentoringModel::Task::Status::TODO
    assert_false t1.overdue?

    # future optional complete
    t1.required, t1.due_date, t1.status = false, 1.week.from_now, MentoringModel::Task::Status::DONE
    assert_false t1.overdue?

    # future required incomplete
    t1.required, t1.due_date, t1.status = true, 1.week.from_now, MentoringModel::Task::Status::TODO
    assert_false t1.overdue?

    # future required complete
    t1.required, t1.due_date, t1.status = true, 1.week.from_now, MentoringModel::Task::Status::DONE
    assert_false t1.overdue?
  end

  def test_due_date_coming_after
    t1 = create_mentoring_model_task
    assert_false t1.due_date_coming_after?(2)
    t1.update_attributes({required: true, due_date: 1.week.ago})
    assert_false t1.due_date_coming_after?(7)
    t1.update_attributes({due_date: 2.days.from_now})
    assert_false t1.due_date_coming_after?(7)
    t1.update_attributes({due_date: 9.days.from_now})
    assert t1.due_date_coming_after?(7)
  end

  def test_is_goal_action_item
    task = create_mentoring_model_task
    assert_false task.is_goal_action_item?
    task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::GOAL})
    assert task.is_goal_action_item?
  end

  def test_is_engagement_survey_action_item
    task = create_mentoring_model_task
    assert_false task.is_engagement_survey_action_item?
    task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY})
    assert task.is_engagement_survey_action_item?
  end

  def test_action_item
    task = create_mentoring_model_task
    task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id})
    assert_equal surveys(:two), task.action_item
  end

  def test_scoping_object
    group = groups(:mygroup)
    task = create_mentoring_model_task
    assert_equal group, MentoringModel::Task.scoping_object(task)
    assert_equal "group#{group.id}", MentoringModel::Task.scoping_object_id(task)

    milestone = create_mentoring_model_milestone
    task.milestone = milestone
    assert_equal milestone, MentoringModel::Task.scoping_object(task)
    assert_equal "milestone#{milestone.id}", MentoringModel::Task.scoping_object_id(task)
  end

  def test_pending
    task = create_mentoring_model_task
    assert task.pending?
    task = create_mentoring_model_task(status: MentoringModel::Task::Status::DONE)
    assert_false task.pending?
    task = create_mentoring_model_task(required: true, due_date: Date.today - 5.days)
    assert_false task.pending?
    assert task.overdue?
    task = create_mentoring_model_task(required: true, due_date: Date.today + 5.days)
    assert task.pending?
    assert_false task.overdue?
  end

  def test_unassigned
    group = groups(:mygroup)
    task = create_mentoring_model_task(connection_membership_id: nil)
    assert task.unassigned?
    task.update_attributes!(connection_membership_id: group.memberships.first.id)
    assert_false task.unassigned?
  end

  def test_from_template
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)
    assert_equal [task_2], group.mentoring_model_tasks.reload.from_template
  end

  def test_comment_association
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)

    assert_equal [], task_1.comments
    assert_equal [], task_2.comments

    comment1 = create_task_comment(task_1, {notify: 1})
    assert_equal [comment1], task_1.comments
    comment2 = create_task_comment(task_1, {notify: 1})
    assert_equal [comment1, comment2], task_1.comments

    assert_difference 'MentoringModel::Task::Comment.count', -2 do
      task_1.destroy
    end
  end

  def test_survey_answer_association
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attributes(:should_sync => true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    survey = program.surveys.find_by(name: "Partnership Effectiveness")
    tem_task1 = create_mentoring_model_task_template
    tem_task1.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, :role => program.roles.with_name([RoleConstants::MENTOR_NAME]).first })
    tem_task2 = create_mentoring_model_task_template
    tem_task2.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, :role => program.roles.with_name([RoleConstants::STUDENT_NAME]).first })

    response_id =  SurveyAnswer.maximum(:response_id).to_i + 1
    answers = {}
    group.memberships.each do |membership|
      task = group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, connection_membership_id: membership.id).first
      answers[task] = []
      task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
        ans = task.survey_answers.new(:user_id => membership.user_id, :response_id => response_id, :answer_text => "lorem ipsum", :last_answered_at => Time.now.utc)
        ans.survey_question = ques
        ans.save!
        answers[task] << ans
      end
      response_id += 1
    end
    answers.each do |task, survey_answer_for_task|
      assert_equal_unordered task.survey_answers, survey_answer_for_task
    end

    task = tem_task1.mentoring_model_tasks.first
    survey_answer = task.survey_answers.first
    assert_no_difference 'SurveyAnswer.count' do
      task.destroy
    end
    assert_nil survey_answer.reload.task_id
  end

  def test_translated_fields
    task = create_mentoring_model_task(from_template: true)
    Globalize.with_locale(:en) do
      task.title = "english title"
      task.description = "english description"
      task.save!
    end
    Globalize.with_locale(:"fr-CA") do
      task.title = "french title"
      task.description = "french description"
      task.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", task.title
      assert_equal "english description", task.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", task.title
      assert_equal "french description", task.description
    end
  end

  def test_translatable_fields_for_not_from_template_tasks
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    Globalize.with_locale(:en) do
      task_1.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"fr-CA") do
      task_1.update_attributes(title: "french title", description: "french description")
    end
    assert_equal 1, task_1.translations.count
    Globalize.with_locale(:en) do
      assert_equal "french title", task_1.title
      assert_equal "french description", task_1.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", task_1.title
      assert_equal "french description", task_1.description
    end

    task_2 = create_mentoring_model_task(from_template: true)
    Globalize.with_locale(:en) do
      task_2.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"fr-CA") do
      task_2.update_attributes(title: "french title", description: "french description")
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", task_2.title
      assert_equal "english description", task_2.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", task_2.title
      assert_equal "french description", task_2.description
    end
  end

  def test_task_checkins
    group = groups(:mygroup)
    task = create_mentoring_model_task(group: group)
    task_checkin1 = create_task_checkin(task, :duration => 60)
    task_checkin2 = create_task_checkin(task, :duration => 45)
    assert_equal task.checkins, [task_checkin1, task_checkin2]
    assert_equal task.group_checkins_duration, 105

    assert_difference 'GroupCheckin.count', -2 do
      assert_difference 'MentoringModel::Task.count', -1 do
        assert_nothing_raised do
          task.destroy
        end
      end
    end
  end

  def test_assigned_scope
    task = create_mentoring_model_task
    assert MentoringModel::Task.assigned.pluck(:id).include?(task.id)
    task.update_attribute(:connection_membership_id, nil)
    assert_false MentoringModel::Task.assigned.pluck(:id).include?(task.id)
  end

  def test_due_date_for_campaigns
    task = create_mentoring_model_task(:required => true)
    assert task.due_date_for_campaigns.present?
    assert_equal task.due_date, task.due_date_for_campaigns
  end

  def test_can_send_campaign_email
    task = create_mentoring_model_task
    task.stubs(:user).returns("someone")
    task.stubs(:todo?).returns(true)
    assert task.can_send_campaign_email?

    task.stubs(:user).returns(nil)
    assert_false task.can_send_campaign_email?

    task.stubs(:user).returns("someone")
    task.stubs(:todo?).returns(false)
    assert_false task.can_send_campaign_email?
  end

  private

  def setup_for_update_position_tests
    t0 = create_mentoring_model_task(required: true, due_date: Time.new(2000), position: 0)
    t1 = create_mentoring_model_task(required: false, due_date: nil, position: 1)
    t2 = create_mentoring_model_task(required: false, due_date: nil, position: 2)
    t3 = create_mentoring_model_task(required: true, due_date: Time.new(2005), position: 3)
    t4 = create_mentoring_model_task(required: true, due_date: Time.new(2010), position: 4)
    [t0, t1, t2, t3, t4]
  end
end