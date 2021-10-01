require_relative './../../test_helper.rb'

class CommonFilterServiceTest < ActiveSupport::TestCase

  def test_initialize_date_range_filter_params
    assert_equal ["", ""], CommonFilterService.initialize_date_range_filter_params("")
    assert_equal ["a", "b"], CommonFilterService.initialize_date_range_filter_params(["a", "b"])
    assert_equal [format_start_time("01/01/2004"),format_end_time("01/01/2004")], CommonFilterService.initialize_date_range_filter_params("01/01/2004")
    assert_equal [format_start_time("01/01/2004"), format_end_time("01/01/2014")], CommonFilterService.initialize_date_range_filter_params("01/01/2004 - 01/01/2014")
    Time.zone = "Asia/Tokyo"
    start_time, end_time = CommonFilterService.initialize_date_range_filter_params("01/01/2004 - 01/05/2014")
    assert_equal DateTime.parse('1st Jan 2004 00:00:00+09:00').to_s, start_time.to_s
    assert_equal DateTime.parse('5th Jan 2014 23:59:59+09:00').to_s, end_time.to_s

  end

  private

  def format_start_time(string)
    Date.strptime(string, "date.formats.date_range".translate).beginning_of_day
  end

  def format_end_time(string)
    Date.strptime(string, "date.formats.date_range".translate).end_of_day
  end
end