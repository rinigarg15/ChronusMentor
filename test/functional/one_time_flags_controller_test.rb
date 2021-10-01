require_relative './../test_helper.rb'

class OneTimeFlagsControllerTest < ActionController::TestCase

  def setup
    super
    current_program_is :albers
  end

  def test_create
    current_user_is :f_admin

    assert_difference 'OneTimeFlag.count' do
      post :create, xhr: true, params: { :TAG => OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG}
    end

    assert_no_difference 'OneTimeFlag.count' do
      post :create, xhr: true, params: { :TAG => OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG}
    end
  end

  def test_create_for_mentor
    current_user_is :f_mentor

    assert_difference 'OneTimeFlag.count' do
      post :create, xhr: true, params: { :TAG => OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG}
    end
  end

end
