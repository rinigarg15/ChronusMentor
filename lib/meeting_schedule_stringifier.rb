# Equivalent of meeting.schedule.to_s, but with i18n support

class MeetingScheduleStringifier
  EXCEPTION_TIMES_SEPARATOR = "/"

  def initialize(meeting)
    @meeting = meeting
    @stringified_schedule = []
  end

  def stringify
    schedule = @meeting.schedule
    handle_recurrence_rules(schedule)
    construct_exception_times(schedule)
    @stringified_schedule.join(" ")
  end

  private

  def handle_recurrence_rules(schedule)
    recurrence_rule = schedule.recurrence_rules.first
    construct_repeats_every_until(recurrence_rule)
    construct_validations(recurrence_rule)
  end

  def construct_exception_times(schedule)
    exception_times = schedule.exception_times.sort
    if exception_times.present?
      exception_times.each do |exception_time|
        literal_exception_time = DateTime.localize(exception_time.in_time_zone(Time.zone).to_date, format: :full_display_no_time_highcharts_js)
        @stringified_schedule << EXCEPTION_TIMES_SEPARATOR
        @stringified_schedule << "feature.meetings.content.not_on_date".translate(date: literal_exception_time)
      end
    end
  end

  def construct_repeats_every_until(recurrence_rule)
    interval = recurrence_rule.instance_variable_get("@interval")
    until_time = recurrence_rule.instance_variable_get("@until").in_time_zone(Time.zone)
    repeats_every = case recurrence_rule.class.name
    when "IceCube::DailyRule"
      "day"
    when "IceCube::WeeklyRule"
      "week"
    when "IceCube::MonthlyRule"
      "month"
    end

    until_date = DateTime.localize(until_time.to_date, format: :full_display_no_time_highcharts_js)
    @stringified_schedule << "feature.meetings.content.repeats.every_#{repeats_every}_until".translate(count: interval, date: until_date)
  end

  def construct_validations(recurrence_rule)
    validations = recurrence_rule.instance_variable_get("@validations")
    if validations.present?
      handle_day_validations(validations[:day])
      handle_day_of_week_validations(validations[:day_of_week])
      handle_day_of_month_validations(validations[:day_of_month])
    end
  end

  def handle_day_validations(validations)
    return if validations.blank?

    days = validations.collect { |validation| validation.instance_variable_get("@day") }.sort
    @stringified_schedule << if days == [0, 6]
      "feature.meetings.content.on_Weekends".translate
    elsif days == (1..5).to_a
      "feature.meetings.content.on_Weekdays".translate
    else
      "feature.meetings.content.on_dates".translate(dates: days.collect { |day| "date.day_names_plural".translate[day] }.to_sentence)
    end
  end

  def handle_day_of_week_validations(validations)
    return if validations.blank?

    validation = validations.first
    nth_weekday = validation.instance_variable_get("@occ")
    day_of_week = Date::DAYNAMES[validation.instance_variable_get("@day")]
    @stringified_schedule << "feature.meetings.content.on_the_date".translate(date: "#{ordinalize(nth_weekday)} #{day_of_week}")
  end

  def handle_day_of_month_validations(validations)
    return if validations.blank?

    validation = validations.first
    nth_monthday = validation.instance_variable_get("@day")
    nth_day_of_month = "feature.meetings.content.nth_day_of_month".translate(nth_day: ordinalize(nth_monthday))
    @stringified_schedule << "feature.meetings.content.on_the_date".translate(date: nth_day_of_month)
  end

  def ordinalize(number)
    ordinal = "display_string.ordinals".translate[number.to_s.to_sym] ||
      "display_string.ordinals".translate[(number % 10).to_s.to_sym] ||
      "display_string.ordinals".translate[:default]
    "display_string.ordinal".translate(number: number, ordinal: ordinal)
  end
end