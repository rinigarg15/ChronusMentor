require_relative './../../test_helper.rb'

class MentoringModel::TaskTemplateTest < ActiveSupport::TestCase
  def setup
    super
    @default_mentoring_model = programs(:albers).default_mentoring_model
  end

  def test_validations
    tt = MentoringModel::TaskTemplate.new
    assert_false tt.save
    tt.mentoring_model = @default_mentoring_model
    assert_false tt.save
    tt.title = "title"
    assert_false tt.save
    tt.duration = 1
    assert tt.save
  end

  def test_reqd_task_duration_validation
    tt = MentoringModel::TaskTemplate.new(mentoring_model_id: @default_mentoring_model.id, title: "title", role_id: programs(:albers).roles.last.id)
    tt.required = true
    tt.duration = 0
    assert_false tt.save
    tt.duration = 1
    assert tt.save
    tt.required = false
    tt.duration = 0
    assert tt.save
  end

  def test_reqd_task_specific_date_validation
    tt = MentoringModel::TaskTemplate.new(mentoring_model_id: @default_mentoring_model.id, title: "title", role_id: programs(:albers).roles.last.id)
    tt.required = true
    tt.duration = 0
    assert_false tt.save
    tt.specific_date = "19/01/2014"
    assert tt.save
    tt.required = false
    tt.duration = 0
    assert_false tt.save
    tt.specific_date = nil
    assert tt.save
  end

  def test_sort_task_on_specific_date
    @default_mentoring_model.allow_manage_mm_milestones!(programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME))
    milestone_template1 = create_mentoring_model_milestone_template
    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 0,specific_date:"19/01/2014")
    tto1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id,required: false, associated_id: tt1.id)

    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 0,specific_date:"21/01/2014")
    tto3 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id,required: false, associated_id: tt3.id)

    tt = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true,duration: 5)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 0,specific_date:"20/01/2014")
    [tt1, tt2, tt3, tto1, tto3, tt].collect(&:reload)
    assert tt1.position < tt2.position
    assert tt2.position < tt3.position
    assert_equal [0, 1, 2, 3, 4, 5], [tt1, tto1, tt2, tt3, tto3, tt].collect(&:position)

  end

  def test_action_item_id_presence
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :action_item_id do
        create_mentoring_model_task_template({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY})
    end
  end

  def test_update_position_special_case_scenario_1
    # Consider the following scenario:
    # 1. Task 'A' => 2 days after SOC
    # 2. Task 'B' => 3 days afetr SOC
    # 3. Task 'C' => 2 days after Task 'A' due
    # When Task 'A' is changed from required to not required task, task 'C' should change to
    # 4 days after SOC, and order should be preserved
    t1 = create_mentoring_model_task_template(duration: 2, required: true)
    t2 = create_mentoring_model_task_template(duration: 3, required: true)
    t3 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t1.id)
    MentoringModel::TaskTemplate.compute_due_dates([t1, t2, t3])
    assert_equal [t1.id, t2.id, t3.id], @default_mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    t1.required = false
    t1.save!
    assert_equal [t1.id, t2.id, t3.id], @default_mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    assert_equal 4, t3.reload.duration
    assert_nil t3.associated_id
  end

  def test_update_position_special_case_scenario_2
    # In a chain of tasks, for ex:
    # 1. Task 'A' (1 day) => Task 'B' (1 day) => Task 'C' (1 day)
    # If Task 'B' is deleted then task 'C' should follow task 'A' and due of 'C' remains fixed, ie, 2 days
    t1 = create_mentoring_model_task_template(duration: 1, required: true)
    t2 = create_mentoring_model_task_template(duration: 1, required: true, associated_id: t1.id)
    t3 = create_mentoring_model_task_template(duration: 1, required: true, associated_id: t2.id)
    MentoringModel::TaskTemplate.compute_due_dates([t1, t2, t3])
    assert_equal [t1.id, t2.id, t3.id], @default_mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    t2.destroy
    assert_equal [t1.id, t3.id], @default_mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    assert_equal 2, t3.reload.duration
    assert_equal t1.id, t3.associated_id
  end

  def test_subtasks_and_filter_subtasks
    # Consider the following scenario:
    # 1. Task 'A' => 2 days after SOC
    # 2. Task 'B' => 3 days after SOC
    # 3. Task 'C' => 2 days after Task 'A' due
    # 3. Task 'D' => 2 days after Task 'C' due
    t1 = create_mentoring_model_task_template(duration: 2, required: true)
    t2 = create_mentoring_model_task_template(duration: 3, required: true)
    t3 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t1.id)
    t4 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t3.id)
    all_task_templates = [t1, t2, t3, t4]

    # subtasks testing
    assert_equal_unordered [t3, t4], MentoringModel::TaskTemplate.sub_tasks(t1, all_task_templates)
    assert_equal_unordered [], MentoringModel::TaskTemplate.sub_tasks(t2, all_task_templates)
    assert_equal_unordered [t4], MentoringModel::TaskTemplate.sub_tasks(t3, all_task_templates)
    assert_equal_unordered [], MentoringModel::TaskTemplate.sub_tasks(t4, all_task_templates)
    assert_equal_unordered [], MentoringModel::TaskTemplate.sub_tasks(MentoringModel::TaskTemplate.new, all_task_templates)

    # filter subtasks tests
    assert_equal_unordered [t1, t2], MentoringModel::TaskTemplate.filter_sub_tasks(t1, all_task_templates)
    assert_equal_unordered [t1, t2, t3, t4], MentoringModel::TaskTemplate.filter_sub_tasks(t2, all_task_templates)
    assert_equal_unordered [t1, t2, t3], MentoringModel::TaskTemplate.filter_sub_tasks(t3, all_task_templates)
    assert_equal_unordered [t1, t2, t3, t4], MentoringModel::TaskTemplate.filter_sub_tasks(t4, all_task_templates)
    assert_equal_unordered [t1, t2, t3, t4], MentoringModel::TaskTemplate.filter_sub_tasks(MentoringModel::TaskTemplate.new, all_task_templates)
  end

  def test_update_task_template_should_not_change_status_of_its_tasks
    group = groups(:mygroup)
    group.update_members([users(:f_mentor), users(:robert)], [users(:mkr_student)])
    group.mentoring_model = programs(:albers).mentoring_models.default.first
    group.save!
    milestone_template1 = create_mentoring_model_milestone_template
    @default_mentoring_model.allow_manage_mm_milestones!(programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME))
    tt = create_mentoring_model_task_template(duration: 2, required: true, milestone_template_id: milestone_template1.id)
    tasks = tt.mentoring_model_tasks.where(group_id: group.id)
    assert_equal 2, tasks.size
    t1, t2 = tasks
    t1.status = MentoringModel::Task::Status::DONE
    t1.save!
    t2.connection_membership_id = nil
    t2.status = MentoringModel::Task::Status::DONE
    t2.save!
    tt.duration = 4
    tt.save!
    assert_equal [MentoringModel::Task::Status::DONE, MentoringModel::Task::Status::DONE], tt.mentoring_model_tasks.where(group_id: group.id).pluck(:status)
  end

  def test_update_role_of_unassigned_task_should_reflect_in_connection
    group = groups(:mygroup)
    group.update_members([users(:f_mentor), users(:robert)], [users(:mkr_student)])
    group.mentoring_model = programs(:albers).mentoring_models.default.first
    group.save!
    milestone_template1 = create_mentoring_model_milestone_template
    @default_mentoring_model.allow_manage_mm_milestones!(programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME))
    tt = create_mentoring_model_task_template(duration: 2, required: true, milestone_template_id: milestone_template1.id, role_id: nil)
    assert_equal 1, tt.mentoring_model_tasks.where(group_id: group.id).count
    tt.role_id = programs(:albers).find_role(RoleConstants::MENTOR_NAME).id
    tt.save!
    assert_equal 2, tt.mentoring_model_tasks.where(group_id: group.id).count
  end

  def test_update_due_positions_with_milestones
    @default_mentoring_model.allow_manage_mm_milestones!(programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME))

    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template

    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 5)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, duration: 7, associated_id: tt1.id)
    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, duration: 6)
    task_templates = MentoringModel::TaskTemplate.compute_due_dates([tt1, tt2, tt3], skip_positions: true)
    MentoringModel::TaskTemplate.update_due_positions([tt1])
    MentoringModel::TaskTemplate.update_due_positions([tt2, tt3])

    assert_equal [0, 1, 0], [tt1, tt2, tt3].collect(&:reload).collect(&:position)

    tt4 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, duration: 20)
    task_templates = MentoringModel::TaskTemplate.compute_due_dates([tt1, tt2, tt3, tt4], skip_positions: true)
    MentoringModel::TaskTemplate.update_due_positions([tt1])
    MentoringModel::TaskTemplate.update_due_positions([tt2, tt3, tt4])

    assert_equal [0, 1, 0, 2], [tt1, tt2, tt3, tt4].collect(&:reload).collect(&:position)
  end

  def test_associated_task
    t1 = create_mentoring_model_task_template(title: "title 1", required: true)
    t2 = create_mentoring_model_task_template(title: "title 2", associated_id: t1.id)
    assert_equal "title 1", t2.associated_task.title
    assert_equal t1, t2.associated_task
    t2.update_attributes!(associated_id: nil)
    assert_nil t2.reload.associated_task
  end

  def test_required_scope
    t1 = create_mentoring_model_task_template(required: false)
    t2 = create_mentoring_model_task_template(required:  true)
    assert_equal_unordered [t1, t2], @default_mentoring_model.mentoring_model_task_templates
    assert_equal_unordered [t2], @default_mentoring_model.mentoring_model_task_templates.required
  end

  def test_of_engagement_survey_type
    t = create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id)
    assert_equal_unordered [t], @default_mentoring_model.mentoring_model_task_templates.of_engagement_survey_type
  end

  def test_is_meeting_action_item
    t1 = create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING)
    assert t1.is_meeting_action_item?
    t1.update_attribute(:action_item_type, MentoringModel::TaskTemplate::ActionItem::DEFAULT)
    assert_false t1.is_meeting_action_item?
  end

  def test_optional
    t1 = create_mentoring_model_task_template(required: true)
    assert_false t1.optional?
    t1.required = false; t1.save
    assert t1.optional?
  end

  def test_scoping_object
    milestone_template = create_mentoring_model_milestone_template
    
    task_template = create_mentoring_model_task_template
    assert_equal @default_mentoring_model, MentoringModel::TaskTemplate.scoping_object(task_template)

    @default_mentoring_model.allow_manage_mm_milestones!(programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME))
    task_template.mentoring_model.reload
    task_template.update_attributes!(milestone_template_id: milestone_template.id)
    assert_equal milestone_template, MentoringModel::TaskTemplate.scoping_object(task_template)
  end

  def test_action_item_list
    t = create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id)
    assert_equal_unordered EngagementSurvey.where(program_id: programs(:albers)), t.get_action_item_list
  end

  def test_is_engagement_survey_action_item
    task_template = create_mentoring_model_task_template
    assert_false task_template.is_engagement_survey_action_item?
    task_template.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id} )
    assert task_template.is_engagement_survey_action_item?
  end

  def test_action_item
    task_template = create_mentoring_model_task_template
    task_template.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id})
    assert_equal surveys(:two), task_template.action_item
  end

  def test_validations_survey_are_linked_if_engagement
    task_template = create_mentoring_model_task_template
    assert_raise(ActiveRecord::RecordInvalid) do
        task_template.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: 26} )
    end
    task_template.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id} )
    assert task_template.is_engagement_survey_action_item?
  end

  def test_skip_survey_validations_attr_accessor
    task_template = create_mentoring_model_task_template
    task_template.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    task_template.action_item_id = 26
    assert_false task_template.valid?
    task_template.skip_survey_validations = true
    assert task_template.valid?
  end

  def test_translated_fields
    tt = create_mentoring_model_task_template
    Globalize.with_locale(:en) do
      tt.title = "english title"
      tt.description = "english description"
      tt.save!
    end
    Globalize.with_locale(:"fr-CA") do
      tt.title = "french title"
      tt.description = "french description"
      tt.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", tt.title
      assert_equal "english description", tt.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", tt.title
      assert_equal "french description", tt.description
    end
  end

  def test_versioning
    task_template = create_mentoring_model_task_template
    assert_difference "task_template.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        task_template.update_attributes(title: "new title")
      end
    end

    assert_difference "task_template.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        task_template.update_attributes(description: "new description")
      end
    end
  end

  def test_version_number
    task_template = create_mentoring_model_task_template
    assert_equal 1, task_template.version_number
    create_chronus_version(item: task_template, object_changes: "", event: ChronusVersion::Events::UPDATE)
    assert_equal 2, task_template.reload.version_number
  end
end
