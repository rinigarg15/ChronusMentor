require_relative './../test_helper.rb'

class CalendarSettingTest < ActiveSupport::TestCase

  def test_validations
    c = CalendarSetting.new(:advance_booking_time => "", :max_meetings_for_mentee => "-2")
    assert_false c.valid?

    assert_equal(["can't be blank"], c.errors[:program])
    assert_equal(["can't be blank", "is not included in the list"], c.errors[:slot_time_in_minutes])
    assert_equal(["can't be blank","should be positive"], c.errors[:advance_booking_time])
    assert_equal(["must be greater than or equal to 0"], c.errors[:max_meetings_for_mentee])
  end

  def test_availability_validation
    c = programs(:albers).calendar_setting
    assert c.valid?
    c.allow_mentor_to_describe_meeting_preference = false
    c.allow_mentor_to_configure_availability_slots = false
    assert_false c.valid?
    assert_equal(["Allow Mentor either to configure availability slots or to describe the Meeting preference"], c.errors[:base])

    c.allow_mentor_to_describe_meeting_preference = true
    assert c.valid?

    c.allow_mentor_to_configure_availability_slots = true
    c.allow_mentor_to_describe_meeting_preference = false
    assert c.valid?
  end

  def test_allow_mentor_to_set_all_availability
    c = programs(:albers).calendar_setting
    c.allow_mentor_to_describe_meeting_preference = true
    c.allow_mentor_to_configure_availability_slots = true
    assert c.allow_mentor_to_set_all_availability?
  end

  def test_association
    c = programs(:albers).calendar_setting
    assert_equal c.program, programs(:albers)
  end

  def test_create_calendar_settings
    program = programs(:nch_mentoring)
    program.enable_feature(FeatureName::CALENDAR)
    program.calendar_setting.destroy
    program.reload

    portal = programs(:primary_portal)

    assert_nil program.calendar_setting
    assert_nil portal.calendar_setting

    CalendarSetting.create_default_calendar_setting
    program.reload
    assert program.calendar_setting.present?
    assert_nil portal.calendar_setting
  end

end
