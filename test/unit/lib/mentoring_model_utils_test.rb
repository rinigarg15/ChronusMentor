require_relative './../../test_helper.rb'

class MentoringModelUtilsTest < ActiveSupport::TestCase
  include MentoringModelUtils

  def test_validate_milestone_order
    assert validate_milestone_order([])
    assert validate_milestone_order([1, 2, 3])
    assert validate_milestone_order([[1, 2, 3], [2, 4, 5], [3, 5, 6]])
    assert validate_milestone_order([[1, 2, 3], [2, 4, 5], [3, 5, 6]])
    assert_false validate_milestone_order([[1, -2, -3], [2, -4, -5], [3, -5, -6]])
    assert validate_milestone_order([[1, -5, -6], [2, -4, -5], [3, -2, -3]])
  end

  def test_get_new_task_template_due_date
    mentoring_model = programs(:albers).default_mentoring_model

    specific_date = "April 10, 2025"
    due_date = specific_date.to_datetime.change(offset: Time.current.in_time_zone(wob_member.get_valid_time_zone).strftime("%z")).to_i - 1e15

    assert_equal due_date, get_new_task_template_due_date(mentoring_model, {:specific_date => specific_date})

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})

    tt1 = create_mentoring_model_task_template({milestone_template_id: mt1.id})
    tt2 = create_mentoring_model_task_template({milestone_template_id: mt2.id})

    mentoring_model.reload

    tt1.due_date = 10
    tt2.due_date = 15

    MentoringModel::TaskTemplate.stubs(:compute_due_dates).returns([tt1, tt2])

    duration = 10

    assert_equal 20, get_new_task_template_due_date(mentoring_model, {:duration => duration, :associated_id => tt1.id})
    assert_equal 25, get_new_task_template_due_date(mentoring_model, {:duration => duration, :associated_id => tt2.id})
    assert_equal 10, get_new_task_template_due_date(mentoring_model, {:duration => duration, :associated_id => ""})
  end

  def test_get_first_and_last_required_task_in_milestones_list
    mentoring_model = programs(:albers).default_mentoring_model

    assert_equal [], get_first_and_last_required_task_in_milestones_list(mentoring_model)

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})

    tt1 = create_mentoring_model_task_template({milestone_template_id: mt1.id, required: true})
    tt2 = create_mentoring_model_task_template({milestone_template_id: mt2.id, required: true})
    tt3 = create_mentoring_model_task_template({milestone_template_id: mt2.id, required: false})

    ft1 = create_mentoring_model_facilitation_template({milestone_template_id: mt2.id})

    mentoring_model.reload

    ft1.due_date = 5
    tt1.due_date = 10
    tt2.due_date = 15
    tt3.due_date = 20

    self.stubs(:get_task_and_facilitation_templates_merged_list).with(mt1).returns([ft1, tt1, tt2, tt3])
    self.stubs(:get_task_and_facilitation_templates_merged_list).with(mt2).returns([ft1, tt2, tt1, tt3])
    self.stubs(:get_task_and_facilitation_templates_merged_list).with(mt3).returns([ft1, tt3])

    assert_equal [[mt1.position, 10, 15], [mt2.position, 15, 10]], get_first_and_last_required_task_in_milestones_list(mentoring_model)
  end


  def test_get_updated_first_and_last_required_task_in_milestones_list
    existing_list = [[1, 5, 10], [3, 15, 18], [4, 30, 35]]

    assert_equal [[1, 5, 5]], get_updated_first_and_last_required_task_in_milestones_list([], 1, 5)

    assert_equal [[1, 3, 10], [3, 15, 18], [4, 30, 35]], get_updated_first_and_last_required_task_in_milestones_list([[1, 5, 10], [3, 15, 18], [4, 30, 35]], 1, 3)

    assert_equal [[1, 5, 10], [3, 15, 18], [4, 30, 35]], get_updated_first_and_last_required_task_in_milestones_list([[1, 5, 10], [3, 15, 18], [4, 30, 35]], 1, 7)

    assert_equal [[1, 5, 13], [3, 15, 18], [4, 30, 35]], get_updated_first_and_last_required_task_in_milestones_list([[1, 5, 10], [3, 15, 18], [4, 30, 35]], 1, 13)

    assert_equal [[1, 5, 10], [2, 12, 12], [3, 15, 18], [4, 30, 35]], get_updated_first_and_last_required_task_in_milestones_list([[1, 5, 10], [3, 15, 18], [4, 30, 35]], 2, 12)
  end

  def test_get_updated_first_and_last_required_task_in_milestones_list_after_milestone_reordering
    @mentoring_model = programs(:albers).default_mentoring_model

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})

    @mentoring_model.reload

    existing_list = [[0, 5, 10], [1, 15, 18], [2, 30, 35]]

    new_position_by_milestone_id_hash = {mt1.id => 1, mt3.id => 0, mt2.id => 2}

    assert_equal [[0, 30, 35], [1, 5, 10], [2, 15, 18]], get_updated_first_and_last_required_task_in_milestones_list_after_milestone_reordering(existing_list, new_position_by_milestone_id_hash)
  end


  private

  def wob_member
    members(:f_admin)
  end

end