require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/managers_helper"

class ManagersHelperTest < ActionView::TestCase  
  def test_formatted_manager_in_listing
    manager = Manager.new(:first_name => "Manager", :last_name => 'a', :email => 'manager@example.com')
    assert_dom_equal("<div>Manager a (<a href=\"mailto:manager@example.com\">manager@example.com</a>)</div>", formatted_manager_in_listing(manager))
    assert_dom_equal("<div></div>", formatted_manager_in_listing(nil))
  end
end