require_relative './../../test_helper.rb'

class MentoringModel::MilestoneTest < ActiveSupport::TestCase
  def setup
    super
    @group = groups(:mygroup)
  end

  def test_mentoring_model_tasks
    milestone = create_mentoring_model_milestone(group_id: @group.id)
    create_mentoring_model_task(milestone_id: milestone.id, title: "Carrie")
    create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes")

    assert_equal 2, milestone.reload.mentoring_model_tasks.size
    assert_equal ["Carrie", "Claire Danes"], milestone.mentoring_model_tasks.map(&:title)

    assert_difference "MentoringModel::Task.count", -2 do
      milestone.destroy
    end
  end

  def test_translated_fields
    milestone = create_mentoring_model_milestone(group_id: @group.id, from_template: true)
    Globalize.with_locale(:en) do
      milestone.title = "english title"
      milestone.description = "english description"
      milestone.save!
    end
    Globalize.with_locale(:"fr-CA") do
      milestone.title = "french title"
      milestone.description = "french description"
      milestone.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", milestone.title
      assert_equal "english description", milestone.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", milestone.title
      assert_equal "french description", milestone.description
    end
  end

  def test_validations
    milestone = MentoringModel::Milestone.new
    assert_false milestone.valid?
    assert_equal ["can't be blank"], milestone.errors[:title]
    assert_equal ["can't be blank"], milestone.errors[:group]
    assert_empty milestone.errors[:template_version]

    milestone.title = "Carrie Mathison"
    milestone.description = "Analyst"
    milestone.group_id = @group.id
    assert milestone.valid?

    milestone.from_template = true
    assert_false milestone.valid?
    assert_equal ["is not a number"], milestone.errors[:template_version]

    milestone.template_version = -1
    assert_false milestone.valid?
    assert_equal ["must be greater than 0"], milestone.errors[:template_version]

    milestone.template_version = 1
    assert milestone.valid?
  end

  def test_positioned_before_scope
    assert_empty @group.mentoring_model_milestones

    milestone_1 = create_mentoring_model_milestone(group_id: @group.id)
    milestone_2 = create_mentoring_model_milestone(group_id: @group.id)
    milestone_3 = create_mentoring_model_milestone(group_id: @group.id)
    milestone_1.update_attribute(:position, nil)
    milestone_2.update_attribute(:position, 1)
    milestone_3.update_attribute(:position, 2)

    assert_equal [milestone_1], @group.mentoring_model_milestones.positioned_before(0)
    assert_equal [milestone_1, milestone_2], @group.mentoring_model_milestones.positioned_before(2)
    assert_equal [milestone_1, milestone_2, milestone_3], @group.mentoring_model_milestones.positioned_before(10)
  end

  def test_overdue
    milestone = create_mentoring_model_milestone(group_id: @group.id)
    milestone1 = create_mentoring_model_milestone(group_id: @group.id)
    t1 = create_mentoring_model_task(milestone_id: milestone.id, title: "Carrie")
    t2 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes")

    assert_false MentoringModel::Milestone.overdue.pluck(:id).include?(milestone.id)

    t3 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", required: true, status: MentoringModel::Task::Status::DONE, due_date: Date.today - 10.days)

    assert_false MentoringModel::Milestone.overdue.pluck(:id).include?(milestone.id)

    t4 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", required: true, due_date: Date.today + 10.days)

    assert_false MentoringModel::Milestone.overdue.pluck(:id).include?(milestone.id)

    t5 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", required: true, due_date: Date.today - 10.days)
    t6 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", required: true, due_date: Date.today - 10.days)

    assert MentoringModel::Milestone.overdue.pluck(:id).include?(milestone.id)
    assert_equal [milestone.id], MentoringModel::Milestone.overdue.pluck(:id)

    create_mentoring_model_task(milestone_id: milestone1.id, title: "Claire Danes", required: true, due_date: Date.today - 10.days)

    assert MentoringModel::Milestone.overdue.pluck(:id).include?(milestone.id)
    assert MentoringModel::Milestone.overdue.pluck(:id).include?(milestone1.id)
    assert_equal [milestone.id, milestone1.id], MentoringModel::Milestone.overdue.pluck(:id)
  end


  def test_current
    milestone1 = create_mentoring_model_milestone(group_id: @group.id)
    create_mentoring_model_task(milestone_id: milestone1.id, title: "Carrie")
    create_mentoring_model_task(milestone_id: milestone1.id, title: "Claire Danes")

    assert_false MentoringModel::Milestone.current.pluck(:id).include?(milestone1.id)
    assert_equal [], MentoringModel::Milestone.current.pluck(:id)

    create_mentoring_model_task(milestone_id: milestone1.id, title: "Claire Danes", required: true, due_date: Date.today - 20.days, status: MentoringModel::Task::Status::DONE)

    assert_false MentoringModel::Milestone.current.pluck(:id).include?(milestone1.id)
    assert_equal [], MentoringModel::Milestone.current.pluck(:id)

    milestone2 = create_mentoring_model_milestone(group_id: @group.id)
    create_mentoring_model_task(milestone_id: milestone2.id, title: "Carrie", required: true, due_date: Date.today + 10.days)
    create_mentoring_model_task(milestone_id: milestone2.id, title: "Claire Danes")

    assert MentoringModel::Milestone.current.pluck(:id).include?(milestone2.id)
    assert_equal [milestone2.id], MentoringModel::Milestone.current.pluck(:id)

    create_mentoring_model_task(milestone_id: milestone2.id, title: "Carrie", required: true, due_date: Date.today + 10.days)

    assert MentoringModel::Milestone.current.pluck(:id).include?(milestone2.id)
    assert_equal [milestone2.id], MentoringModel::Milestone.current.pluck(:id)

    milestone3 = create_mentoring_model_milestone(group_id: @group.id)
    create_mentoring_model_task(milestone_id: milestone3.id, title: "Carrie")
    create_mentoring_model_task(milestone_id: milestone3.id, title: "Claire Danes")

    assert MentoringModel::Milestone.current.pluck(:id).include?(milestone2.id)
    assert_equal [milestone2.id], MentoringModel::Milestone.current.pluck(:id)

    task = create_mentoring_model_task(milestone_id: milestone3.id, title: "Carrie", required: true, due_date: Date.today + 10.days)

    assert MentoringModel::Milestone.current.pluck(:id).include?(milestone3.id)
    assert_equal [milestone2.id, milestone3.id], MentoringModel::Milestone.current.pluck(:id)

    task.status = MentoringModel::Task::Status::DONE
    task.save!

    assert_false MentoringModel::Milestone.current.pluck(:id).include?(milestone3.id)
    assert_equal [milestone2.id], MentoringModel::Milestone.current.pluck(:id)
  end

  def test_pending
    milestone = create_mentoring_model_milestone
    assert_equal [], MentoringModel::Milestone.pending

    create_mentoring_model_task(milestone_id: milestone.id, required: true, due_date: Date.today - 20.days)
    assert_equal [], MentoringModel::Milestone.pending
    assert_equal [milestone], MentoringModel::Milestone.overdue

    create_mentoring_model_task(milestone_id: milestone.id, required: true, due_date: Date.today + 20.days)
    assert_equal [], MentoringModel::Milestone.pending
    assert_equal [milestone], MentoringModel::Milestone.overdue

    milestone1 = create_mentoring_model_milestone
    task = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 20.days)
    assert_equal [milestone1], MentoringModel::Milestone.pending

    task.update_attributes!(status: MentoringModel::Task::Status::DONE)
    assert_equal [], MentoringModel::Milestone.pending

    milestone2 = create_mentoring_model_milestone
    create_mentoring_model_task(milestone_id: milestone2.id)
    create_mentoring_model_task(milestone_id: milestone2.id)
    assert_equal [], MentoringModel::Milestone.pending
  end

  def test_completed
    milestone1 = create_mentoring_model_milestone
    assert_equal [milestone1], MentoringModel::Milestone.completed

    create_mentoring_model_task(milestone_id: milestone1.id)
    create_mentoring_model_task(milestone_id: milestone1.id)
    assert_equal [milestone1], MentoringModel::Milestone.completed

    task = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 20.days)
    assert_equal [], MentoringModel::Milestone.completed
    assert_equal [milestone1], MentoringModel::Milestone.pending

    task.update_attributes!(status: MentoringModel::Task::Status::DONE)
    assert_equal [milestone1], MentoringModel::Milestone.completed

    task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 20.days, status: MentoringModel::Task::Status::DONE)
    task2 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today - 20.days)

    assert_equal [], MentoringModel::Milestone.completed
    assert_equal [], MentoringModel::Milestone.pending
    assert_equal [milestone1], MentoringModel::Milestone.overdue

    task2.update_attributes!(status: MentoringModel::Task::Status::DONE)

    assert_equal [milestone1], MentoringModel::Milestone.completed
    assert_equal [], MentoringModel::Milestone.pending
    assert_equal [], MentoringModel::Milestone.overdue
  end

  def test_with_incomplete_optional_tasks
    milestone1 = create_mentoring_model_milestone
    assert_equal [], MentoringModel::Milestone.with_incomplete_optional_tasks

    task1 = create_mentoring_model_task(milestone_id: milestone1.id, status: MentoringModel::Task::Status::DONE)
    task2 = create_mentoring_model_task(milestone_id: milestone1.id, status: MentoringModel::Task::Status::TODO, required: true)
    assert_equal [], MentoringModel::Milestone.with_incomplete_optional_tasks

    task2.update_attribute(:status, MentoringModel::Task::Status::DONE)
    assert_equal [], MentoringModel::Milestone.with_incomplete_optional_tasks

    task1.update_attribute(:status, MentoringModel::Task::Status::TODO)
    assert_equal [milestone1], MentoringModel::Milestone.with_incomplete_optional_tasks
  end

  def test_from_template
    group = groups(:mygroup)
    milestone_1 = create_mentoring_model_milestone(from_template: false)
    milestone_2 = create_mentoring_model_milestone(from_template: true)
    assert_equal [milestone_2], group.mentoring_model_milestones.reload.from_template
  end

  def test_translatable_fields_for_not_from_template_milestones
    group = groups(:mygroup)
    milestone_1 = create_mentoring_model_milestone(from_template: false)
    Globalize.with_locale(:en) do
      milestone_1.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"fr-CA") do
      milestone_1.update_attributes(title: "french title", description: "french description")
    end
    assert_equal 1, milestone_1.translations.count
    Globalize.with_locale(:en) do
      assert_equal "french title", milestone_1.title
      assert_equal "french description", milestone_1.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", milestone_1.title
      assert_equal "french description", milestone_1.description
    end

    milestone_2 = create_mentoring_model_milestone(from_template: true)
    Globalize.with_locale(:en) do
      milestone_2.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"fr-CA") do
      milestone_2.update_attributes(title: "french title", description: "french description")
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", milestone_2.title
      assert_equal "english description", milestone_2.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", milestone_2.title
      assert_equal "french description", milestone_2.description
    end
  end

  def test_es_reindex
    milestone = create_mentoring_model_milestone
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [milestone.group_id])
    MentoringModel::Milestone.es_reindex(milestone)
  end

  def test_reindex_group
    milestone = create_mentoring_model_milestone
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [milestone.group_id])
    MentoringModel::Milestone.reindex_group([milestone.group_id])
  end

  def test_reindex_followups
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(3).with(Group, [groups(:mygroup).id])
    milestone = create_mentoring_model_milestone
    milestone.destroy
  end

  def test_milestone_checkins_duration
    milestone = create_mentoring_model_milestone
    task = create_mentoring_model_task(milestone_id: milestone.id)

    task_checkin1 = create_task_checkin(task, :duration => 60)
    task_checkin2 = create_task_checkin(task, :duration => 45)

    assert_equal milestone.group_checkins_duration, 105
  end
end