module MentoringModel::TaskTemplatesHelper
  def milestone_template_options(milestone_templates)
    milestone_templates.map do |milestone_template|
      [milestone_template.title, milestone_template.id]
    end
  end

  def new_task_template_options(partial_options)
    link_options = {format: :js}
    link_options.merge!(milestone_template_id: partial_options[:milestone_template_id]) if partial_options.has_key?(:milestone_template_id)
    link_options
  end

  def params_content(task_templates)
    merge_top_required = true
    if task_templates.present?
      content = render partial: "mentoring_model/task_templates/task_template", collection: task_templates
    else
      content = ""
      merge_top_required = false
    end
    [content, merge_top_required]
  end

  def choose_appropriate_option(task_template, drop_down_options)
    if task_template.new_record?
      drop_down_options.last[1]
    elsif task_template.associated_id.present?
      task_template.associated_task.id
    else
      drop_down_options.first[1]
    end
  end

  def calculate_tooltip_text(task_template) 
    survey_campaign = task_template.action_item.campaign
    tooltip_text = ""
    if survey_campaign.present?
      sorted_reminder_durations_with_days = survey_campaign.campaign_messages.pluck(:duration).sort.map{|duration|
        "feature.mentoring_model.label.days".translate(count: duration)}.try(:to_sentence)
    end

    tooltip_text = "feature.mentoring_model.label.due_date_reminder_durations_label_description".translate(reminder_durations:sorted_reminder_durations_with_days) if sorted_reminder_durations_with_days.present?
    tooltip_text += "feature.mentoring_model.label.due_date_reminder_label_description".translate
    return tooltip_text.html_safe
  end

end