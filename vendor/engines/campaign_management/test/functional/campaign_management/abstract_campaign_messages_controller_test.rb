require_relative './../../test_helper.rb'

class CampaignManagement::AbstractCampaignMessagesControllerTest < ActionController::TestCase
  def setup
    super
    current_program_is :albers
  end

  def test_new_not_logged_in
    get :new, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id }
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      get :new, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id }
    end
  end

  def test_create_not_logged_in
    post :create, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id }
    assert_redirected_to new_session_path
  end

  def test_create_non_admin_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      post :create, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id }
    end
  end

  def test_edit_not_logged_in
    get :edit, params: { id: cm_campaign_messages(:campaign_message_1).id, user_campaign_id: cm_campaigns(:active_campaign_1).id }
    assert_redirected_to new_session_path
  end

  def test_edit_non_admin_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      get :edit, params: { id: cm_campaign_messages(:campaign_message_1).id, user_campaign_id: cm_campaigns(:active_campaign_1).id }
    end
  end

  def test_update_not_logged_in
    put :update, params: { id: cm_campaign_messages(:campaign_message_1).id, user_campaign_id: cm_campaigns(:active_campaign_1).id }
    assert_redirected_to new_session_path
  end

  def test_update_non_admin_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      put :update, params: { id: cm_campaign_messages(:campaign_message_1).id, user_campaign_id: cm_campaigns(:active_campaign_1).id }
    end
  end

  def test_create_success
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id
    assert_difference "CampaignManagement::AbstractCampaignMessage.count", 1 do
      post :create, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "12", :mailer_template => {:subject => "Sample", :source => "Sample content"}}}
    end
    assert_redirected_to details_campaign_management_user_campaign_path(:id => cm_campaigns(:active_campaign_1).id)
    assert_equal html_escape("The email 'Sample' has been added to the campaign 'Campaign1 Name'"), flash[:notice]
    assert assigns(:campaign_message).valid?
    assert_equal admin_id, assigns(:campaign_message).sender_id
    assert_equal 12, assigns(:campaign_message).duration
    email_template = assigns(:campaign_message).email_template
    assert email_template
    assert_equal "Sample content", email_template.source
    assert_equal "Sample", email_template.subject
  end

  def test_create_success_start_draft_campaign
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::DRAFTED, enabled_at: nil)
    assert campaign.drafted?
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id

    Timecop.freeze(Time.now) do
      assert_difference "CampaignManagement::AbstractCampaignMessage.count", 1 do
        post :create, params: { :user_campaign_id => campaign.id, :sender_id => admin_id,
        :campaign_management_abstract_campaign_message => {:duration => "0", :mailer_template => {:subject => "Sample", :source => "Sample content"}}, start_campaign: 'true'}
      end
      assert_redirected_to details_campaign_management_user_campaign_path(:id => campaign.id)
      assert_equal html_escape("Congratulations on starting the 'Campaign1 Name' campaign. You can track the effectiveness of the campaign on the campaign page. The emails ' \"Campaign Message - Subject1\", \"Sample\" ' will be sent to targeted users within couple of hours."), flash[:notice]
      assert assigns(:campaign_message).valid?
      assert_equal admin_id, assigns(:campaign_message).sender_id
      assert_equal 0, assigns(:campaign_message).duration
      email_template = assigns(:campaign_message).email_template
      assert email_template
      assert_equal "Sample content", email_template.source
      assert_equal "Sample", email_template.subject
      assert campaign.reload.active?
      assert_equal Time.now.utc.to_s(:db), campaign.enabled_at.utc.to_s(:db)
    end
  end

  def test_create_success_in_active_campaign
    campaign = cm_campaigns(:active_campaign_1)
    admin_id = programs(:albers).admin_users.first.id

    Timecop.freeze(Time.now) do
      campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::ACTIVE, enabled_at: nil)
      current_user_is :f_admin
      assert_difference "CampaignManagement::AbstractCampaignMessage.count" do
        post :create, params: { :user_campaign_id => campaign.id, :sender_id => admin_id,
        :campaign_management_abstract_campaign_message => {:duration => "0", :mailer_template => {:subject => "Sample", :source => "Sample content"}}}
      end
      assert_redirected_to details_campaign_management_user_campaign_path(:id => campaign.id)
      assert_equal html_escape("The email 'Sample' has been added to the campaign 'Campaign1 Name'. The email 'Sample' will be sent to targeted users within couple of hours."), flash[:notice]
      assert assigns(:campaign_message).valid?
      assert_equal admin_id, assigns(:campaign_message).sender_id
      assert_equal 0, assigns(:campaign_message).duration
      email_template = assigns(:campaign_message).email_template
      assert email_template
      assert_equal "Sample content", email_template.source
      assert_equal "Sample", email_template.subject
      assert campaign.reload.active?
      assert_equal Time.now.utc.to_s(:db), campaign.enabled_at.utc.to_s(:db)
    end
  end

  def test_create_success_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    assert_no_difference "VulnerableContentLog.count" do
      assert_difference "CampaignManagement::AbstractCampaignMessage.count", 1 do
        post :create, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :sender_id => admin_id,
        :campaign_management_abstract_campaign_message => {:duration => "12", :mailer_template => {:subject => "Sample", :source => "Sample content<script>alert(10);</script>"}}}
      end
    end
  end

  def test_create_success_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    assert_difference "VulnerableContentLog.count" do
      assert_difference "CampaignManagement::AbstractCampaignMessage.count", 1 do
        post :create, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :sender_id => admin_id,
        :campaign_management_abstract_campaign_message => {:duration => "12", :mailer_template => {:subject => "Sample", :source => "Sample content<script>alert(10);</script>"}}}
      end
    end
  end

  def test_create_should_fail_when_email_template_contains_invalid_tags
    admin_id = programs(:albers).admin_users.first.id
    #invalid source and subject tags
    assert_no_difference "CampaignManagement::AbstractCampaignMessage.count" do
      post :create, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "12", :mailer_template => {:subject => "Sample {{invalid_subject_tag}}", :source => "Sample content {{invalid_source_tag}}"}}}
    end
    assert assigns(:campaign_message).nil?

    #invalid subject syntax
    assert_no_difference "CampaignManagement::AbstractCampaignMessage.count" do
      post :create, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "12", :mailer_template => {:subject => "Hello {{user_firstname}", :source => "Hi {{user_name}}"}}}
    end
    assert assigns(:campaign_message).nil?

    #invalid source syntax
    assert_no_difference "CampaignManagement::AbstractCampaignMessage.count" do
      post :create, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "12", :mailer_template => {:subject => "Hello {{user_firstname}}", :source => "Hi {{user_name}"}}}
    end
    assert assigns(:campaign_message).nil?
  end

  def test_update_failure
    current_user_is :f_admin
    campaign_message_id = cm_campaigns(:active_campaign_1).campaign_messages.first.id
    assert_no_difference "CampaignManagement::AbstractCampaignMessage.count" do
      put :update, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id,
      :id => campaign_message_id, :campaign_management_abstract_campaign_message => { :duration => "", :mailer_template => {:subject => "", :source => ""}}}
    end
    assert_false assigns(:campaign_message).valid?
    assert_equal "Please fix the highlighted errors.", flash[:error]
    campaign_title = "'#{cm_campaigns(:active_campaign_1).title}'"
    link = "#{details_campaign_management_user_campaign_path(cm_campaigns(:active_campaign_1))}"
    back_link = {:label=>"#{campaign_title}",:link=>"#{link}"}
    assert_equal back_link, assigns(:back_link)
    assert assigns(:tour_taken)
    assert_false assigns(:less_than_ie9)
  end

  def test_update_success
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.last.id
    campaign_message_id = cm_campaigns(:active_campaign_1).campaign_messages.first.id
    assert_no_difference "CampaignManagement::AbstractCampaignMessage.count" do
      put :update, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :id => campaign_message_id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "121", :mailer_template => {:subject => "Sample Update", :source => "Sample content update"}}}
    end
    assert_redirected_to details_campaign_management_user_campaign_path(:id => cm_campaigns(:active_campaign_1).id)
    assert assigns(:campaign_message).valid?
    assert_equal "The email has been successfully updated.", flash[:notice]
    assert_equal admin_id, assigns(:campaign_message).sender_id
    assert_equal 121, assigns(:campaign_message).duration
    email_template = assigns(:campaign_message).email_template
    assert email_template
    assert_equal "Sample content update", email_template.source
    assert_equal "Sample Update", email_template.subject
  end

  def test_update_success_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.last.id
    campaign_message_id = cm_campaigns(:active_campaign_1).campaign_messages.first.id
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    assert_no_difference "VulnerableContentLog.count" do
      assert_no_difference "CampaignManagement::AbstractCampaignMessage.count" do
        put :update, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :id => campaign_message_id, :sender_id => admin_id,
        :campaign_management_abstract_campaign_message => {:duration => "121", :mailer_template => {:subject => "Sample Update", :source => "Sample content update<script>alert(10);</script>"}}}
      end
    end
  end

  def test_update_success_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.last.id
    campaign_message_id = cm_campaigns(:active_campaign_1).campaign_messages.first.id
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    assert_difference "VulnerableContentLog.count" do
      assert_no_difference "CampaignManagement::AbstractCampaignMessage.count" do
        put :update, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :id => campaign_message_id, :sender_id => admin_id,
        :campaign_management_abstract_campaign_message => {:duration => "121", :mailer_template => {:subject => "Sample Update", :source => "Sample content update<script>alert(10);</script>"}}}
      end
    end
  end

  def test_auto_complete_for_name
    current_user_is :f_admin
    program = programs(:albers)
    get :auto_complete_for_name, xhr: true, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :format => :json}
    assert_response :success
    result = YAML.load(response.body)
    assert_equal program.name, result[0]["title"]
    assert_nil result[0]["id"]
    assert_equal program.admin_users.first.name(:name_only => true), result[1]["title"]
    assert_equal program.admin_users.first.id, result[1]["id"]
    assert_equal program.admin_users.last.name(:name_only => true), result[2]["title"]
    assert_equal program.admin_users.last.id, result[2]["id"]
  end

  def test_auto_complete_for_name_properly_escaped
    current_user_is :f_admin
    program = programs(:albers)
    admin = users(:ram)
    admin.member.update_attributes!(first_name: "Kal@Ram")
    reindex_documents(updated: admin.member.users)
    get :auto_complete_for_name, xhr: true, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, search: "Kal@Ram", :format => :json}
    assert_response :success
    result = YAML.load(response.body)
    assert_equal admin.name(name_only: true), result[0]["title"]
    assert_equal admin.id, result[0]["id"]
  end

  def test_auto_complete_for_name_should_not_have_mentor_admin
    user = users(:f_admin)
    user.member.update_attribute(:email, SUPERADMIN_EMAIL)

    current_user_is user
    get :auto_complete_for_name, xhr: true, params: { user_campaign_id: cm_campaigns(:active_campaign_2).id, format: :json }
    assert_response :success
    result = YAML.load(response.body)
    assert_equal 2, result.size
    assert_equal_hash( { "title" => user.program.name, "id" => nil }, result[0])
    assert_equal_hash( { "title" => users(:ram).name(name_only: true), "id" => users(:ram).id }, result[1])
  end

  def test_fetch_campaign_email_tags
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.last.id
    campaign_message_id = cm_campaigns(:active_campaign_1).campaign_messages.first.id
    put :update, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :id => campaign_message_id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "121", :mailer_template => {:subject => "Sample Update", :source => "Sample content update"}}}
    assert_equal 16, assigns(:all_tags).count
  end

  def test_fetch_campaign_email_tags_should_populate_flash_mentoring_tags_if_feature_enabled_and_in_order
    current_user_is :f_admin
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    admin_id = programs(:albers).admin_users.last.id
    campaign_message_id = cm_campaigns(:active_campaign_1).campaign_messages.first.id
    put :update, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :id => campaign_message_id, :sender_id => admin_id, :campaign_management_abstract_campaign_message => {:duration => "121", :mailer_template => {:subject => "Sample Update", :source => "Sample content update"}}}

    expected_tags_order = [:user_firstname, :user_lastname, :user_name, :user_email, :user_role, :url_signup, :url_contact_admin, :profile_completion_score, :url_profile_completion, :last_logged_in_on, :join_date, :available_connection_slots, :number_of_pending_mentor_requests, :mentor_request_acceptance_rate, :mentor_request_average_response_time, :recommended_mentors, :number_of_pending_meeting_requests, :meeting_request_acceptance_rate, :meeting_request_average_response_time]

    assert_equal 19, assigns(:all_tags).count
    assert_equal expected_tags_order, assigns(:all_tags).keys
  end

  def test_fetch_campaign_email_tags_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_admin
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    admin_id = programs(:albers).admin_users.last.id
    campaign_message_id = cm_campaigns(:active_campaign_1).campaign_messages.first.id
    put :update, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :id => campaign_message_id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "121", :mailer_template => {:subject => "Sample Update", :source => "Sample content update"}}}

    assert_false assigns(:all_tags).keys.include?(:available_connection_slots)
    assert_false assigns(:all_tags).keys.include?(:number_of_pending_mentor_requests)
    assert_false assigns(:all_tags).keys.include?(:mentor_request_acceptance_rate)
    assert_false assigns(:all_tags).keys.include?(:mentor_request_average_response_time)
  end

  def test_new_success
    current_user_is :f_admin
    get :new, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id}
    assert_equal cm_campaigns(:active_campaign_1), assigns(:campaign)
    assert_response :success
  end

  def test_create_failure_should_flash_error_message_and_redirect_to_new
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id
    assert_difference "CampaignManagement::AbstractCampaignMessage.count", 0 do
      post :create, params: { :user_campaign_id => cm_campaigns(:active_campaign_1).id, :sender_id => admin_id,
      :campaign_management_abstract_campaign_message => {:duration => "-1", :mailer_template => {:subject => "Sample", :source => "Sample content"}}}
    end

    assert_equal "Please fix the highlighted errors.", flash[:error]
    campaign_title = "'#{cm_campaigns(:active_campaign_1).title}'"
    link = "#{details_campaign_management_user_campaign_path(cm_campaigns(:active_campaign_1))}"
    back_link = {:label=>"#{campaign_title}",:link=>"#{link}"}
    assert_equal back_link, assigns(:back_link)
    assert_false assigns(:tour_taken)
    assert_false assigns(:less_than_ie9)
    assert_template :new
  end

  def test_edit_success
    current_user_is :f_admin
    get :edit, params: { :id => cm_campaign_messages(:campaign_message_1), :user_campaign_id => cm_campaigns(:active_campaign_1)}
    assert_equal cm_campaigns(:active_campaign_1), assigns(:campaign)
    assert_equal cm_campaign_messages(:campaign_message_1), assigns(:campaign_message)
  end

  def test_index_html_success
    current_user_is :f_admin
    cm_campaign_messages(:campaign_message_1).update_attributes(:duration => 25)

    get :index, params: { :user_campaign_id => cm_campaigns(:active_campaign_1)}
    assert_equal cm_campaigns(:active_campaign_1), assigns(:campaign)
    assert_equal [cm_campaign_messages(:campaign_message_2), cm_campaign_messages(:campaign_message_3), cm_campaign_messages(:campaign_message_4), cm_campaign_messages(:campaign_message_1)], assigns(:campaign_messages)
    assert_response :success
  end

  def test_index_json_success
    current_user_is :f_admin
    get :index, xhr: true, params: { :user_campaign_id => cm_campaigns(:active_campaign_1), :format => :json}
    assert_equal cm_campaigns(:active_campaign_1), assigns(:campaign)
    assert_equal [cm_campaign_messages(:campaign_message_1), cm_campaign_messages(:campaign_message_2), cm_campaign_messages(:campaign_message_3), cm_campaign_messages(:campaign_message_4)], assigns(:campaign_messages)
    assert_response :success
  end

  def test_destroy_success
    current_user_is :f_admin
    assert_difference "CampaignManagement::AbstractCampaignMessage.count", -1 do
      delete :destroy, xhr: true, params: { id: cm_campaign_messages(:campaign_message_1).id, user_campaign_id: cm_campaigns(:active_campaign_1).id }
    end
    assert_template :refresh
  end

  def test_sent_test_email_success
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id

    assert_difference "ActionMailer::Base.deliveries.count", 1 do
      post :send_test_email, xhr: true, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id, sender_id: admin_id,
        campaign_management_abstract_campaign_message: {duration: "12", mailer_template: {subject: "Test mail to {{user_firstname}}", source: "Sample content sent to {{user_email}}"}} }
    end

    assert_response :success

    email = ActionMailer::Base.deliveries.last
    assert_equal "Test mail to John", email.subject
    assert_match "Sample content sent to johndoe@example.com", get_text_part_from(email)
    assert_match /#{programs(:albers).name}/, get_html_part_from(email) #campaign emails header should contain the program name
  end

  def test_sent_test_email_success_invitations
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id
    campaign = programs(:albers).program_invitation_campaign
    assert_difference "ActionMailer::Base.deliveries.count", 1 do
      post :send_test_email, xhr: true, params: { user_campaign_id: campaign,
        campaign_management_abstract_campaign_message: {mailer_template: {subject: "Test mail", source: "Sample content"}}}
    end

    assert_response :success
    email = ActionMailer::Base.deliveries.last
    assert_equal "Test mail", email.subject
    assert_match "Sample content", get_text_part_from(email)
    assert_match /#{programs(:albers).name}/, get_html_part_from(email) #campaign emails header should contain the program name
  end

  def test_sent_test_email_should_fail_when_email_contains_invalid_tags
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id

    assert_no_difference "ActionMailer::Base.deliveries.count" do
      post :send_test_email, xhr: true, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id, sender_id: admin_id,
        campaign_management_abstract_campaign_message: {duration: "12", mailer_template: {subject: "{{invalid_subject_tag}}", source: "Hello {{invalid_source_tag}}"}}}
    end
    assert_equal "Subject contains invalid tags - {{invalid_subject_tag}} and Body contains invalid tags - {{invalid_source_tag}}", assigns(:campaign_message_email_failure)
  end

  def test_sent_test_email_should_fail_when_email_contains_invalid_syntax_tags
    current_user_is :f_admin
    admin_id = programs(:albers).admin_users.first.id

    assert_no_difference "ActionMailer::Base.deliveries.count" do
      post :send_test_email, xhr: true, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id, sender_id: admin_id,
        campaign_management_abstract_campaign_message: {duration: "12", mailer_template: {subject: "Test Subject", source: "Hello {{user_firstname}"}}}
    end
    assert_equal "Body contains invalid syntax, donot apply any styles within flower braces of the tag", assigns(:campaign_message_email_failure)

    assert_no_difference "ActionMailer::Base.deliveries.count" do
      post :send_test_email, xhr: true, params: { user_campaign_id: cm_campaigns(:active_campaign_1).id, sender_id: admin_id,
        campaign_management_abstract_campaign_message: {duration: "12", mailer_template: {subject: "Hi {{user_name}", source: "Hello {{user_firstname}}"}}}
    end
    assert_equal "Subject contains invalid syntax, donot apply any styles to the tags in subject", assigns(:campaign_message_email_failure)
  end

  def test_new_campaign_email_should_initialize_back_link_label_and_url_and_title
    current_user_is :f_admin

    #user campaign: new campaign email
    campaign = cm_campaigns(:active_campaign_1)
    get :new, params: { :user_campaign_id => campaign.id}
    assert_equal campaign, assigns(:campaign)
    assert_response :success

    assert_equal "'#{campaign.title}'", assigns(:back_link)[:label]
    assert_match 'details', assigns(:back_link)[:link]
    assert_equal "New Campaign: '#{campaign.title}'", assigns(:new_campaign_email_title)

    #new program invitation email
    campaign = programs(:albers).program_invitation_campaign
    get :new, params: { :program_invitation_campaign_id => campaign.id}
    assert_equal campaign, assigns(:campaign)
    assert_response :success

    assert_equal "Invitations", assigns(:back_link)[:label]
    assert_equal "/p/albers/invite_users", assigns(:back_link)[:link]
    assert_equal "New Invitation Email", assigns(:new_campaign_email_title)
  end

  def test_edit_campaign_email_should_initialize_edit_title
    current_user_is :f_admin

    campaign = cm_campaigns(:active_campaign_1)
    get :edit, params: { :id => cm_campaign_messages(:campaign_message_1), :user_campaign_id => campaign.id}
    assert_response :success
    assert_equal "Edit Campaign: '#{campaign.title}'", assigns(:edit_campaign_email_title)

    campaign = programs(:albers).program_invitation_campaign
    get :edit, params: { :id => campaign.campaign_messages.last.id, :user_campaign_id => campaign.id}
    assert_response :success
    assert_equal "Edit Invitation Email", assigns(:edit_campaign_email_title)
  end

  def test_new_cm_for_survey_campaign
    current_user_is :f_admin
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    campaign = survey.campaign

    get :new, params: { survey_campaign_id: campaign.id}
    assert_equal campaign, assigns(:campaign)
    assert_response :success
    assert_equal campaign.campaign_email_tags, assigns(:all_tags)
    assert_equal "feature.survey.content.new_reminder_email".translate, assigns(:new_campaign_email_title)
    assert_equal reminders_survey_path(survey), assigns(:back_url)
    assert_equal "feature.survey.content.Reminders".translate, assigns(:back_link)[:label]
  end

  def test_edit_cm_for_survey_campaign
    current_user_is :f_admin
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    campaign = survey.campaign
  end

end
