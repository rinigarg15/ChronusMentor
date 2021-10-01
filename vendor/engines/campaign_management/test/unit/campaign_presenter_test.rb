require_relative './../test_helper'

class CampaignPresenterTest < ActiveSupport::TestCase
  def setup
    super
    @program = programs(:albers)
    @tour_taken = true
    # active_campaign_2 & active_campaign_1 are being created from the observers. Eariler the test cases were written based on fixtures for which we controlled created_at time.
    # The disabled campaigns which are populated from fixtures anyways have created_at times set to 2000
    cm_campaigns(:active_campaign_2).update_attributes(:created_at => cm_campaigns(:active_campaign_1).created_at+10)
  end

  def test_target_state_with_tour_taken
    params = ActionController::Parameters.new(state: CampaignManagement::AbstractCampaign::STATE::ACTIVE)
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    assert_equal CampaignManagement::AbstractCampaign::STATE::ACTIVE, presenter.target_state
  end

  def test_target_state_with_tour_not_taken
    params = ActionController::Parameters.new(state: CampaignManagement::AbstractCampaign::STATE::ACTIVE)
    @tour_taken = false
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    assert_equal CampaignManagement::AbstractCampaign::STATE::DRAFTED, presenter.target_state
  end

  def test_list_without_state
    cm_campaigns(:active_campaign_1).update_attributes!(enabled_at: cm_campaigns(:active_campaign_1).enabled_at - 1.minute)
    presenter = CampaignManagement::CampaignPresenter.new(@program, ActionController::Parameters.new, @tour_taken)

    expected_campaigns = [
      cm_campaigns(:active_campaign_2),
      cm_campaigns(:active_campaign_1)
    ]

    analytics_stub = {
      CampaignManagement::EmailEventLog::Type::CLICKED => 5,
      CampaignManagement::EmailEventLog::Type::OPENED => 4,
      CampaignManagement::EmailEventLog::Type::DELIVERED => 10
    }

    CampaignManagement::UserCampaign.any_instance.expects(:calculate_overall_analytics).
      times(expected_campaigns.size).returns(analytics_stub)

    admin_message_stub_array = Array.new(10)
    AdminMessage.stubs(:where).times(expected_campaigns.size).returns(admin_message_stub_array)

    list = presenter.list

    assert_equal expected_campaigns.map(&:title), list.map(&:title)
    assert_equal 0.5, list[0].click_rate
    assert_equal 0.4, list[0].open_rate
    assert_equal 10, list[0].total_sent
  end

  def test_list_with_title_sorting
    #sort descending order
    params = ActionController::Parameters.new(sort: { 0 => { field: :title, dir: :desc } }, state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    list = presenter.list

    expected_campaigns = [
      cm_campaigns(:disabled_campaign_4),
      cm_campaigns(:disabled_campaign_3),
      cm_campaigns(:disabled_campaign_2),
      cm_campaigns(:disabled_campaign_1)
    ]
    assert_equal expected_campaigns.map(&:title), list.map(&:title)

    #sort ascending order
    params = ActionController::Parameters.new(sort: { 0 => { field: :title, dir: :asc } }, state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    list = presenter.list

    expected_campaigns = [
      cm_campaigns(:disabled_campaign_1),
      cm_campaigns(:disabled_campaign_2),
      cm_campaigns(:disabled_campaign_3),
      cm_campaigns(:disabled_campaign_4)
    ]
    assert_equal expected_campaigns.map(&:title), list.map(&:title)
  end

  def test_list_disabled
    params = ActionController::Parameters.new(state: CampaignManagement::AbstractCampaign::STATE::STOPPED)

    expected_campaigns = [
      cm_campaigns(:disabled_campaign_1),
      cm_campaigns(:disabled_campaign_2),
      cm_campaigns(:disabled_campaign_3),
      cm_campaigns(:disabled_campaign_4)
    ]

    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    list = presenter.list
    assert_equal_unordered expected_campaigns.map(&:title), list.map(&:title)
  end

  def test_list_with_click_rate_sorting
    analytics_stub_1 = {
        CampaignManagement::EmailEventLog::Type::CLICKED => 5,
        CampaignManagement::EmailEventLog::Type::DELIVERED => 10
      }
    analytics_stub_2 = {
        CampaignManagement::EmailEventLog::Type::CLICKED => 6,
        CampaignManagement::EmailEventLog::Type::DELIVERED => 10
      }
    analytics_stub_3 = {
        CampaignManagement::EmailEventLog::Type::CLICKED => 4,
        CampaignManagement::EmailEventLog::Type::DELIVERED => 10
      }
    analytics_stub_4 = {
        CampaignManagement::EmailEventLog::Type::CLICKED => 2,
        CampaignManagement::EmailEventLog::Type::DELIVERED => 10
      }

    expected_campaigns = [
      cm_campaigns(:disabled_campaign_1),
      cm_campaigns(:disabled_campaign_2),
      cm_campaigns(:disabled_campaign_3),
      cm_campaigns(:disabled_campaign_4)
    ]

    CampaignManagement::UserCampaign.any_instance.stubs(:calculate_overall_analytics).
      times(expected_campaigns.size).returns(analytics_stub_1, analytics_stub_2, analytics_stub_3, analytics_stub_4)

    admin_message_stub_array = Array.new(10)
    AdminMessage.stubs(:where).times(expected_campaigns.size).returns(admin_message_stub_array)

    params = ActionController::Parameters.new(sort: { 0 => { field: :click_rate, dir: :desc } }, state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    list = presenter.list

    assert_equal_unordered expected_campaigns.map(&:title), list.map(&:title)
  end

  def test_find_total_active_and_disabled_campaigns_count
    campaign = cm_campaigns(:active_campaign_1)
    params = ActionController::Parameters.new(id: campaign.id)
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)

    assert_equal campaign, presenter.find
    assert_equal 8, presenter.total
    assert_equal 2, presenter.active
    assert_equal 4, presenter.disabled
    assert_equal 2, presenter.drafted

    disabled_cm = cm_campaigns(:disabled_campaign_4)
    disabled_cm.update_attributes(state: CampaignManagement::AbstractCampaign::STATE::DRAFTED)

    presenter = CampaignManagement::CampaignPresenter.new(@program.reload, params, @tour_taken)
    assert_equal 3, presenter.disabled
    assert_equal 3, presenter.drafted
  end

  def test_list_when_sort_by_db_field
    stopped_campaigns = [
      cm_campaigns(:disabled_campaign_4),
      cm_campaigns(:disabled_campaign_3),
      cm_campaigns(:disabled_campaign_2),
      cm_campaigns(:disabled_campaign_1)
    ]

    params = ActionController::Parameters.new(sort: { 0 => { field: :id, dir: :desc } }, state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    assert_equal stopped_campaigns, presenter.list

    params = ActionController::Parameters.new(sort: { 0 => { field: :id, dir: :asc } }, state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
    presenter = CampaignManagement::CampaignPresenter.new(@program, params, @tour_taken)
    assert_equal stopped_campaigns.reverse, presenter.list
  end
end