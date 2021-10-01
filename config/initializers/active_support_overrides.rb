module ActiveSupport
  class TimeZone
    # Fix time zone for daylight saving times

    # Have to call "now" to deal with daylight saving time, see:
    # https://github.com/rails/rails/issues/7297

    # Returns a textual representation of time zone.
    def to_s
      timezone_details = ActiveSupport::TimeZone.get_timezone_details(self)
      if timezone_details[:area] == "Others"
        return "#{timezone_details[:formatted_offset]} #{timezone_details[:translated_location]}"
      else
        return "#{timezone_details[:formatted_offset]} #{timezone_details[:translated_area]}/#{timezone_details[:translated_location]}"
      end
    end

    def self.get_timezone_details(timezone)
      timezone = ActiveSupport::TimeZone.new(timezone) if timezone.is_a?(String)
      timezone = timezone.tzinfo if timezone.is_a?(ActiveSupport::TimeZone)
      timezone_area, timezone_location = timezone.name.split("/", 2)
      if timezone_location.blank?
        timezone_location = timezone_area
        timezone_area = "Others"
      end
      utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(timezone.current_period.utc_total_offset, true)
      {
        area: timezone_area,
        location: timezone_location,
        translated_area: "timezone.region.#{timezone_area}".translate,
        translated_location: "timezone.zone.#{timezone_location}".translate,
        formatted_offset: "(GMT#{utc_offset})"
      }
    end
  end
end