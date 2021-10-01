require_relative './../../test_helper.rb'

class TabConstantsTest < ActiveSupport::TestCase
  def test_translation_key
    assert TabConstants.translation_key(TabConstants::HOME)[:is_key?]
    assert_equal "tab_constants.app_home", TabConstants.translation_key(TabConstants::HOME)[:value]
    assert_false TabConstants.translation_key("Other translated label")[:is_key?]
    assert_equal "Other translated label", TabConstants.translation_key("Other translated label")[:value]
  end
end