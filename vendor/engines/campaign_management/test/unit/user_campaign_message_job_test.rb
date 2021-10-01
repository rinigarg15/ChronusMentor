require_relative './../test_helper'

class UserCampaignMessageJobTest < ActiveSupport::TestCase
  def setup
    super
    @user = users(:f_student)
    @campaign_message = cm_campaign_messages(:campaign_message_1)
    @campaign = @campaign_message.campaign
    @job = cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_student)
    @job.update_attributes!(run_at: 5.minutes.ago)
  end

  def test_belongs
    assert_equal @user, @job.user
    assert_equal @campaign_message, @job.campaign_message
  end

  def test_validations
    status = CampaignManagement::UserCampaignMessageJob.new(user: nil, campaign_message: nil, run_at: nil)

    assert_false status.valid?
    assert status.errors.has_key?(:user)
    assert status.errors.has_key?(:campaign_message)
    assert status.errors.has_key?(:run_at)
  end

  # Added the names aaa and aab just to make sure they run in order
  def test_aaa_if_user_not_found
    @user.destroy
    assert_equal false, @job.failed
    assert_equal 4, @campaign.jobs.where(:abstract_object_id => @user.id).count

    assert @job.create_personalized_message
    assert_equal 4, @campaign.jobs.where(:abstract_object_id => @user.id).count
  end

  def test_aab_send_message_to_should_trigger_an_email
    @job.create_personalized_message
    email = AdminMessage.last
    # See if we can test with tags replaced
    assert_equal "Campaign Message - Subject1", email.subject
  end

  def test_dj_should_send_an_admin_message
    assert_difference "AdminMessage.count", 1 do
      assert_difference "@campaign.jobs.where(:abstract_object_id => @user.id).count", 0 do
        @job.create_personalized_message
      end
    end
  end

  def test_normal_case
    CampaignManagement::AbstractCampaign.any_instance.stubs(:abstract_object_ids => [@user.id])
    @job.create_personalized_message
    assert_equal 4, @campaign.jobs.where(:abstract_object_id => @user.id).count
  end

  def test_user_was_not_found
    @user.destroy
    assert @job.create_personalized_message
    assert_equal 4, @campaign.jobs.where(:abstract_object_id => @user.id).count
  end

  # User Job status -- Where should that be changed ?
  def test_mails_should_go_to_inactive_users
    stub_parallel
    @user.suspend_from_program!(users(:f_admin), "Sample Reason")
    @job.create_personalized_message
    email = AdminMessage.last
    # See if we can test with tags replaced
    assert_equal "Campaign Message - Subject1", email.subject
    assert_equal 4, @campaign.jobs.where(:abstract_object_id => @user.id).count
  end

  def test_campaign_message_not_found
    @campaign_message.destroy
    assert_equal false, @job.failed

    Airbrake.expects(:notify)

    assert_no_emails do
      assert_false @job.create_personalized_message
    end
    assert_equal 3, @campaign.jobs.where(:abstract_object_id => @user.id).count
  end

  def test_program_removed
    @user.program.delete
    Airbrake.expects(:notify)
    assert_false @job.create_personalized_message
    assert_equal 4, @campaign.jobs.where(:abstract_object_id => @user.id).count
  end

  def test_template_removed
    @campaign_message.email_template.delete

    Airbrake.expects(:notify)
    assert_false @job.create_personalized_message
    assert_equal 4, @campaign.jobs.where(:abstract_object_id => @user.id).count
  end

  def test_auto_link_of_messages
    @campaign_message.email_template.update_attributes(:subject => "Sample", :source => "Sample content for raw url http://google.com and sample content for anchored url <a href=\"http://google.com\">http://google.com</a> {{url_contact_admin}}")

    @job.create_personalized_message
    # See if we can test with tags replaced
    assert_equal "Sample content for raw url <a href=\"http://google.com\">http://google.com</a> and sample content for anchored url <a href=\"http://google.com\">http://google.com</a> <a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/contact_admin\">https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/contact_admin</a><style>\n</style>", AdminMessage.last.content

  end

  def test_check_mentor_and_meeting_request_campaign_tags
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    mentor_request = mentor_requests(:mentor_request_0)
    user = mentor_request.mentor
    responded_mentor_request = user.received_mentor_requests.accepted + user.received_mentor_requests.rejected
    responded_mentor_request.each do |request|
      request.update_attributes!(:updated_at => mentor_requests(:mentor_request_0).created_at + 10.hours)
    end
    @campaign_message.email_template.subject = "Hello {{user_firstname}}, you have {{number_of_pending_mentor_requests}} pending mentor requests and {{number_of_pending_meeting_requests}} pending meeting requests"
    @campaign_message.email_template.source = "mentor_request_acceptance_rate: {{mentor_request_acceptance_rate}}<br />mentor_request_average_response_time: {{mentor_request_average_response_time}}<br />meeting_request_acceptance_rate: {{meeting_request_acceptance_rate}}<br />meeting_request_average_response_time: {{meeting_request_average_response_time}} and use {{url_signup}} to invite mentees."
    @campaign_message.email_template.save!
    job = CampaignManagement::UserCampaignMessageJob.find_or_initialize_by(abstract_object_id: user.id, campaign_message_id: @campaign_message.id)
    job.run_at = 5.minutes.ago
    job.save!
    job.create_personalized_message
    assert_equal "Hello Good unique, you have 11 pending mentor requests and 1 pending meeting requests", AdminMessage.last.subject
    assert_match("mentor_request_acceptance_rate: 0.0%<br />mentor_request_average_response_time: 10.0 hours<br />meeting_request_acceptance_rate: 100.0%<br />meeting_request_average_response_time: 0.0 hours", AdminMessage.last.content)
    assert_match("https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/users/new_user_followup", AdminMessage.last.content)
  end

    # Add a test case for AP-8847
  def test_check_mentoring_connection_tags_when_anchored_to_text
    mentor_request = mentor_requests(:mentor_request_0)
    user = mentor_request.mentor
    @campaign_message.email_template.subject = "Hello {{user_lastname}}, your profile score is {{profile_completion_score}}"
    @campaign_message.email_template.source = "Your have {{last_logged_in_on}}, from {{join_date}} but available connection slots are {{available_connection_slots}} and <a href=\"{{url_profile_completion}}\">Click here to complete your profile</a><br /> please contact admin  <a href=\"{{url_contact_admin}}\">here</a>"

    @campaign_message.email_template.save!
    Member.any_instance.stubs(:can_signin?).returns(false)
    job = CampaignManagement::UserCampaignMessageJob.find_or_initialize_by(abstract_object_id: user.id, campaign_message_id: @campaign_message.id)
    job.run_at = 5.minutes.ago
    job.save!
    job.create_personalized_message

    matching_string = "<a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/users/new_user_followup"
    assert_match(matching_string, AdminMessage.last.content) # {{url_profile_completion}}
    matching_regex = Regexp.new "<a href=\"<a href=#{matching_string}"
    assert_no_match(matching_regex, AdminMessage.last.content)

    matching_string = "<a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/contact_admin"
    assert_match(matching_string, AdminMessage.last.content) # {{url_profile_completion}}
    matching_regex = Regexp.new "<a href=\"<a href=#{matching_string}"
    assert_no_match(matching_regex, AdminMessage.last.content)
  end

  def test_check_mentoring_connection_tags
    mentor_request = mentor_requests(:mentor_request_0)
    user = mentor_request.mentor
    @campaign_message.email_template.subject = "Hello {{user_lastname}}, your profile score is {{profile_completion_score}}"
    @campaign_message.email_template.source = "Your have {{last_logged_in_on}}, from {{join_date}} but available connection slots are {{available_connection_slots}} and complete {{url_profile_completion}} please contact {{url_contact_admin}}"
    @campaign_message.email_template.save!

    Member.any_instance.stubs(:can_signin?).returns(false)
    job = CampaignManagement::UserCampaignMessageJob.find_or_initialize_by(abstract_object_id: user.id, campaign_message_id: @campaign_message.id)
    job.run_at = 5.minutes.ago
    job.save!
    job.create_personalized_message
    assert_equal "Hello name, your profile score is 59", AdminMessage.last.subject
    join_date = user.created_at.strftime("%b %d, %Y")
    assert_match(/Your have Never logged in, from #{join_date} but available connection slots are 1/, AdminMessage.last.content)
    assert_match("<a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/users/new_user_followup", AdminMessage.last.content) # {{url_profile_completion}}
    assert_match("<a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/contact_admin", AdminMessage.last.content) # {{url_contact_admin}}

    @campaign_message.email_template.source = "Your have {{last_logged_in_on}}, from {{join_date}} but available connection slots are {{available_connection_slots}} and complete {{url_profile_completion}} please contact {{url_contact_admin}}"
    @campaign_message.email_template.save!
    job = CampaignManagement::UserCampaignMessageJob.find_or_initialize_by(abstract_object_id: user.id, campaign_message_id: @campaign_message.id)
    job.run_at = 5.minutes.ago
    job.save!
    job.create_personalized_message
    assert_match("<a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/users/new_user_followup", AdminMessage.last.content)
  end

  def test_check_available_connection_slots_incase_of_non_mentor_case
    mentor_request = mentor_requests(:mentor_request_0)
    user = mentor_request.student
    @campaign_message.email_template.subject = "Hello {{user_lastname}}"
    @campaign_message.email_template.source = "Available connection slots are {{available_connection_slots}}"
    @campaign_message.email_template.save!
    job = CampaignManagement::UserCampaignMessageJob.find_or_initialize_by(abstract_object_id: user.id, campaign_message_id: @campaign_message.id)
    job.run_at = 5.minutes.ago
    job.save!
    job.create_personalized_message
    assert_equal "Hello example", AdminMessage.last.subject
    assert_equal "Available connection slots are 0<style>\n</style>", AdminMessage.last.content
  end

  def test_check_campaign_tags
    mentor_request = mentor_requests(:mentor_request_0)
    user = mentor_request.mentor
    @campaign_message.email_template.subject = "Hello {{user_name}} ({{user_role}})"
    @campaign_message.email_template.source = "Hi, use {{user_email}} and click {{url_signup}} to signup."
    @campaign_message.email_template.save!
    job = CampaignManagement::UserCampaignMessageJob.find_or_initialize_by(abstract_object_id: user.id, campaign_message_id: @campaign_message.id)
    job.run_at = 5.minutes.ago
    job.save!
    job.create_personalized_message
    assert_equal "Hello Good unique name (Mentor)", AdminMessage.last.subject
    assert_match("robert@example.com", AdminMessage.last.content)
    assert_match("<a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/users/new_user_followup", AdminMessage.last.content)
  end

  def test_create_personalized_message_should_return_true_in_case_of_success
    assert @job.create_personalized_message
  end

  def test_set_abstract_object_type
    job = CampaignManagement::UserCampaignMessageJob.create
    assert_equal User.name, job.abstract_object_type
  end

end
