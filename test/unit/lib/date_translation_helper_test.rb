require_relative './../../test_helper.rb'

class DateTranslationHelperTest < ActiveSupport::TestCase
  include DateTranslationHelper

  def test_get_datetime_str_in_en
    assert_equal "January", get_datetime_str_in_en("January")
    run_in_another_locale(:"fr-CA") do
      assert_equal "June", get_datetime_str_in_en("Juin")
    end
  end

  def test_valid_date
    assert valid_date?("23 June, 2018")
    assert_equal Date.parse("23 June, 2018"), valid_date?("23 June, 2018", get_date: true)
    assert_false valid_date?("01/31/2019")
    assert_false valid_date?("01/31/2019", get_date: true)
  end
end