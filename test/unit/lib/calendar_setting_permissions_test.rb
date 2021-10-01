require_relative './../../test_helper.rb'

class CalendarSettingPermissionsTest < ActiveSupport::TestCase

  def test_is_allowed_to_set_slot_availability
    user = users(:f_mentor)
    assert_false user.is_allowed_to_set_slot_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    calendar_settings(:calendar_settings_1).update_attributes!(allow_mentor_to_configure_availability_slots: true)
    assert user.reload.is_allowed_to_set_slot_availability?
  end

  def test_is_allowed_to_set_general_availability
    user = users(:f_mentor)
    assert_false user.is_allowed_to_set_general_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    assert user.reload.is_allowed_to_set_general_availability?
  end

  def test_is_allowed_to_set_all_availability
    user = users(:f_mentor)
    assert_false user.is_allowed_to_set_all_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    calendar_settings(:calendar_settings_1).update_attributes!(allow_mentor_to_configure_availability_slots: true)
    assert user.reload.is_allowed_to_set_all_availability?
  end

  def test_is_allowed_to_set_only_slot_availability
    user = users(:f_mentor)
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)

    assert_false calendar_settings(:calendar_settings_1).allow_mentor_to_configure_availability_slots
    assert calendar_settings(:calendar_settings_1).allow_mentor_to_describe_meeting_preference
    assert_false users(:f_mentor).is_allowed_to_set_only_slot_availability?

    calendar_settings(:calendar_settings_1).update_attributes!(:allow_mentor_to_configure_availability_slots => true)
    assert_false user.reload.is_allowed_to_set_only_slot_availability?

    calendar_settings(:calendar_settings_1).update_attributes!(:allow_mentor_to_describe_meeting_preference => false)
    assert user.reload.is_allowed_to_set_only_slot_availability?
  end

  def test_can_set_slot_availability
    user = users(:f_mentor)
    assert_false user.can_set_slot_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    calendar_settings(:calendar_settings_1).update_attributes!(allow_mentor_to_configure_availability_slots: true)
    assert user.reload.can_set_slot_availability?
    user = users(:f_student)
    assert_false user.can_set_slot_availability?
  end

  def test_can_set_general_availability
    user = users(:f_mentor)
    assert_false user.can_set_general_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    assert user.reload.can_set_general_availability?
    user = users(:f_student)
    assert_false user.can_set_general_availability?
  end

  def test_can_set_meeting_availability
    user = users(:f_mentor)
    assert_false user.can_set_meeting_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    assert user.reload.can_set_meeting_availability?
    user = users(:f_student)
    assert_false user.can_set_meeting_availability?
  end

  def test_is_opted_for_slot_availability
    user = users(:f_mentor)
    user.member.update_attributes!(will_set_availability_slots: true)
    assert_false user.is_opted_for_slot_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    calendar_settings(:calendar_settings_1).update_attributes!(allow_mentor_to_configure_availability_slots: true)
    assert user.reload.is_opted_for_slot_availability?
  end

  def test_is_opted_for_general_availability
    user = users(:f_mentor)
    assert_false user.is_opted_for_general_availability?
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    calendar_settings(:calendar_settings_1).update_attributes!(allow_mentor_to_configure_availability_slots: true)
    user.member.update_attributes!(will_set_availability_slots: false)
    assert user.reload.is_opted_for_general_availability?
  end


  def test_can_set_mentee_general_availability_preference
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).save!
    user = users(:f_mentor)
    user.member.update_attributes!(will_set_availability_slots: true)
    assert_false user.can_set_mentee_general_availability_preference?
    user.add_role(RoleConstants::STUDENT_NAME)
    calendar_settings(:calendar_settings_1).update_attributes!(allow_mentor_to_configure_availability_slots: true)
    assert user.can_set_mentee_general_availability_preference?
    user = users(:f_student)
    assert user.can_set_mentee_general_availability_preference?
  end
end