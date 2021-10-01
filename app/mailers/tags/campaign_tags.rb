include CommonTags
include ActionView::Helpers::DateHelper
MailerTag.register_tags(:campaign_tags) do |t|
  t.get_common_user_tags

  t.tag :url_signup, :description => Proc.new{'feature.email.tags.campaign_tags.url_signup.description'.translate}, :example => Proc.new{'http://www.chronus.com'}, :name => Proc.new{'feature.email.tags.campaign_tags.url_signup.name'.translate}  do
    reset_password = Password.create!(:member => @member)
    url = new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => reset_password.reset_code)
    url.html_safe
  end

  t.get_contact_admin_url_tag

  t.tag :profile_completion_score, :description => Proc.new{'feature.email.tags.campaign_tags.profile_completion_score.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.profile_completion_score.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.profile_completion_score.name'.translate}  do
    @user.profile_score.sum
  end

  t.tag :url_profile_completion, :description => Proc.new{'feature.email.tags.campaign_tags.url_profile_completion.description'.translate}, :example => Proc.new{'http://www.chronus.com'}, :name => Proc.new{'feature.email.tags.campaign_tags.url_profile_completion.name'.translate}  do
    if @member.can_signin?
      url = edit_member_url(@member, :subdomain => @program.organization.subdomain, :first_visit => true)
    else
      reset_password = Password.create!(:member => @user.member)
      url = new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => reset_password.reset_code)
    end
    url.html_safe
  end

  t.tag :last_logged_in_on, :description => Proc.new{'feature.email.tags.campaign_tags.last_logged_in_on.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.last_logged_in_on.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.last_logged_in_on.name'.translate}  do
    last_login = @user.last_seen_at
    last_login ? formatted_time_in_words(last_login, :no_ago => false) : "feature.user.content.never_logged_in".translate
  end

  t.tag :join_date, :description => Proc.new{'feature.email.tags.campaign_tags.join_date.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.join_date.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.join_date.name'.translate} do
    DateTime.localize(@user.created_at, :format => "%b %d, %Y") #should recheck this
  end
end

MailerTag.register_tags(:mentoring_connection_tags) do |t|
  t.tag :available_connection_slots, :description => Proc.new{'feature.email.tags.campaign_tags.available_connection_slots.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.available_connection_slots.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.available_connection_slots.name'.translate} do
    @user.is_mentor? ? @user.slots_available : 0
  end
end

MailerTag.register_tags(:mentor_request_campaign_tags) do |t|
  t.tag :number_of_pending_mentor_requests, :description => Proc.new{'feature.email.tags.campaign_tags.number_of_pending_mentor_requests.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.number_of_pending_mentor_requests.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.number_of_pending_mentor_requests.name'.translate} do
    @user.received_mentor_requests.active.count
  end

  t.tag :mentor_request_acceptance_rate, :description => Proc.new{'feature.email.tags.campaign_tags.mentor_request_acceptance_rate.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.mentor_request_acceptance_rate.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.mentor_request_acceptance_rate.name'.translate} do
    mentor_request_acceptance_rate = @user.mentor_request_acceptance_rate
    'feature.email.tags.campaign_tags.mentor_request_acceptance_rate.value_html'.translate(value: mentor_request_acceptance_rate) unless mentor_request_acceptance_rate.nil?
  end

  t.tag :mentor_request_average_response_time, :description => Proc.new{'feature.email.tags.campaign_tags.mentor_request_average_response_time.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.mentor_request_average_response_time.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.mentor_request_average_response_time.name'.translate} do
    mentor_request_average_reponse_time = @user.mentor_request_average_reponse_time
    'feature.email.tags.campaign_tags.mentor_request_average_response_time.value_html'.translate(count: mentor_request_average_reponse_time) unless mentor_request_average_reponse_time.nil?
  end
end

MailerTag.register_tags(:meeting_request_campaign_tags) do |t|
  t.tag :number_of_pending_meeting_requests, :description => Proc.new{'feature.email.tags.campaign_tags.number_of_pending_meeting_requests.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.number_of_pending_meeting_requests.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.number_of_pending_meeting_requests.name'.translate} do
    @user.received_meeting_requests.active.count
  end

  t.tag :meeting_request_acceptance_rate, :description => Proc.new{'feature.email.tags.campaign_tags.meeting_request_acceptance_rate.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.meeting_request_acceptance_rate.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.meeting_request_acceptance_rate.name'.translate} do
    meeting_request_acceptance_rate = @user.meeting_request_acceptance_rate
    'feature.email.tags.campaign_tags.meeting_request_acceptance_rate.value_html'.translate(value: meeting_request_acceptance_rate) unless meeting_request_acceptance_rate.nil?
  end

  t.tag :meeting_request_average_response_time, :description => Proc.new{'feature.email.tags.campaign_tags.meeting_request_average_response_time.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.meeting_request_average_response_time.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.meeting_request_average_response_time.name'.translate} do
    meeting_request_average_reponse_time = @user.meeting_request_average_reponse_time
    'feature.email.tags.campaign_tags.meeting_request_average_response_time.value_html'.translate(count: meeting_request_average_reponse_time) unless meeting_request_average_reponse_time.nil?
  end
end

