require_relative '../../test_helper'

class CampaignManagement::UserCampaignsControllerTest < ActionController::TestCase
  def test_should_require_super_user
    current_user_is :f_student
    assert_raises Authorization::PermissionDenied do
      get :index
    end
  end

  def test_index
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_template :index
    assert_instance_of CampaignManagement::CampaignPresenter, assigns(:presenter)
  end

  def test_index_js
    current_user_is :f_admin
    get :index, params: { format: :json}
    assert_response :success
    assert_instance_of CampaignManagement::CampaignPresenter, assigns(:presenter)
  end

  def test_new_not_logged_in
    current_program_is :albers
    get :new
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      get :new
    end
  end

  def test_new_not_logged_in_for_create
    current_program_is :albers

    post :create
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied_for_create
    current_user_is :f_student
    assert_permission_denied do
      post :create
    end
  end

  def test_new_not_logged_in_for_edit
    current_program_is :albers
    get :edit, params: { id: cm_campaigns(:active_campaign_1).id }
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied_for_edit
    current_user_is :f_student
    assert_permission_denied do
      get :edit, params: { id: cm_campaigns(:active_campaign_1).id }
    end
  end

  def test_new_not_logged_in_for_update
    current_program_is :albers
    put :update, params: { id: cm_campaigns(:active_campaign_1).id }
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied_for_update
    stub_program_and_render_admin_views
    current_user_is :f_student
    assert_permission_denied do
      put :update, params: { id: cm_campaigns(:active_campaign_1).id }
    end
  end

  def test_new_success
    current_user_is :f_admin
    get :new
    assert_response :success
    assert assigns(:campaign).new_record?
  end

  def test_create_failure
    current_user_is :f_admin
    params = Hash.new
    admin_view = programs(:albers).admin_views.first
    assert_no_difference "CampaignManagement::UserCampaign.count" do
      post :create, params: { :campaign_management_user_campaign => {:title => ""}, :campaign_admin_views => admin_view.id} #CM_TODO - handle multiple case
    end
    assert_response :success
    assert_equal "", assigns(:campaign).title
    params[1] = [admin_view.id]
    assert_equal params, assigns(:campaign).trigger_params
    assert_equal ["can't be blank"], assigns(:campaign).errors[:title]

    assert_no_difference "CampaignManagement::UserCampaign.count" do
      post :create, params: { :campaign_management_user_campaign => {:title => "Test Campaign"}}
    end
    assert_response :success
    assert_equal "Test Campaign", assigns(:campaign).title
    assert_equal ["can't be blank"], assigns(:campaign).errors[:trigger_params]
    assert_nil assigns(:campaign).trigger_params
  end

  def test_create_success
    current_user_is :f_admin
    params = Hash.new
    admin_view = programs(:albers).admin_views.first
    params[1] = [admin_view.id]
    assert_difference "CampaignManagement::UserCampaign.count", 1 do
      post :create, params: { :campaign_management_user_campaign => {:title => "Test Campaign"}, :campaign_admin_views => admin_view.id} #CM_TODO - handle multiple case
    end
    assert_redirected_to details_campaign_management_user_campaign_path(assigns(:campaign))
    assert_equal "Test Campaign", assigns(:campaign).title
    assert_equal params, assigns(:campaign).trigger_params
  end

  def test_edit_success
    stub_program_and_render_admin_views
    current_user_is :f_admin
    params = Hash.new
    admin_view = programs(:albers).admin_views.first
    params[1] = [(admin_view.id).to_s]
    get :edit, params: { :id => cm_campaigns(:active_campaign_1), :campaign_admin_views => admin_view.id} #CM_TODO - handle multiple case
    assert_response :success
    assert_equal cm_campaigns(:active_campaign_1), assigns(:campaign)
  end

  def test_update_failure
    stub_program_and_render_admin_views
    current_user_is :f_admin
    params = Hash.new
    admin_view = programs(:albers).admin_views.first
    params[1] = [(admin_view.id).to_s]
    put :update, params: { :id => cm_campaigns(:active_campaign_1), :campaign_admin_views => admin_view.id, :campaign_management_user_campaign => {:title => ""}} #CM_TODO - handle multiple case object
    assert_equal ["can't be blank"], assigns(:campaign).errors[:title]
    assert_false assigns(:campaign).valid?
    assert_not_nil cm_campaigns(:active_campaign_1).reload.title
  end

  def test_update_success
    stub_program_and_render_admin_views
    current_user_is :f_admin
    params = Hash.new
    admin_view = programs(:albers).admin_views.first
    params[1] = [(admin_view.id).to_s]
    assert_no_difference "CampaignManagement::UserCampaign.count" do
      put :update, params: { :id => cm_campaigns(:active_campaign_1), :campaign_admin_views => admin_view.id, :campaign_management_user_campaign => {:title => "Updated Title"}} #CM_TODO - handle multiple case object
    end
    assert assigns(:campaign).valid?
    assert_equal "Updated Title", cm_campaigns(:active_campaign_1).reload.title
  end

  def test_import_csv
    program = programs(:albers)
    current_user_is :f_admin
    login_as_super_user

    campaigns = CampaignManagement::UserCampaign.where(:program_id => program.id)
    post :import_csv, params: { campaign: {template: fixture_file_upload(File.join('files', 'campaign_management', 'campaign_model_import.csv'), 'text/csv')}}
    assert_equal "The Campaign template has been set up successfully from the template file", flash[:notice]
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name","Campaign 1", "Campaign 2", "Campaign 3"], campaigns.collect(&:title)
    campaign_ids = campaigns.pluck(:id)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
    assert_equal [7, 30, 0, 5, 10, 15, 4, 6, 0, 0, 1, 2], campaign_messages.collect(&:duration)
    campaign_message_ids = campaign_messages.pluck(:id)
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6", "Subject 1", "Subject 2"], Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
    assert_redirected_to campaign_management_user_campaigns_path

    post :import_csv, params: { campaign: {template: fixture_file_upload(File.join('files', 'campaign_management', 'incorrect_format.png'), 'text/csv')}}
    assert_equal "flash_message.campaign_management.campaign.csv_parse_error".translate, flash[:error]

    post :import_csv, params: { campaign: {template: fixture_file_upload(File.join('files', 'campaign_management', 'campaign_model_campaign_error_import.csv'), 'text/csv')}}
    assert_equal "feature.campaign.description.error_notice".translate + "Campaign 1" + ". " + "feature.campaign.description.error_notice_tip".translate, flash[:error]

    post :import_csv, params: { campaign: nil}
    assert_equal flash[:error] = "feature.campaign.description.error_file_absent".translate, flash[:error]
  end

  def test_import_csv_failure
    program = programs(:albers)
    current_user_is :f_mentor

    assert_permission_denied do
      post :import_csv
    end

    current_user_is :f_student
    assert_permission_denied do
      post :import_csv
    end

  end

  def test_export_csv
    program = programs(:albers)
    current_user_is :f_admin
    login_as_super_user

    get :export_csv
    assert_response :success

    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
  end

  def test_export_csv_failure
    program = programs(:albers)
    current_user_is :f_mentor

    assert_permission_denied do
      get :export_csv
    end

    current_user_is :f_student
    assert_permission_denied do
      get :export_csv
    end
  end

  def test_campaign_details
    stub_program_and_render_admin_views
    current_user_is :f_admin
    get :details, params: { :id => cm_campaigns(:active_campaign_1),
        :end_time => Time.gm(2004), :months => 2
      }

    total_analytics = {0=>3, 1=>2, 3=>1, 4=>2}
    assert_equal  total_analytics, assigns(:overall_analytics)
    assert_equal 5, assigns(:analytic_stats)[:total_sent_count]
  end

  def test_details_should_return_overall_analyticss_even_if_no_analytics_for_given_period
    stub_program_and_render_admin_views
    current_user_is :f_admin
    get :details, params: { :id => cm_campaigns(:active_campaign_1),
        :end_time => Time.gm(2014), :months => 2
      }

    total_analytics = {0=>3, 1=>2, 3=>1, 4=>2}
    assert_equal  total_analytics, assigns(:overall_analytics)
    assert_equal 5, assigns(:analytic_stats)[:total_sent_count]
  end

  def test_campaign_details_when_sent_count_is_zero
    stub_program_and_render_admin_views
    current_user_is :f_admin

    emails_mock = mock
    emails_mock.stubs(:where).returns([])
    emails_mock.stubs(:count).returns(0)

    CampaignManagement::UserCampaign.any_instance.stubs(:valid_emails).returns(emails_mock)
    get :details, params: { :id => cm_campaigns(:active_campaign_1),
        :end_time => Time.gm(2004), :months => 2
      }

    total_analytics = {0=>3, 1=>2, 3=>1, 4=>2}
    assert_equal  total_analytics, assigns(:overall_analytics)

    assert_equal 0, assigns(:analytic_stats)[:open_rate]
    assert_equal 0, assigns(:analytic_stats)[:click_rate]
    assert_equal 0, assigns(:analytic_stats)[:total_sent_count]
  end

  def test_disable_should_deactive_the_campaign
    current_user_is :f_admin
    get :disable, params: { :id => cm_campaigns(:active_campaign_1).id}
    assert_equal cm_campaigns(:active_campaign_1), assigns(:campaign)
    assert_equal CampaignManagement::UserCampaign::STATE::STOPPED,  assigns(:campaign).state
    assert_equal "The campaign has been stopped.", flash[:notice]
    assert_redirected_to details_campaign_management_user_campaign_path(cm_campaigns(:active_campaign_1))
  end

  def test_destroy_should_destroy_the_campaign
    current_user_is :f_admin
    assert_difference "CampaignManagement::UserCampaign.count", -1 do
      delete :destroy, params: { :id => cm_campaigns(:disabled_campaign_1).id}
    end
    assert_redirected_to campaign_management_user_campaigns_path(:state => CampaignManagement::UserCampaign::STATE::STOPPED)
  end

  def test_start_failure
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::DRAFTED, enabled_at: nil)
    assert campaign.drafted?
    current_user_is :f_student

    assert_permission_denied do
      put :start, params: { id: campaign.id}
    end
    assert_false campaign.reload.active?
  end

  def test_start_success
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::DRAFTED, enabled_at: nil)
    assert campaign.drafted?

    current_user_is :f_admin
    put :start, params: { id: campaign.id}
    assert_redirected_to details_campaign_management_user_campaign_path(campaign)
    assert campaign.reload.active?
    assert_equal html_escape("The campaign is now active. The email \"Campaign Message - Subject1\" will be sent to targeted users within couple of hours."), flash[:notice]
  end

  def test_clone_popup_failure
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    assert campaign.stopped?

    current_user_is :f_student
    assert_permission_denied do
      get :clone_popup, xhr: true, params: { id: campaign.id}
    end
  end

  def test_clone_popup_success
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    assert campaign.stopped?

    current_user_is :f_admin
    get :clone_popup, xhr: true, params: { id: campaign.id}
    assert_response :success
    assert assigns(:campaign).for_cloning
  end

  def test_clone_failure
    admin_view = programs(:albers).admin_views.first
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    assert campaign.stopped?

    current_user_is :f_student
    assert_no_difference "CampaignManagement::UserCampaign.count" do
      assert_permission_denied do
        post :clone_popup, params: { id: campaign.id, :campaign_management_user_campaign => {:title => "Test Campaign"}, :campaign_admin_views => admin_view.id}
      end
    end
  end

  def test_clone_success
    admin_view = programs(:albers).admin_views.first
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    assert campaign.stopped?
    assert_equal 4, campaign.campaign_messages.count
    current_user_is :f_admin

    assert_difference "CampaignManagement::UserCampaign.count", 1 do
      post :clone, params: { id: campaign.id, :campaign_management_user_campaign => {:title => "Test Campaign"}, :campaign_admin_views => admin_view.id}
    end

    clone = assigns(:cloned_campaign)
    assert_redirected_to details_campaign_management_user_campaign_path(clone)
    assert_equal html_escape("#{clone.title} campaign has been created successfully. The email \"Campaign Message - Subject1\" will be sent to targeted users within couple of hours."), flash[:notice]
    assert_equal CampaignManagement::UserCampaign.last.id, clone.id

    assert_equal "Test Campaign", clone.title
    assert_equal 4, clone.campaign_messages.count
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, clone.trigger_params # ensure its not ActionController::Parameters
    assert_equal_hash( { 1 => [admin_view.id] }, clone.trigger_params)
    assert clone.active?
  end

  def test_clone_draft_success
    admin_view = programs(:albers).admin_views.first
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    assert campaign.stopped?
    assert_equal 4, campaign.campaign_messages.count
    current_user_is :f_admin

    assert_difference "CampaignManagement::UserCampaign.count", 1 do
      post :clone, params: { id: campaign.id, :campaign_management_user_campaign => {:title => "Test Campaign"}, :campaign_admin_views => admin_view.id, draft: "true"}
    end

    clone = assigns(:cloned_campaign)
    assert_redirected_to details_campaign_management_user_campaign_path(clone)
    assert_equal "#{clone.title} campaign has been created successfully.", flash[:notice]
    assert_equal CampaignManagement::UserCampaign.last.id, clone.id

    assert_equal "Test Campaign", clone.title
    assert_equal 4, clone.campaign_messages.count
    params = Hash.new
    params[1] = [admin_view.id]
    assert_equal params, clone.trigger_params
    assert clone.drafted?
  end

  private

  def stub_program_and_render_admin_views
    CampaignManagement::UserCampaignsController.expects(:current_program).at_least(0).returns(programs(:albers))
    CampaignManagement::UserCampaignsController.any_instance.expects(:render_admin_views).at_least(0).returns(programs(:albers).admin_views.pluck(:title).first)
  end
end