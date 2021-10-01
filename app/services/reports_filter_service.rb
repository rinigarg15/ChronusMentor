class ReportsFilterService

  def self.get_report_date_range(filters, default_start_time)
    if filters.blank? || filters[:date_range].blank?
      return default_start_time.to_date, Time.current.to_date
    else
      range = filters[:date_range].split("-").collect do |date|
        Date.strptime(date.strip, MeetingsHelper::DateRangeFormat.call).to_date
      end
      if range.count > 1
        return range[0], range[1]
      else
        return range[0], range[0]
      end
    end
  end

  def self.date_to_string(start_date, end_date)
    "#{start_date.strftime(MeetingsHelper::DateRangeFormat.call)} - #{end_date.strftime(MeetingsHelper::DateRangeFormat.call)}"
  end

  def self.dynamic_profile_filter_params(profile_filter_params)
    filter_values = profile_filter_params.values
    filter_values.select{|v| v["field"] =~ /column/}
  end

  def self.get_percentage_change(prev_period_count, current_period_count)
    return nil if prev_period_count == nil
    if prev_period_count > 0
      percentage = (((current_period_count - prev_period_count).to_f /  prev_period_count)*100).round()
    else
      percentage = (current_period_count == 0 ? 0 : 100)
    end
    return percentage
  end

  def self.set_percentage_from_ids(prev_period_ids, current_period_ids)
    prev_period_count = prev_period_ids.nil? ? nil : prev_period_ids.count
    current_period_count = current_period_ids.count
    return ReportsFilterService.get_percentage_change(prev_period_count, current_period_count), prev_period_count
  end

  def self.get_previous_time_period(start_date, end_date, program)
    duration = (end_date - start_date).to_i + 1
    prev_period_start_date = start_date - duration.days

    if prev_period_start_date >= program.created_at.to_date
      [prev_period_start_date, start_date - 1.days]
    else
      [nil, nil]
    end
  end

  def self.program_created_date(program)
    program.created_at.to_date
  end

  def self.dashboard_past_meetings_date
    Time.current.to_date
  end

  def self.dashboard_upcoming_end_date
    (Time.current + 1.year).to_date
  end

  def self.dashboard_upcoming_start_date
    (Time.current + 1.day).to_date
  end
end