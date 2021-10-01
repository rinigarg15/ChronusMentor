require_relative './../../../../test_helper'

class LocationElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_list_of_autocompleted_locations
    # partial match the text
    assert_equal locations(:cha_am, :chennai).collect(&:full_address_db), Location.get_list_of_autocompleted_locations('Ch')
    # full match the text
    assert_equal [locations(:chennai).full_address_db], Location.get_list_of_autocompleted_locations('Chennai, Tamil Nadu, India')
    # text with special characters
    assert_equal [locations(:cha_am).full_address_db], Location.get_list_of_autocompleted_locations('cha-')
    assert_equal [locations(:st_mary).full_address_db], Location.get_list_of_autocompleted_locations('st.')
    # To check reliable false
    assert_equal [], Location.get_list_of_autocompleted_locations('Invalid')
  end

  def test_get_filtered_list_of_autocompleted_locations
    # partial match the text
    assert_equal_unordered [locations(:chennai).full_city, locations(:chennai).full_state], Location.get_filtered_list_of_autocompleted_locations('', members(:f_mentor))

    assert_equal_unordered [], Location.get_filtered_list_of_autocompleted_locations('Ch', members(:f_mentor))

    assert_equal_unordered [locations(:chennai).full_city], Location.get_filtered_list_of_autocompleted_locations('Che', members(:f_mentor))
    # full match the text
    assert_equal_unordered [locations(:ukraine).full_country, locations(:ukraine).full_state, locations(:ukraine).full_city], Location.get_filtered_list_of_autocompleted_locations('Ukr', members(:f_mentor))
    # text with special characters
    assert_equal [], Location.get_list_of_autocompleted_locations('Invalid')
  end
end