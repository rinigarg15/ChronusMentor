require_relative './../../../test_helper.rb'

class MentoringModel::MilestonesHelperTest < ActionView::TestCase

  def test_marker_for_milestones_with_optional_tasks
    group = groups(:mygroup)
    group_status = group.status
    milestone1 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone1.id)
    milestone2 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone2.id)
    milestone3 = create_mentoring_model_milestone(group_id: group.id, title: "Homeland - Carrie Mathison")
    create_mentoring_model_task(milestone_id: milestone3.id)

    create_mentoring_model_task(milestone_id: milestone1.id, required: false)
    create_mentoring_model_task(milestone_id: milestone2.id, required: false, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(milestone_id: milestone3.id, required: false)

    milestone1_id = "milestone_progress_#{milestone1.id}"
    milestone2_id = "milestone_progress_#{milestone2.id}"
    milestone3_id = "milestone_progress_#{milestone3.id}"
    set_response_text(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required, group_status))
    assert_select "div" do
      assert_select "div#milestone_#{milestone1.id}" do
        assert_select "div##{milestone1_id}"
        assert_no_select "i.fa-caret-up"
      end
      assert_select "div#milestone_#{milestone2.id}" do
        assert_select "div##{milestone2_id}"
        assert_no_select "i.fa-caret-up"
      end
      assert_select "div#milestone_#{milestone3.id}" do
        assert_select "div##{milestone3_id}"
        assert_select "i.fa-caret-up"
      end
    end

    set_response_text(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required, group_status, true))
    assert_select "div" do
      assert_select "div#milestone_#{milestone1.id}" do
        assert_select "div##{milestone1_id}"
        assert_no_select "i.fa-caret-up"
      end
      assert_select "div#milestone_#{milestone2.id}" do
        assert_select "div##{milestone2_id}"
        assert_no_select "i.fa-caret-up"
      end
      assert_select "div#milestone_#{milestone3.id}" do
        assert_select "div##{milestone3_id}"
        assert_select "i.fa-caret-up"
        assert_select "div.small", text: "Current Milestone"
      end
    end
  end

  def test_render_milestones_progress_current_milestone
    group = groups(:mygroup)
    group_status = group.status
    milestone1 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone1.id)
    milestone2 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone2.id)
    milestone3 = create_mentoring_model_milestone(group_id: group.id, title: "Homeland - Carrie Mathison")
    create_mentoring_model_task(milestone_id: milestone3.id)  

    set_response_text(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required, group_status))
    assert_select "div" do
      assert_select "div.progress-bar.progress-bar-black", count: 3
    end
    assert_select "div.current_milestone_info"

    create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today - 2.days)
    create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today - 2.days, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(milestone_id: milestone3.id, required: true, due_date: Date.today + 2.days)
    milestone4 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone4.id, required: true, due_date: Date.today + 2.days)
    create_mentoring_model_task(milestone_id: milestone4.id, required: true, due_date: Date.today + 8.days)

    set_response_text(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required.group_by(&:milestone_id), group_status))
    assert_select "div" do
      assert_select "div.progress-bar.progress-bar-danger", count: 1
      assert_select "div.progress-bar.progress-bar-black", count: 1
      assert_select "div.progress-bar.progress-bar-dark-gray", count: 1
      assert_select "div.progress-bar", count: 4
    end
    assert_select "div.current_milestone_info" do
      assert_select "span.font-bold", text: "Homeland - Carrie Mathison"
      assert_select "ul" do
        assert_select "li", count: 1 do
          assert_select "span.text-muted", text: "1 pending task"
        end
      end
    end

    create_mentoring_model_task(milestone_id: milestone3.id, required: true, due_date: Date.today - 2.days, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(milestone_id: milestone3.id, required: true, due_date: Date.today - 2.days)

    set_response_text(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required.group_by(&:milestone_id), group_status))
    assert_select "div" do
      assert_select "div.progress-bar.progress-bar-danger", count: 2
      assert_select "div.progress-bar.progress-bar-black", count: 1
      assert_select "div.progress-bar.progress-bar-dark-gray", count: 1
    end
    assert_select "div.current_milestone_info" do
      assert_select "span.font-bold", text: "Homeland - Carrie Mathison"
      assert_select "ul" do
        assert_select "li", count: 3 do
          assert_select "span.text-muted", text: "1 pending task"
          assert_select "span.text-danger", text: "1 overdue task"
          assert_select "span", text: "1 completed task"
        end
      end
    end

    set_response_text(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required.group_by(&:milestone_id), Group::Status::CLOSED))
    assert_no_select "div.current_milestone_info"
  end

  def test_current_milestone_tasks
    tasks_list = ActiveSupport::OrderedHash.new
    tasks_list[:ongoing] = { count: 1, color: "text-navy" }
    tasks_list[:completed] = { count: 0, color: "text-success" }
    tasks_list[:overdue] = { count: 3, color: "text-danger" }

    assert_select_helper_function_block "div.milestone_status_list", current_milestone_tasks(tasks_list) do
      assert_select "ul" do
        assert_select "li", count: 2
        assert_select "li" do
          assert_select "span.text-navy", text: "1 pending task"
          assert_select "span.text-danger", text: "3 overdue tasks"
          assert_no_select "span.text-success"
        end
      end
    end
  end

  def test_milestone_popover_snippet
    group = groups(:mygroup)
    milestone1 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone1.id)
    create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 10.days)
    create_mentoring_model_task(milestone_id: milestone1.id, required: true, status: MentoringModel::Task::Status::DONE, due_date: Date.today + 10.days)

    required_tasks = milestone1.mentoring_model_tasks.required.group_by(&:milestone_id)
    set_response_text(milestone_popover_snippet(milestone1, required_tasks))

    assert_select "div.ct_popover_tasks_list" do
      assert_select "div.ct_popover_task_info", text: "1 pending, 1 completed"
    end
  end

  def test_get_current_milestone_text
    manage_connections_view = false
    set_response_text(get_current_milestone_text(manage_connections_view))
    assert_select "i.fa-caret-up"
    assert_no_select "div.small", text: "Current Milestone"

    manage_connections_view = true
    set_response_text(get_current_milestone_text(manage_connections_view))
    assert_select "i.fa-caret-up"
    assert_select "div.small", text: "Current Milestone"
  end

  def test_calculate_milestones_progress
    group = groups(:mygroup)
    group_status = group.status
    milestone1 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone1.id)
    milestone2 = create_mentoring_model_milestone(group_id: group.id)
    create_mentoring_model_task(milestone_id: milestone2.id)
    milestone3 = create_mentoring_model_milestone(group_id: group.id, title: "Homeland - Carrie Mathison")
    create_mentoring_model_task(milestone_id: milestone3.id)

    create_mentoring_model_task(milestone_id: milestone1.id, required: false)
    create_mentoring_model_task(milestone_id: milestone2.id, required: false, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(milestone_id: milestone3.id, required: false)

    set_response_text(calculate_milestones_progress(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required, group_status, true), milestone3, group.reload.mentoring_model_tasks.required, true))
    assert_no_select "div.current_milestone_info"

    set_response_text(calculate_milestones_progress(render_milestones_progress(group.reload.mentoring_model_milestones, group.reload.mentoring_model_tasks.required, group_status, true), milestone3, group.reload.mentoring_model_tasks.required, false))

    assert_select "div.current_milestone_info"
  end
end