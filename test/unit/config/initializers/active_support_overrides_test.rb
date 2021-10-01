require_relative './../../../test_helper.rb'

class ActiveSupportOverridesTest < ActiveSupport::TestCase
  def test_get_timezone_details
    rails_timezone = ActiveSupport::TimeZone.new("Kolkata")
    tz_info_timezone = TZInfo::Timezone.new("Asia/Kolkata")
    dst_aware_offset = Time.now.in_time_zone("America/North_Dakota/New_Salem").dst? ? "(GMT-05:00)" : "(GMT-06:00)"
    asia_hash = { area: "Asia", location: "Kolkata", translated_area: "Asia", translated_location: "Kolkata", formatted_offset: "(GMT+05:30)" }
    met_offset = Time.now.in_time_zone("MET").dst? ? "(GMT+02:00)" : "(GMT+01:00)"
    met_hash = { area: "Others", location: "MET", translated_area: "Others", translated_location: "MET", formatted_offset: met_offset }
    america_hash = { area: "America", location: "North_Dakota/New_Salem", translated_area: "America", translated_location: "North Dakota/New Salem", formatted_offset: dst_aware_offset }

    assert_equal_hash asia_hash, ActiveSupport::TimeZone.get_timezone_details("Asia/Kolkata")
    assert_equal_hash america_hash, ActiveSupport::TimeZone.get_timezone_details("America/North_Dakota/New_Salem")
    assert_equal_hash asia_hash, ActiveSupport::TimeZone.get_timezone_details(rails_timezone)
    assert_equal_hash asia_hash, ActiveSupport::TimeZone.get_timezone_details(tz_info_timezone)
    assert_equal_hash met_hash, ActiveSupport::TimeZone.get_timezone_details("MET")
  end
end