require_relative './../test_helper.rb'

class OneTimeFlagTest < ActiveSupport::TestCase

  def test_validations

    one_time_flag = OneTimeFlag.new(message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG)
    assert_false one_time_flag.valid?
    assert_equal ["can't be blank"], one_time_flag.errors[:ref_obj]

    one_time_flag.message_tag = "TAG"
    assert_false one_time_flag.valid?
    assert_equal ["is not included in the list"], one_time_flag.errors[:message_tag]

    all_valid_message_tags = OneTimeFlag::Flags::TourTags.all + OneTimeFlag::Flags::Popups.all
    assert all_valid_message_tags.all? do |tag|
      one_time_flag.message_tag = tag
      one_time_flag.valid?
    end

    user = users(:f_student)
    assert_difference 'OneTimeFlag.count' do
      user.one_time_flags.create!(message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG)
    end

    assert_no_difference 'OneTimeFlag.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :message_tag, "has already been taken" do
        user.one_time_flags.create!(message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG)
      end
    end

    assert_difference 'OneTimeFlag.count' do
      user.member.one_time_flags.create!(message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG)
    end
  end

  def test_all_popups
    assert_equal_unordered [OneTimeFlag::Flags::Popups::MENTEE_GUIDANCE_POPUP_TAG, OneTimeFlag::Flags::Popups::EXPLICIT_PREFERENCE_CREATION_POPUP_TAG], OneTimeFlag::Flags::Popups.all
  end
end