MailerTag.register_tags(:engagement_survey_campaign_tags) do |t|
  t.tag :survey_name, :description => Proc.new{'feature.email.tags.campaign_tags.survey_name.description'.translate}, :example => Proc.new{'feature.email.tags.campaign_tags.survey_name.example_html'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.survey_name.name'.translate} do
    @survey.name
  end

  t.tag :survey_url, :description => Proc.new{'feature.email.tags.campaign_tags.survey_url.description'.translate}, :example => Proc.new{"http://www.chronus.com"}, :name => Proc.new{'feature.email.tags.campaign_tags.survey_url.name'.translate} do
    options = {src: Survey::SurveySource::MAIL, task_id: @abstract_object.id, subdomain: @organization.subdomain, root: @program.root}
    edit_answers_survey_url(@survey, options)
  end

  t.tag :start_survey_button, :description => Proc.new{'feature.email.tags.campaign_tags.start_survey_button.description_v1'.translate}, :name => Proc.new{'feature.email.tags.campaign_tags.start_survey_button.name_v1'.translate}, :example => Proc.new{ ChronusActionMailer::Base.call_to_action_example("feature.email.tags.campaign_tags.survey_url.start_survey_v1".translate) } do
    options = {src: Survey::SurveySource::MAIL, task_id: @abstract_object.id, subdomain: @organization.subdomain, root: @program.root}
    campaigns_call_to_action("feature.email.tags.campaign_tags.survey_url.start_survey_v1".translate, edit_answers_survey_url(@survey, options))
  end

  t.tag :mentoring_connection_name, :description => Proc.new{|program| 'feature.email.tags.campaign_tags.group_name.description'.translate(program.return_custom_term_hash)}, :example => Proc.new{'feature.email.tags.campaign_tags.group_name.example'.translate}, :name => Proc.new{|program| 'feature.email.tags.campaign_tags.group_name.name'.translate(program.return_custom_term_hash)} do
    @abstract_object.group.name
  end

  t.tag :customized_mentoring_connection_term, :description => Proc.new{|program| 'feature.email.tags.custom_terms.customized_mentoring_connection_term_v1'.translate(program.return_custom_term_hash)}, :eval_tag => true do
    @_mentoring_connection_string
  end
end

# invite, program, organization instance variables have to be set, for the below placeholders to work fine
MailerTag.register_tags(:program_invitation_campaign_tags) do |t|
  t.tag :invitor_name, :description => Proc.new{'email_translations.invite_notification.tags.invitor_name.description'.translate}, :example => Proc.new{"John Doe"}, :name => Proc.new{'email_translations.invite_notification.tags.invitor_name.name'.translate} do
    @invite.user.present? ? get_sender_name(@invite.user) : customized_admin_term_capitalized
  end

  t.tag :role_name, description: Proc.new{'email_translations.invite_notification.tags.role_name.description'.translate}, example: Proc.new{|program| program.get_first_role_term(:term_downcase)}, name: Proc.new{'email_translations.invite_notification.tags.role_name.name'.translate} do
    human_role_string = RoleConstants.human_role_string(@invite.role_names, :program => @program, :no_capitalize => true)
    get_role_name_string(@invite.role_type, human_role_string)
  end

  t.tag :as_role_name_articleized, description: Proc.new{'email_translations.invite_notification.tags.as_role_name_articleized.description'.translate}, example: Proc.new{|program| 'email_translations.invite_notification.tags.as_role_name_articleized.example_v1'.translate(:role => program.get_first_role_term(:articleized_term_downcase))}, name: Proc.new{'email_translations.invite_notification.tags.as_role_name_articleized.name'.translate} do
    human_role_string = RoleConstants.human_role_string(@invite.role_names, :program => @program, :no_capitalize => true, :articleize => true)
    get_role_name_string(@invite.role_type, human_role_string, true)
  end

  t.tag :url_invitation, :description => Proc.new{'email_translations.invite_notification.tags.url_invitation.description'.translate}, :example => Proc.new{"http://www.chronus.com"}, :name => Proc.new{'email_translations.invite_notification.tags.url_invitation.name'.translate} do
    new_registration_url(invite_code: @invite.code, subdomain: @organization.subdomain)
  end

  t.tag :invitation_expiry_date, :description => Proc.new{'email_translations.invite_expiry_notification.tags.invitation_expiry_date.description'.translate}, :example => Proc.new{'email_translations.invite_expiry_notification.tags.invitation_expiry_date.example'.translate}, :name => Proc.new{'email_translations.invite_expiry_notification.tags.invitation_expiry_date.description'.translate} do
    formatted_time_in_words(@invite.expires_on, :no_ago => true, :no_time => true)
  end

  t.tag :subprogram_or_program_name, :description => Proc.new{'feature.email.tags.subprogram_tags.subprogram_or_program_name.description'.translate}, :name => Proc.new{'feature.email.tags.subprogram_tags.subprogram_or_program_name.name'.translate}, :eval_tag => true do
    (@program || @organization).name
  end

  t.tag :url_subprogram_or_program, :description => Proc.new{'feature.email.tags.subprogram_tags.url_subprogram_or_program.description'.translate}, :name => Proc.new{'feature.email.tags.subprogram_tags.url_subprogram_or_program.name'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    if @program
      url_subprogram
    else
      url_program
    end
  end

  t.tag :url_contact_admin, :description => Proc.new{'feature.email.tags.campaign_tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'}, :name => Proc.new{'feature.email.tags.campaign_tags.url_contact_admin.name'.translate}  do
    get_contact_admin_path(@program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @program.root}})
  end

  private

  def get_role_name_string(invite_type, human_role_string, having_as = false)
    if invite_type == ProgramInvitation::RoleType::ASSIGN_ROLE
      return "email_translations.invite_notification.as".translate + " " + human_role_string if having_as
      return human_role_string
    else
      return "" if having_as
      return "display_string.member".translate
    end
  end

end