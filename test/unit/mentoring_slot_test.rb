require_relative './../test_helper.rb'

class MentoringSlotTest < ActiveSupport::TestCase

  def test_validations
    m = MentoringSlot.new
    assert_false m.valid?
    assert_equal [m.errors[:end_time], m.errors[:start_time], m.errors[:repeats]], [["can't be blank"]]*3
    m.repeats = MentoringSlot::Repeats::WEEKLY
    assert_false m.valid?
    assert_equal [m.errors[:end_time], m.errors[:start_time], m.errors[:repeats_on_week], m.errors[:repeats_by_month_date]], [["can't be blank"], ["can't be blank"], ["can't be blank"], []]
    m.repeats = MentoringSlot::Repeats::MONTHLY
    m.repeats_by_month_date = nil
    assert_false m.valid?
    assert_equal [m.errors[:end_time], m.errors[:start_time], m.errors[:repeats_by_month_date], m.errors[:repeats_on_week]], [["can't be blank"], ["can't be blank"], ["is not included in the list"], []]
    m.repeats_by_month_date = false
    assert_false m.valid?
    assert_equal [m.errors[:end_time], m.errors[:start_time], m.errors[:repeats_by_month_date], m.errors[:repeats_on_week]], [["can't be blank"], ["can't be blank"], [], []]
  end

  def test_check_start_time_should_be_lesser
    m = create_mentoring_slot
    m.update_attributes(:start_time => 20.minutes.since, :end_time => 10.minutes.since)
    assert_false m.valid?
    assert_equal ["starting time should be before ending time"], m.errors[:start_time]
  end

  def test_check_repeats_end_date
    m = mentoring_slots(:f_mentor)
    m.update_attributes(:start_time => "2025-02-26 10:00:00", :end_time => "2025-02-26 12:00:00", :repeats_end_date => "2025-02-26 00:00:00", :repeats => MentoringSlot::Repeats::WEEKLY, :repeats_on_week => "6")
    assert_false m.valid?
    assert_equal ["repeat date should be after start date"], m.errors[:repeats_end_date]
    m.update_attributes(:start_time => "2025-02-26 10:00:00", :end_time => "2025-02-26 12:00:00", :repeats_end_date => "2025-02-25 00:00:00", :repeats => MentoringSlot::Repeats::WEEKLY, :repeats_on_week => "5")
    assert_false m.valid?
    assert_equal ["repeat date should be after start date"], m.errors[:repeats_end_date]
    m.update_attributes(:start_time => "2025-02-26 10:00:00", :end_time => "2025-02-26 12:00:00", :repeats_end_date => "2025-02-27 00:00:00", :repeats => MentoringSlot::Repeats::WEEKLY, :repeats_on_week => "0")
    assert m.valid?
  end

  def test_remove_slots_smaller_than_calendar_slot_time
    slot1 = {:start => "2025-02-26 10:00:00", :end => "2025-02-26 10:30:00"}
    slot2 = {:start => "2025-02-26 10:00:00", :end => "2025-02-26 10:20:00"}
    slot3 = {:start => "2025-02-26 10:00:00", :end => "2025-02-26 11:00:00"}

    slots = [slot1, slot2, slot3]

    program = programs(:albers)

    assert_equal 30, program.get_calendar_slot_time

    assert_equal_unordered [slot1, slot3], MentoringSlot.remove_slots_smaller_than_calendar_slot_time(slots, program)
    
    program.calendar_setting.update_attribute(:slot_time_in_minutes, 0)

    assert_equal_unordered [slot1, slot3], MentoringSlot.remove_slots_smaller_than_calendar_slot_time(slots, program)

    program.calendar_setting.update_attribute(:slot_time_in_minutes, 60)

    assert_equal_unordered [slot3], MentoringSlot.remove_slots_smaller_than_calendar_slot_time(slots, program)
  end

  def test_recurrent
    m = mentoring_slots(:f_mentor)
    assert_false m.recurrent?
    m.update_attributes(:repeats => MentoringSlot::Repeats::DAILY)
    assert m.recurrent?
    m.update_attributes(:repeats => nil)
  end

  def test_repeats_every_option_getter
    m = mentoring_slots(:f_mentor)
    assert_equal m.repeats, MentoringSlot::Repeats::NONE
    assert_equal m.repeats_every_option, 0
    m.update_attributes(:repeats => MentoringSlot::Repeats::WEEKLY, :repeats_on_week => "6")
    assert_equal m.reload.repeats_every_option, 2
    m.update_attributes(:repeats => MentoringSlot::Repeats::MONTHLY)
    assert_equal m.reload.repeats_every_option, 3
  end

  def test_repeats_every_option_setter
    m = mentoring_slots(:f_mentor)
    m.repeats_every_option = 0
    assert_equal m.repeats, MentoringSlot::Repeats::NONE
    m.repeats_every_option = 1
    assert_equal m.repeats, MentoringSlot::Repeats::DAILY
    m.repeats_every_option = 2
    assert_equal m.repeats, MentoringSlot::Repeats::WEEKLY
    m.repeats_every_option = 3
    assert_equal m.repeats, MentoringSlot::Repeats::MONTHLY
  end

  def test_fetch_start_and_end_time
    t = MentoringSlot.fetch_start_and_end_time("February 18, 2011", "05:30 am", "07:00 pm")
    assert_equal t[0].strftime("%Y-%m-%d %T"), "2011-02-18 05:30:00"
    assert_equal t[1].strftime("%Y-%m-%d %T"), "2011-02-18 19:00:00"
    
    t = MentoringSlot.fetch_start_and_end_time("February 18, 2011", "05:30 am", "12:00 am")
    assert_equal t[0].strftime("%Y-%m-%d %T"), "2011-02-18 05:30:00"
    assert_equal t[1].strftime("%Y-%m-%d %T"), "2011-02-19 00:00:00"
    
    t = MentoringSlot.fetch_start_and_end_time("January 31, 2011", "12:30 am", "12:00 am")
    assert_equal t[0].strftime("%Y-%m-%d %T"), "2011-01-31 00:30:00"
    assert_equal t[1].strftime("%Y-%m-%d %T"), "2011-02-01 00:00:00"
  end

  def test_repeats_end_date_view_getter_setter
    mentoring_slots(:f_mentor).update_attributes(:start_time => "2025-03-01 17:00:00", :end_time => "2025-03-01 19:00:00")
    mentoring_slots(:f_mentor).reload.update_attributes(:repeats_end_date => "2025-03-06")
    assert_nil mentoring_slots(:f_mentor).reload.repeats_end_date_view
    mentoring_slots(:f_mentor).reload.update_attributes(:repeats_end_date => "2025-03-06",:repeats => MentoringSlot::Repeats::WEEKLY, :repeats_on_week => "6")
    assert_equal mentoring_slots(:f_mentor).reload.repeats_end_date_view, "March 05, 2025"
    mentoring_slots(:f_mentor).reload.repeats_end_date_view = "March 06, 2025"
    assert_time_string_equal mentoring_slots(:f_mentor).repeats_end_date, "2025-03-07 00:00:00".to_date
  end

  def test_repeats_end_date
    Time.zone = "Asia/Kolkata"
    mentoring_slots(:f_mentor).update_attributes(:start_time => "2025-03-01 17:00:00", :end_time => "2025-03-01 19:00:00")
    mentoring_slots(:f_mentor).reload.update_attributes(:repeats_end_date => "2025-03-06",:repeats => MentoringSlot::Repeats::WEEKLY, :repeats_on_week => "0")
    assert_time_string_equal mentoring_slots(:f_mentor).reload.repeats_end_date, "2025-03-06 00:00:00".to_time
  end

  def test_sort_slots
    member = members(:f_mentor)
    assert_equal 1, member.mentoring_slots.size
    slot1 = member.mentoring_slots.first    
    slot_start_time = Time.now + 2.days
    slot_end_time = slot_start_time + 2.hours
    slot1.update_attributes!(:start_time => slot_start_time, :end_time => slot_end_time, :location => "Cafeteria")
    slot2 = create_mentoring_slot(:member => member, :location => "Bangalore",
      :start_time => slot_start_time - 1.day, :end_time => (slot_start_time - 1.day) + 2.hours,
      :repeats => MentoringSlot::Repeats::NONE, :repeats_on_week => nil)
    slot1hash = slot1.get_json_objects("#{member.name} available at #{slot1.location}", slot1.location, false, nil, false, false)
    slot2hash = slot2.get_json_objects("#{member.name} available at #{slot2.location}", slot2.location, false, nil, false, false)
    assert_false slot1hash[:member].present?
    mentoring_slots = member.get_mentoring_slots(slot_start_time - 5.days, slot_start_time + 5.days)
    assert_mentoring_slots [slot1hash, slot2hash], mentoring_slots
    MentoringSlot.sort_slots!(mentoring_slots)
    assert_mentoring_slots [slot2hash, slot1hash], mentoring_slots
    # Test to see if member object directly loads in the hash key
    slot1hash = slot1.get_json_objects("#{member.name} available at #{slot1.location}", slot1.location, false, nil, false, false, nil, true)
    assert slot1hash[:member].present?
    assert_equal slot1hash[:member], slot1.member
  end

  def test_scopes
    member = members(:f_mentor)
    assert_equal 1, member.mentoring_slots.size
    slot1 = member.mentoring_slots.first
    assert_equal [], member.mentoring_slots.recurring
    assert_equal [slot1], member.mentoring_slots.non_recurring

    start_time = 1.month.ago
    end_time = 1.month.from_now
    slot1.start_time = start_time+1.day
    slot1.end_time = end_time-1.day
    slot1.save!
    
    assert_equal [], member.mentoring_slots.recurring.between_time(start_time, end_time)
    assert_equal [slot1], member.mentoring_slots.non_recurring.between_time(start_time, end_time)
    assert_equal [], member.mentoring_slots.recurring.recurring_between_time(start_time, end_time)

    slot1.repeats = MentoringSlot::Repeats::DAILY    
    slot1.save!

    assert_equal [slot1], member.mentoring_slots.recurring.between_time(start_time, end_time)
    assert_equal [], member.mentoring_slots.non_recurring.between_time(start_time, end_time)
    assert_equal [slot1], member.mentoring_slots.recurring.recurring_between_time(end_time)
  end

  def test_generate_slot_hashes
    member = members(:f_mentor)
    program = programs(:albers)
    user = member.user_in_program(program)

    non_recurring_slots_hash_initial, recurring_slots_hash_initial = MentoringSlot.generate_slot_hashes(program, {:current_time=>Time.now, :two_months_ago=>Time.now-2.months, :one_month_ago=>Time.now-1.month, :one_month_from_now=>Time.now+1.month})

    assert_equal 1, member.mentoring_slots.size
    slot1 = member.mentoring_slots.first
    assert_equal [], member.mentoring_slots.recurring
    assert_equal [slot1], member.mentoring_slots.non_recurring

    start_time = 1.month.ago
    end_time = 1.month.from_now
    slot1.start_time = start_time+1.day
    slot1.end_time = end_time-1.day
    slot1.save!

    slot1.repeats = MentoringSlot::Repeats::DAILY    
    slot1.save!

    non_recurring_slots_hash_both_mode, recurring_slots_hash_both_mode = MentoringSlot.generate_slot_hashes(program, {:current_time=>Time.now, :two_months_ago=>Time.now-2.months, :one_month_ago=>Time.now-1.month, :one_month_from_now=>Time.now+1.month})

    user.mentoring_mode = 1
    user.save!
    non_recurring_slots_hash_ongoing_mode, recurring_slots_hash_ongoing_mode = MentoringSlot.generate_slot_hashes(program, {:current_time=>Time.now, :two_months_ago=>Time.now-2.months, :one_month_ago=>Time.now-1.month, :one_month_from_now=>Time.now+1.month})
    
    user.mentoring_mode = 2
    user.save!
    
    non_recurring_slots_hash_one_time_mode, recurring_slots_hash_one_time_mode = MentoringSlot.generate_slot_hashes(program, {:current_time=>Time.now, :two_months_ago=>Time.now-2.months, :one_month_ago=>Time.now-1.month, :one_month_from_now=>Time.now+1.month})

    assert_not_equal recurring_slots_hash_initial, recurring_slots_hash_both_mode
    assert_not_equal recurring_slots_hash_ongoing_mode, recurring_slots_hash_one_time_mode
    assert_equal recurring_slots_hash_both_mode, recurring_slots_hash_one_time_mode
    assert_not_equal recurring_slots_hash_ongoing_mode, recurring_slots_hash_both_mode
  end

  def test_generate_slot_hashes_with_one_member
    member = members(:f_mentor)
    program = programs(:albers)
    user = member.user_in_program(program)

    time_intervals_hash = {:current_time=>Time.now, :two_months_ago=>Time.now-2.months, :one_month_ago=>Time.now-1.month, :one_month_from_now=>Time.now+1.month}
    MentoringSlot.expects(:generate_hash).with(program.mentoring_slots.non_recurring.where({:member_id => [member.id]}), time_intervals_hash)
    MentoringSlot.generate_slot_hashes(program, member, time_intervals_hash)
  end

  def test_rotate_repeats_on_week
    repeats_on_week = [0,6]
    res = MentoringSlot.rotate_repeats_on_week(repeats_on_week, -1)
    assert_equal [6,5], res
    repeats_on_week = [2,3,4]
    res = MentoringSlot.rotate_repeats_on_week(repeats_on_week, 2)
    assert_equal [4,5,6], res
  end

  def test_get_json_objects
    Timecop.freeze
    member = members(:f_mentor)
    slot = member.mentoring_slots.first
    start_time = DateTime.localize(slot.start_time, format: :full_date_full_time_utc)
    end_time = DateTime.localize(slot.end_time, format: :full_date_full_time_utc)

    output = {title: "test slot", allDay: false, repeats: 0, dbId: 1, eventMemberId: 3, location: "Conference room", new_meeting_params: {location: "Conference room", mentor_id: 3}, editable: false, start: start_time, end: end_time, clickable: false}
    assert_equal output, slot.get_json_objects("test slot", "Conference room", false, nil, false, false, nil, false, {})

    recurring_options = {starts: start_time, until: end_time, every: :month, on: 21}
    output = {title: "test slot", allDay: false, repeats: 0, dbId: 1, eventMemberId: 3, location: "Conference room", new_meeting_params: {location: "Conference room", mentor_id: 3}, editable: false, recurring_options: recurring_options, start: start_time, end: end_time, clickable: false}
    assert_equal output, slot.get_json_objects("test slot", "Conference room", false, nil, false, false, nil, false, recurring_options)

    slot.start_time = Date.tomorrow.beginning_of_day
    slot.end_time = Date.tomorrow.end_of_day
    output = {title: "test slot", allDay: false, repeats: 0, dbId: 1, eventMemberId: 3, location: "Conference room", new_meeting_params: {location: "Conference room", mentor_id: 3}, editable: false, start: DateTime.localize(slot.start_time, format: :full_date_full_time_utc), end: DateTime.localize(slot.end_time, format: :full_date_full_time_utc), clickable: false}
    assert_equal output, slot.get_json_objects("test slot", "Conference room", false, nil, false, false, nil, false, check_for_expired_availability: true)

    slot.start_time = Date.yesterday.beginning_of_day
    slot.end_time = Date.yesterday.end_of_day
    output = {title: "test slot", allDay: false, repeats: 0, dbId: 1, eventMemberId: 3, location: "Conference room", new_meeting_params: {location: "Conference room", mentor_id: 3}, editable: false, start: DateTime.localize(slot.start_time, format: :full_date_full_time_utc), end: DateTime.localize(slot.end_time, format: :full_date_full_time_utc), clickable: true, className: "expired_availability_slots"}
    assert_equal output, slot.get_json_objects("test slot", "Conference room", false, nil, false, false, nil, false, check_for_expired_availability: true)

    recurring_options = {starts: DateTime.localize(slot.start_time, format: :full_date_full_time_utc), until: DateTime.localize(slot.end_time, format: :full_date_full_time_utc), every: :month, on: 21, check_for_expired_availability: true}
    output = {title: "test slot", allDay: false, repeats: 0, dbId: 1, eventMemberId: 3, location: "Conference room", new_meeting_params: {location: "Conference room", mentor_id: 3}, editable: false, recurring_options: recurring_options, start: DateTime.localize(slot.start_time, format: :full_date_full_time_utc), end: DateTime.localize(slot.end_time, format: :full_date_full_time_utc), clickable: true, className: "expired_availability_slots"}
    assert_equal output, slot.get_json_objects("test slot", "Conference room", false, nil, false, false, nil, false, recurring_options)
  end
end
