require_relative './../../test_helper.rb'
require_relative './../../../app/helpers/profile_picture_helper'

class ProfilePictureHelperTest < ActionView::TestCase
  def test_get_rotate_buttons
    assert_equal "<a class=\"btn btn-white cjs-profile-pic-rotate\" data-degree=\"-90\" href=\"javascript:void(0)\;\"><i class=\"fa fa-rotate-left fa-fw m-r-xs\"></i><span class=\"sr-only \">Rotate-Left</span></a>", get_rotate_buttons.first
    assert_equal "<a class=\"btn btn-white cjs-profile-pic-rotate\" data-degree=\"90\" href=\"javascript:void(0)\;\"><i class=\"fa fa-rotate-right fa-fw m-r-xs\"></i><span class=\"sr-only \">Rotate-Right</span></a>", get_rotate_buttons.last
  end
end
