require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/mentoring_slots_helper"

class MentoringSlotsHelperTest < ActionView::TestCase

  def test_location_text
    mentoring_slots(:f_mentor).update_attribute(:location, "")
    assert_equal location_text(mentoring_slots(:f_mentor)), "-"
    mentoring_slots(:f_mentor).update_attribute(:location, "HSB")
    assert_match /HSB/, location_text(mentoring_slots(:f_mentor))
  end

  def test_get_calendar_slot_popup_header
    output = get_calendar_slot_popup_header(true, true)
    set_response_text(output)
    assert_select "div.inner_tabs" do
      assert_select "li", count: 2
      assert_select "li.active", count: 1
      assert_select "li.active" do
        assert_select "a[href='#availability_slot_form_container'][data-toggle='tab']", text: "Availability Slot"
      end
      assert_select "li" do
        assert_select "a[href='#meeting_form_container'][data-toggle='tab']", text: "Create a Meeting"
      end
    end
    output = get_calendar_slot_popup_header(true, false)
    assert_match /Create a Meeting/, output
    assert_no_match(/Availability Slot/, output)
    output = get_calendar_slot_popup_header(false, true)
    assert_match /Availability Slot/, output
    assert_no_match(/Create a Meeting/, output)

    output = get_calendar_slot_popup_header(true, true, {from_settings_page: true})
    assert_no_match /Create a Meeting/, output
    assert_match(/Availability Slot/, output)
  end

  def _meeting
    "meeting"
  end

  def _Meeting
    "Meeting"
  end

  def test_get_recurring_mentoring_slot_display_text
    start_time = Date.new(2016,11,15)
    end_time = Date.new(2016,11,29)
    recurring_slot_end_time = Date.new(2016,12,17)

    #repeats daily
    slot_options = {:repeats => 1, :recurring_options=>{:starts=> start_time, :until=> end_time, :recurring_slot_end_time=> recurring_slot_end_time, :every=>:week}}
    assert_equal "Repeats daily until Dec 17, 2016", get_recurring_mentoring_slot_display_text(slot_options)
    slot_options = {:repeats => 1, :recurring_options=>{:starts=> start_time, :until=> end_time, :every=>:week}}
    assert_equal "Repeats daily", get_recurring_mentoring_slot_display_text(slot_options)

    #repeats weekly
    slot_options = {:repeats => 2, :recurring_options=>{:starts=> start_time, :until=> end_time, :recurring_slot_end_time=> recurring_slot_end_time, :every=>:week, :on=>[:sunday, :saturday]}}
    get_recurring_mentoring_slot_display_text(slot_options)
    assert_equal "Repeats every week on Su, Sa until Dec 17, 2016", get_recurring_mentoring_slot_display_text(slot_options)
    slot_options = {:repeats => 2, :recurring_options=>{:starts=> start_time, :until=> end_time, :every=>:week, :on=>[:sunday, :saturday]}}
    assert_equal "Repeats every week on Su, Sa", get_recurring_mentoring_slot_display_text(slot_options)

    #repeats monthly
    slot_options = {:repeats => 3, :recurring_options=>{:starts=> start_time, :until=> end_time, :recurring_slot_end_time=> recurring_slot_end_time, :every=>:month, :weekday=>:tuesday, :on=>:third}}
    assert_equal "Repeats every month on 3rd Tuesday until Dec 17, 2016", get_recurring_mentoring_slot_display_text(slot_options)
    slot_options = {:repeats => 3, :recurring_options=>{:starts=> start_time, :until=> end_time, :every=>:month, :weekday=>:tuesday, :on=>:third}}
    assert_equal "Repeats every month on 3rd Tuesday", get_recurring_mentoring_slot_display_text(slot_options)

    slot_options = {:repeats => 3, :recurring_options=>{:starts=> start_time, :until=> end_time, :recurring_slot_end_time=> recurring_slot_end_time, :every=>:month, :on=> 21}}
    assert_equal "Repeats every month on 21st until Dec 17, 2016", get_recurring_mentoring_slot_display_text(slot_options)
    slot_options = {:repeats => 3, :recurring_options=>{:starts=> start_time, :until=> end_time, :every=>:month, :on=> 21}}
    assert_equal "Repeats every month on 21st", get_recurring_mentoring_slot_display_text(slot_options)
  end

  def test_get_day_opts_for_mentoring_slot
    mentoring_slot = mentoring_slots(:f_mentor)
    assert_equal [mentoring_slot.start_time.wday.to_s], get_day_opts_for_mentoring_slot(mentoring_slot)
    mentoring_slot.update_attributes(repeats: MentoringSlot::OPTIONS_FOR_AVAILABILITY::WEEKLY, repeats_on_week: "5,6")
    mentoring_slot.reload
    assert_equal ["5", "6"], get_day_opts_for_mentoring_slot(mentoring_slot)
  end

end
