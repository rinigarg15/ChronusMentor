class CommonFilterService

  def self.initialize_date_range_filter_params(date_filter)
    return date_filter if date_filter.is_a?(Array)
    if date_filter.present?
      range = date_filter.split("-").collect do |date|
        Date.strptime(date.strip, "date.formats.date_range".translate)
      end
      start_time = range[0].beginning_of_day.to_datetime
      end_time = range[-1].end_of_day.to_datetime
    end
    return [start_time || "", end_time || ""]
  end
end