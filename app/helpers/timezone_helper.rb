module TimezoneHelper
  def get_timezone_locations_options
    timezones = valid_tz_info_timezone_objects.sort { |a, b| a.current_period.utc_total_offset <=> b.current_period.utc_total_offset }
    options = [["common_text.prompt_text.Select_time_zone".translate, ""]]
    options += timezones.collect do |timezone|
      timezone_details = ActiveSupport::TimeZone.get_timezone_details(timezone)
      option_text = "#{timezone_details[:formatted_offset]} #{timezone_details[:translated_location]}"
      option_value = timezone.name
      option_attribute_hash = {timezone_area: timezone_details[:area]}
      [option_text, option_value, option_attribute_hash]
    end
  end

  def get_timezone_areas_options
    result_array = [["common_text.prompt_text.Select_time_zone_area".translate, ""]]
    sorted_timezone_areas = TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS.collect { |timezone| ActiveSupport::TimeZone.get_timezone_details(timezone)[:area]}.uniq.sort - ["Others"]
    sorted_timezone_areas.each { |timezone_area| result_array << ["timezone.region.#{timezone_area}".translate, timezone_area] }
    result_array << ["timezone.region.Others".translate, "Others"]
  end

  def get_translations_hash_for_valid_timezone_identifiers
    TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS.inject({}) do |translations_hash, timezone|
      timezone_details = ActiveSupport::TimeZone.get_timezone_details(timezone)
      translations_hash[timezone] = (timezone_details[:area] == "Others") ? timezone_details[:translated_location] : "#{timezone_details[:translated_area]}/#{timezone_details[:translated_location]}"
      translations_hash
    end
  end

  private

  def valid_tz_info_timezone_objects
    TZInfo::Timezone.all.reject {|timezone| TimezoneConstants::OBSOLETE_TIMEZONES_HASH.include? timezone.name}
  end
end