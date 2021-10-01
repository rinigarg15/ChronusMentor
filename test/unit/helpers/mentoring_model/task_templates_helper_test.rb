require_relative './../../../test_helper.rb'

class MentoringModel::TaskTemplatesHelperTest < ActionView::TestCase

  def test_params_content
    t1 = create_mentoring_model_task_template
    t2 = create_mentoring_model_task_template
    @mentoring_model = t1.mentoring_model
    content = params_content([t1, t2])
    assert content[1]
    assert content[0].present?

    content = params_content([])
    assert_false content[1]
    assert content[0].blank?
  end

  def test_calculate_tooltip_text
    t1 = create_mentoring_model_task_template
    s = programs(:psg).surveys.find_by(name: "Mentoring Connection Activity Feedback")
    t1.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    t1.action_item_id = s.id
    tooltip_text = calculate_tooltip_text(t1) 
    assert_equal tooltip_text, "Reminders are sent 3 days and 7 days to the assignee after the survey task is overdue. Click here to view and update the reminders."
    s.campaign.campaign_messages.first.delete
    tooltip_text = calculate_tooltip_text(t1) 
    assert_equal tooltip_text, "Reminders are sent 7 days to the assignee after the survey task is overdue. Click here to view and update the reminders."
    s.campaign.campaign_messages.first.delete
    tooltip_text = calculate_tooltip_text(t1) 
    assert_equal tooltip_text, "Click here to view and update the reminders."
  end

  private

  def _Meeting
    "Meeting"
  end

end