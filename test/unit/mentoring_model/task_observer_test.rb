require_relative './../../test_helper.rb'

class MentoringModel::TaskObserverTest < ActiveSupport::TestCase
  def test_new_added_task_should_come_last_in_the_list
    group = groups(:mygroup)
    t0 = create_mentoring_model_task(required: true, due_date: Time.new(2000), position: 0)
    t1 = create_mentoring_model_task(required: false, due_date: nil, position: 1)
    t2 = create_mentoring_model_task(required: false, due_date: nil, position: 2)
    t3 = create_mentoring_model_task(required: true, due_date: Time.new(2005), position: 3)
    t4 = create_mentoring_model_task(required: true, due_date: Time.new(2010), position: 4)
    assert_equal [t0, t1, t2, t3, t4].map(&:id), group.mentoring_model_tasks.map(&:id)
    assert_equal [0, 1, 2, 3, 4], [t0, t1, t2, t3, t4].map(&:position)
    task = create_mentoring_model_task(required: false)
    assert_equal 5, task.position
    assert_equal task.id, group.reload.mentoring_model_tasks.last.id
  end

  def test_update_positions_on_milestone_update
    current_date = Date.current
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task11 = create_mentoring_model_task(milestone: milestone1, required: true, due_date: current_date + 4.days)
    task12 = create_mentoring_model_task(milestone: milestone1.reload, required: true, due_date: current_date + 2.days)
    task21 = create_mentoring_model_task(milestone: milestone2, required: true, due_date: current_date + 3.days)
    assert_equal 1, task11.reload.position
    assert_equal 0, task12.reload.position
    assert_equal 0, task21.reload.position

    task21.skip_update_positions = nil
    task21.milestone = milestone1.reload
    task21.save!
    assert_equal 2, task11.reload.position
    assert_equal 0, task12.reload.position
    assert_equal 1, task21.reload.position
  end

  def test_es_reindexing
    milestone1 = create_mentoring_model_milestone
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(3).with(Group, [groups(:mygroup).id])
    task = create_mentoring_model_task(milestone: milestone1, required: true, due_date: Date.current + 4.days)
    task.update_attributes!(required: false, perform_delta: true)
    task.destroy
  end

end