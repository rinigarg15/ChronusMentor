require_relative './../../test_helper.rb'

class MentoringModel::TaskTemplateObserverTest < ActiveSupport::TestCase
  def setup
    super
    @mentoring_model = programs(:albers).default_mentoring_model
  end  

  def test_on_destroy_associate_previous_task
    t1 = create_mentoring_model_task_template(required: true, duration: 1)
    t2 = create_mentoring_model_task_template(required: true, duration: 1, associated_id: t1.id)
    t3 = create_mentoring_model_task_template(required: true, duration: 1, associated_id: t2.id)
    assert_equal t2.id, t3.associated_id
    t2.destroy
    assert_equal t1.id, t3.reload.associated_id
  end

  def test_check_duration_on_create
    task_template = MentoringModel::TaskTemplate.create({mentoring_model_id: @mentoring_model.id,
      role_id: programs(:albers).roles.last.id, title: "task template title", duration: 1, required: false })
    assert_equal 0, task_template.reload.duration
  end

  def test_check_duration_on_edit
    task_template = create_mentoring_model_task_template(duration: 1, required: true)
    assert_equal 1, task_template.duration
    assert task_template.required
    task_template.required = false
    task_template.save
    assert_equal 0, task_template.reload.duration
    assert_false task_template.required
  end

  def test_position_set_to_end_for_optional_task_template_on_create
    t1 = create_mentoring_model_task_template
    t2 = create_mentoring_model_task_template
    t3 = create_mentoring_model_task_template(duration: 1, required: true)
    t4 = create_mentoring_model_task_template(associated_id: t3.id, required: false)
    assert_equal [t1, t2, t3, t4].map(&:id), @mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [0, 1, 2, 3], @mentoring_model.reload.mentoring_model_task_templates.map(&:position)
    t5 = create_mentoring_model_task_template
    assert_equal 4, t5.reload.position
    assert_equal t3.id, t5.associated_id
  end

  def test_update_position_after_save
    t1 = create_mentoring_model_task_template
    t1.mentoring_model.reload.mentoring_model_task_templates
    t2 = create_mentoring_model_task_template
    t2.mentoring_model.reload.mentoring_model_task_templates
    t3 = create_mentoring_model_task_template(duration: 1, required: true)
    t3.mentoring_model.reload.mentoring_model_task_templates
    t4 = create_mentoring_model_task_template(associated_id: t3.id, required: false)
    t4.mentoring_model.reload.mentoring_model_task_templates
    assert_equal [t1, t2, t3, t4].map(&:id), @mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [0, 1, 2, 3], @mentoring_model.reload.mentoring_model_task_templates.map(&:position)
    t2.required = true
    t2.duration = 3
    t2.save
    assert_equal [t1, t3, t4, t2].map(&:id), @mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [0, 1, 2, 3], @mentoring_model.reload.mentoring_model_task_templates.map(&:position)
  end

  def test_update_position_after_save_with_milestone_templates_and_specific_date
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template

    t1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 6, required: true)
    t2 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 1, required: true)
    t3 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 3, required: true)
    t4 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, duration: 9, required: true)
    t5 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, duration: 3, required: true)
    
    assert_equal [t2, t3, t1].map(&:id), milestone_template1.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [0, 1, 2], milestone_template1.mentoring_model_task_templates.map(&:position)

    assert_equal [t5, t4].map(&:id), milestone_template2.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [0, 1], milestone_template2.mentoring_model_task_templates.map(&:position)

    t6 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 0, required: true, specific_date: "2014-12-28")
    t7 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, specific_date: "2014-12-19")
    t8 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, duration: 0, required: true, specific_date: "2014-01-01")
    t9 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, specific_date: "2014-04-12")

    assert_equal [t7, t6, t2, t3, t1].map(&:id), milestone_template1.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [0, 1, 2, 3, 4], milestone_template1.mentoring_model_task_templates.map(&:position)

    assert_equal [t8, t9, t5, t4].map(&:id), milestone_template2.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [0, 1, 2, 3], milestone_template2.mentoring_model_task_templates.map(&:position)
  end

  def test_milestone_link_children_to_parent
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template

    t1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 6, required: true)
    t2 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 1, required: true, associated_id: t1.id)
    t3 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 3, required: true, associated_id: t2.id)

    assert_equal [t1, t2, t3].map(&:id), milestone_template1.mentoring_model_task_templates.map(&:id)
    t1.destroy
    assert_equal 7, t2.reload.duration
    assert_nil t2.associated_id

    assert_equal [t2, t3].map(&:id), milestone_template1.reload.mentoring_model_task_templates.map(&:id)
    t2.destroy
    assert_equal 10, t3.reload.duration
    assert_nil t3.associated_id
    assert_equal [t3].map(&:id), milestone_template1.reload.mentoring_model_task_templates.map(&:id)

    t1 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, duration: 6, required: true)
    t2 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, duration: 1, required: true, associated_id: t1.id)
    t3 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, duration: 3, required: true, associated_id: t2.id)

    t2.destroy
    assert_equal 4, t3.reload.duration
    assert_equal t1.id, t3.associated_id
    assert_equal [t1, t3].map(&:id), milestone_template2.reload.mentoring_model_task_templates.map(&:id)

    t1.update_attributes!(required: false)
    assert_equal 10, t3.reload.duration
    assert_nil t3.associated_id
    assert_equal [t1, t3].map(&:id), milestone_template2.reload.mentoring_model_task_templates.map(&:id)
    assert_equal [t3].map(&:id), milestone_template2.mentoring_model_task_templates.required.map(&:id)
  end

  def test_link_children_to_parent_on_updating_specific_date
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template

    t1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 6, required: true)
    t2 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 1, required: true, associated_id: t1.id)
    t3 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 3, required: true, associated_id: t2.id)
    t4 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 6, required: true, associated_id: t3.id)
    t5 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 1, required: true, associated_id: t4.id)
    t6 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, duration: 3, required: true, associated_id: t5.id)

    assert_equal [nil, t1.id, t2.id, t3.id, t4.id, t5.id], milestone_template1.mentoring_model_task_templates.collect(&:associated_id)
    t1.update_attributes!(specific_date: "2012-12-04", duration: 0)
    milestone_template1.reload
    assert_equal [nil, nil, t2.id, t3.id, t4.id, t5.id], milestone_template1.mentoring_model_task_templates.collect(&:associated_id)
  end

  def test_increament_template_version_after_crud
    program = programs(:albers)
    @mentoring_model = program.default_mentoring_model
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      @task_template = create_mentoring_model_task_template
    end
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      @task_template.title = "New title"
      @task_template.save!
    end
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      @task_template.destroy
    end
  end

  def test_skip_increment
    program = programs(:albers)
    @mentoring_model = program.default_mentoring_model
    MentoringModel.expects(:trigger_sync).times(0)
    assert_difference "@mentoring_model.reload.version", 0 do
      @task_template = create_mentoring_model_task_template(skip_increment_version_and_sync_trigger: true)
    end
    assert_difference "@mentoring_model.reload.version", 0 do
      @task_template.title = "New title"
      @task_template.save!
    end
    assert_difference "@mentoring_model.reload.version", 0 do
      @task_template.destroy
    end
  end
end
