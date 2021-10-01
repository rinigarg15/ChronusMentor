require_relative './../../test_helper.rb'

class FilterUtilsTest < ActiveSupport::TestCase
  def test_admin_views_connection_status_filter_translated_options
    status_filter_options = FilterUtils::AdminViewFilters::CONNECTION_STATUS_FILTER_OPTIONS
    assert_equal 4, status_filter_options.count
    exp = [["Select...", ""], ["Never connected", "neverconnected"], ["Currently connected", "connected"], ["Currently not connected", "unconnected"]]
    assert_equal exp, status_filter_options.map{|translation_proc, value| [translation_proc.call, value]}
    assert_equal exp, FilterUtils::AdminViewFilters.connection_status_filter_translated_options
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal "Sélectionner...", FilterUtils::AdminViewFilters.connection_status_filter_translated_options[0][0]
    end
  end

end