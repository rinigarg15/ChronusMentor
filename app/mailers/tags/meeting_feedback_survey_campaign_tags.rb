include ActionView::Helpers::DateHelper
MailerTag.register_tags(:meeting_feedback_survey_campaign_tags) do |t|
  t.tag :topic_of_meeting, :description => Proc.new{|program| 'feature.email.tags.campaign_tags.meeting_topic.description'.translate(program.return_custom_term_hash)}, :example => Proc.new{'feature.email.tags.campaign_tags.meeting_topic.example'.translate}, :name => Proc.new{|program| 'feature.email.tags.campaign_tags.meeting_topic.name'.translate(program.return_custom_term_hash)} do
    @abstract_object.meeting.topic
  end

  t.tag :partner_name, :description => Proc.new{'feature.email.tags.campaign_tags.partner_name.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.partner_name.example'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.partner_name.name'.translate} do
    @abstract_object.other_members.collect(&:name).to_sentence
  end

  t.tag :feedback_survey_url, :description => Proc.new{'feature.email.tags.campaign_tags.survey_url.description'.translate}, :example => Proc.new{"http://www.chronus.com"}, :name => Proc.new{'feature.email.tags.campaign_tags.survey_url.name'.translate} do
    options = {src: Survey::SurveySource::MAIL, member_meeting_id: @abstract_object.id, subdomain: @organization.subdomain, root: @program.root, meeting_occurrence_time: @abstract_object.meeting.first_occurrence}
    participate_survey_url(@survey, options)
  end

  t.tag :meeting_area_url, :description => Proc.new{|program| 'feature.email.tags.campaign_tags.meeting_area_url.description'.translate(program.return_custom_term_hash)}, :example => Proc.new{"http://www.chronus.com"}, :name => Proc.new{|program| 'feature.email.tags.campaign_tags.meeting_area_url.name'.translate(program.return_custom_term_hash)} do
    options = {src: Survey::SurveySource::MAIL, subdomain: @organization.subdomain, root: @program.root, current_occurrence_time: @abstract_object.meeting.first_occurrence}
    meeting_url(@abstract_object.meeting, options)
  end

  t.tag :meeting_reschedule_url, :description => Proc.new{|program| 'feature.email.tags.campaign_tags.meeting_reschedule_url.description'.translate(program.return_custom_term_hash)}, :example => Proc.new{"http://www.chronus.com"}, :name => Proc.new{|program| 'feature.email.tags.campaign_tags.meeting_reschedule_url.name'.translate(program.return_custom_term_hash)} do
    options = {src: Survey::SurveySource::MAIL, subdomain: @organization.subdomain, root: @program.root, edit_time: true, current_occurrence_time: @abstract_object.meeting.first_occurrence}
    meeting_url(@abstract_object.meeting, options)
  end

  t.tag :customized_meeting_term, :description => Proc.new{|program| 'feature.email.tags.custom_terms.customized_meeting_term'.translate(program.return_custom_term_hash)}, :eval_tag => true do
    @_meeting_string
  end

  t.tag :feedback_survey_button, :description => Proc.new{'feature.email.tags.campaign_tags.feedback_survey_button.description'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.feedback_survey_button.name'.translate}, :example => Proc.new{ ChronusActionMailer::Base.call_to_action_example("feature.meetings.action.provide_feedback".translate) } do
    options = {src: Survey::SurveySource::MAIL, member_meeting_id: @abstract_object.id, subdomain: @organization.subdomain, root: @program.root, meeting_occurrence_time: @abstract_object.meeting.first_occurrence}
    campaigns_call_to_action("feature.meetings.action.provide_feedback".translate, participate_survey_url(@survey, options))
  end
end