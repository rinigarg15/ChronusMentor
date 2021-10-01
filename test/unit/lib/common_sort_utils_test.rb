require_relative './../../test_helper.rb'

class CommonSortUtilsTest < ActiveSupport::TestCase
  def test_we
    assert_equal_hash({:sort_field=>"id", :sort_order=>"desc"}, CommonSortUtils.fill_user_sort_input_or_defaults!({}))
    assert_equal_hash({a: 1, :sort_field=>"id", :sort_order=>"desc"}, CommonSortUtils.fill_user_sort_input_or_defaults!({a: 1}))
    assert_equal_hash({:sort_field=>"dsf", :sort_order=>"dso"}, CommonSortUtils.fill_user_sort_input_or_defaults!({}, {}, {default_sort_field: 'dsf', default_sort_order: 'dso'}))
    assert_equal_hash({:default_sort_field=>"dsf", :default_sort_order=>"dso", :sort_field=>"id", :sort_order=>"desc"}, CommonSortUtils.fill_user_sort_input_or_defaults!({default_sort_field: 'dsf', default_sort_order: 'dso'}))
    assert_equal_hash({:sort_field=>"id", :sort_order=>"asc"}, CommonSortUtils.fill_user_sort_input_or_defaults!({}, {}, default_sort_field: 'id', default_sort_order: 'asc'))
    assert_equal_hash({:sort_field=>"id", :sort_order=>"desc"}, CommonSortUtils.fill_user_sort_input_or_defaults!({}, {sort_field: 'sf', sort_order: 'so'}))
    assert_equal_hash({:sort_field=>"id", :sort_order=>"desc"}, CommonSortUtils.fill_user_sort_input_or_defaults!({}, {sort_field: 'id', sort_order: 'so'}))
    assert_equal_hash({:sort_field=>"id", :sort_order=>"asc"}, CommonSortUtils.fill_user_sort_input_or_defaults!({}, {sort_field: 'id', sort_order: 'asc'}))
  end
end