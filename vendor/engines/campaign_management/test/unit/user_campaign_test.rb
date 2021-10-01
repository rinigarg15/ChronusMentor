require_relative './../test_helper'

class UserCampaignTest < ActiveSupport::TestCase
  def test_presence_of_state_n_program
    campaign = CampaignManagement::UserCampaign.new(:state => nil)
    campaign.save
    assert_equal ["can't be blank", "is not included in the list"], campaign.errors[:state]
  end

  def test_presence_of_state_in_the_list
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: 10)
    assert_equal ["is not included in the list"], campaign.errors[:state]
  end

  def test_state_change
    campaign = cm_campaigns(:active_campaign_1)
    assert campaign.campaign_messages.present?
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    assert_equal [], campaign.errors[:state]

    campaign = cm_campaigns(:active_campaign_2)
    campaign.campaign_messages.delete_all
    assert campaign.valid?
    assert_equal [], campaign.errors[:state]
  end

  def test_check_state
    campaign = cm_campaigns(:active_campaign_1)
    campaign.state = CampaignManagement::AbstractCampaign::STATE::STOPPED
    campaign.save!
    assert campaign.stopped?
  end

  def test_belongs_to_program
    assert_equal programs(:albers), cm_campaigns(:active_campaign_1).program
  end

  def test_email_template_association
    campaign = cm_campaigns(:cm_campaigns_1)
    assert_equal_unordered campaign.campaign_messages.collect(&:email_template), campaign.email_templates
  end

  def test_all_admin_view_ids
    campaign = cm_campaigns(:active_campaign_1)

    campaign.trigger_params = {
      t1: [1, 2],
      t2: [3, 1]
    }

    assert_arrays_equal [1, 2, 3], campaign.all_admin_view_ids
  end

  def test_all_admin_views
    campaign = cm_campaigns(:active_campaign_1)
    test_view = programs(:albers).admin_views.first
    campaign.trigger_params = { t1: [test_view.id] }

    assert_arrays_equal [test_view], campaign.all_admin_views
  end

  def test_campaign_email_tags_should_return_available_email_tags
    program = programs(:albers)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false program.calendar_enabled?
    campaign = program.user_campaigns.first
    all_tags = campaign.campaign_email_tags
    assert_equal 12, all_tags.count
    assert_equal_unordered ["user_firstname", "user_lastname", "user_name", "user_email", "user_role", "url_signup", "url_contact_admin", "profile_completion_score", "url_profile_completion", "last_logged_in_on", "join_date", "available_connection_slots"], all_tags.keys.collect(&:to_s)

    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(true)
    assert_false program.calendar_enabled?
    campaign.reload
    all_tags = campaign.campaign_email_tags
    assert_equal 16, all_tags.count
    assert_equal_unordered ["user_firstname", "user_lastname", "user_name", "user_email", "user_role", "url_signup", "url_contact_admin", "profile_completion_score", "url_profile_completion", "last_logged_in_on", "join_date", "available_connection_slots",  "number_of_pending_mentor_requests", "mentor_request_acceptance_rate", "mentor_request_average_response_time", "recommended_mentors"], all_tags.keys.collect(&:to_s)


    programs(:albers).enable_feature(FeatureName::CALENDAR)
    assert program.calendar_enabled?
    campaign.reload
    all_tags = campaign.campaign_email_tags
    assert_equal 19, all_tags.count
    assert_equal_unordered ["user_firstname", "user_lastname", "user_name", "user_email", "user_role", "url_signup", "url_contact_admin", "profile_completion_score", "url_profile_completion", "last_logged_in_on", "join_date", "available_connection_slots",  "number_of_pending_mentor_requests", "mentor_request_acceptance_rate", "mentor_request_average_response_time", "recommended_mentors", "number_of_pending_meeting_requests", "meeting_request_acceptance_rate", "meeting_request_average_response_time"], all_tags.keys.collect(&:to_s)
  end

  def test_clone
    campaign = cm_campaigns(:active_campaign_1)
    clone = CampaignManagement::UserCampaign.clone(campaign, title: "Something", trigger_params: campaign.trigger_params, state: CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    assert clone.drafted?
    assert_equal "Something", clone.title
    assert_equal campaign.trigger_params, clone.trigger_params
    expected_content = campaign.campaign_messages.includes(:email_template).collect{|cm| [cm.sender_id, cm.duration, cm.email_template.source, cm.email_template.subject]}
    cloned_conent = clone.campaign_messages.includes(:email_template).collect{|cm| [cm.sender_id, cm.duration, cm.email_template.source, cm.email_template.subject]}
    assert_equal expected_content, cloned_conent
  end

  def test_process_should_call_cleanup_create_and_fix_inconsistencies
    CampaignManagement::UserCampaign.any_instance.expects(:cleanup_jobs_for_object_ids).once
    CampaignManagement::UserCampaign.any_instance.expects(:create_campaign_message_jobs).once
    CampaignManagement::UserCampaign.any_instance.expects(:fix_inconsistencies).once
    campaign = cm_campaigns(:active_campaign_1)
    campaign.process!
  end

  def test_user_ids
    campaign = cm_campaigns(:active_campaign_1)
    program = campaign.program

    abstract_views = 3.times.map { |i| mock(id: i + 1) }
    abstract_views[0].stubs(:generate_view).returns([1, 2])
    abstract_views[1].stubs(:generate_view).returns([3, 4])
    abstract_views[2].stubs(:generate_view).returns([2, 3])

    campaign.trigger_params = {
      t1: [1, 2],
      t2: [3]
    }

    program.abstract_views.stubs(:where).returns(abstract_views[0,2]).then.returns(abstract_views[2,1])

    assert_equal [2, 3], campaign.get_current_object_ids # ([1,2] | [3,4]) & [2,3]
  end

  def test_fix_inconsistencies_should_create_jobs_for_new_created_campaign_messages

    campaign = cm_campaigns(:active_campaign_1)
    email_template = Mailer::Template.new(:program_id => programs(:albers).id, source: "Test", subject: "Test")
    email_template.belongs_to_cm = true
    cm = CampaignManagement::UserCampaignMessage.new(:sender_id => nil, :duration => 5, :email_template => email_template)
    cm.campaign_id = campaign.id
    cm.save!
    
    assert_equal 8, campaign.jobs.count

    CampaignManagement::UserCampaign.any_instance.expects(:get_current_object_ids).twice.returns([users(:f_student).id, users(:f_admin).id])
    users(:f_student).created_at = Time.zone.now
    users(:f_admin).created_at = Time.zone.now

    
    assert_difference "CampaignManagement::UserCampaignMessageJob.count", 2 do
      campaign.process!
    end
    
    assert_equal 10, campaign.jobs.count
  end

end