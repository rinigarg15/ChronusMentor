require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/timezone_helper"

class TimezoneHelperTest < ActionView::TestCase
  include TimezoneHelper

  def setup
    super
    helper_setup
  end

  def test_get_timezone_location_options
    timezone_location =
      if Time.now.in_time_zone("America/North_Dakota/New_Salem").dst?
        "(GMT-05:00) North Dakota/New Salem"
      else
        "(GMT-06:00) North Dakota/New Salem"
      end
    timezone_objects = ["Asia/Kolkata", "Etc/UTC", "America/North_Dakota/New_Salem"].collect{|tz_identifier| TZInfo::Timezone.get(tz_identifier)}
    timezone_location_options = [
      ["Select time zone...", ""],
      [timezone_location, "America/North_Dakota/New_Salem", { :timezone_area=>"America" }],
      ["(GMT+00:00) UTC", "Etc/UTC", { :timezone_area=>"Etc" }],
      ["(GMT+05:30) Kolkata", "Asia/Kolkata", { :timezone_area=>"Asia" }]
    ]
    TimezoneHelperTest.any_instance.stubs(:valid_tz_info_timezone_objects).returns(timezone_objects)
    assert_equal timezone_location_options, get_timezone_locations_options
  end

  def test_get_timezone_area_options
    timezone_identifiers = ["MET", "Etc/UTC", "Asia/Tokyo"]
    timezone_areas_options = [ ["Select region...", ""], ["Asia", "Asia"], ["Etc", "Etc"], ["Others", "Others"] ]
    modify_const(:VALID_TIMEZONE_IDENTIFIERS, timezone_identifiers, TimezoneConstants) do
      assert_equal timezone_areas_options, get_timezone_areas_options
    end
  end

end
