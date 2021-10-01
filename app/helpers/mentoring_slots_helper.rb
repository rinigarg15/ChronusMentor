module MentoringSlotsHelper

  def days_list_first_letter
    ["common_text.day_name_abbreviation.Sunday".translate, "common_text.day_name_abbreviation.Monday".translate,
     "common_text.day_name_abbreviation.Tuesday".translate, "common_text.day_name_abbreviation.Wednesday".translate,
      "common_text.day_name_abbreviation.Thursday".translate, "common_text.day_name_abbreviation.Friday".translate,
       "common_text.day_name_abbreviation.Saturday".translate]
  end

  def location_text(mentoring_slot)
    mentoring_slot.location.blank? ? "-" : append_text_to_icon("fa fa-map-marker", mentoring_slot.location)
  end

  def add_urls(slots)
    slots.each do |s|
      s.merge!({:new_meeting_url => new_meeting_url, :show_member_mentoring_slot_url => member_mentoring_slot_url(s[:eventMemberId], s[:dbId])})
    end
  end

  def mentoring_slot_repeats_warning_js(mentoring_slot, confirmation_message)
    %Q[jQueryShowHide(this, '.repetition_end_date', #{MentoringSlot::Repeats::NONE}, false)]
  end

  def mentoring_slot_show_end_date
    javascript_tag(%Q[jQuery('.repetition_end_date').show();])
  end

  def get_calendar_slot_popup_header(can_create_meeting, can_create_availability_slot, options={})
    tabs = []
    if can_create_availability_slot
      tabs << {
        label: append_text_to_icon("fa fa-th", "feature.mentoring_slot.content.availability_slot".translate),
        url: "#availability_slot_form_container",
        active: true,
        link_options: {
          data: {
            toggle: "tab"
          }
        }
      }
    end
    if can_create_meeting && !options[:from_settings_page]
      tabs << {
        label: append_text_to_icon("fa fa-calendar", "feature.meetings.content.create_meeting_v1".translate(:Meeting => h(_Meeting))),
        url: "#meeting_form_container",
        active: !can_create_availability_slot,
        link_options: {
          data: {
            toggle: "tab"
          }
        }
      }
    end
    inner_tabs(tabs)
  end

  def get_day_opts_for_mentoring_slot(mentoring_slot)
    day_opts = []
    day_opts = mentoring_slot.repeats_weekly? ? mentoring_slot.repeats_on_week.split(',') : [mentoring_slot.start_time.wday.to_s]
    return day_opts
  end

  def options_for_avialability
    [["feature.mentoring_slot.repeats.Never".translate, 0],
     ["feature.mentoring_slot.repeats.Daily".translate, 1],
     ["feature.mentoring_slot.repeats.Weekly".translate, 2],
     ["feature.mentoring_slot.repeats.Monthly".translate, 3],
   ]
  end

  def get_recurring_mentoring_slot_display_text(slot_options = {})
    slot_end_time = slot_options[:recurring_options][:recurring_slot_end_time]
    end_date = DateTime.localize(slot_end_time, format: :abbr_short) if slot_end_time.present?
    case slot_options[:repeats]
    when MentoringSlot::Repeats::DAILY
      slot_end_time.present? ? "feature.mentoring_slot.content.slot_repeat_display_text_daily_with_end_time".translate(date: end_date) : "feature.mentoring_slot.content.slot_repeat_display_text_daily".translate
    when MentoringSlot::Repeats::WEEKLY
      repeat_days = slot_options[:recurring_options][:on].collect{|day| get_translated_day_name_for_slot(day.to_s)[0..1].capitalize}.join(', ')
      slot_end_time.present? ? "feature.mentoring_slot.content.slot_repeat_display_text_weekly_with_end_time".translate(repeat_days: repeat_days, date: end_date) : "feature.mentoring_slot.content.slot_repeat_display_text_weekly".translate(repeat_days: repeat_days)
    when MentoringSlot::Repeats::MONTHLY
      day_of_week = [:first, :second, :third, :fourth, :fifth]
      repeat_day = slot_options[:recurring_options][:weekday].present? ?  "#{(day_of_week.index(slot_options[:recurring_options][:on]) + 1).ordinalize}" " #{get_translated_day_name_for_slot(slot_options[:recurring_options][:weekday].to_s)}" : slot_options[:recurring_options][:on].ordinalize
      slot_end_time.present? ? "feature.mentoring_slot.content.slot_repeat_display_text_monthly_with_end_time".translate(repeat_day: repeat_day, date: end_date) : "feature.mentoring_slot.content.slot_repeat_display_text_monthly".translate(repeat_day: repeat_day)
    end 
  end

  def get_translated_day_name_for_slot(weekday)
    "date.day_names".translate[DateTime.parse(weekday.to_s).wday]
  end

end
