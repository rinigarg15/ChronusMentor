require_relative './../../test_helper.rb'
require_relative './../../../app/helpers/analytics_helper'

class AnalyticsHelperTest < ActionView::TestCase
  include UsersHelper
  include ProgramsHelper
  include MembersHelper
  include ExplicitUserPreferencesHelper
  def setup
    super
    helper_setup
    self.expects(:working_on_behalf?).at_least(0)
    self.expects(:wob_member).at_least(0)
  end
  
  def test_render_gtac
    str = render_gtac()
    
    assert_not_nil str
    assert_match ENV["DEFAULT_DOMAIN_NAME"].to_s, str
    assert_match "UA-AAABBB-CC", str
  end

  def test_render_gtac_for_logged_in
    @current_member = nil
    assert_false get_dimensions_hash[:is_logged_in]
    str = render_gtac()
    assert_match %Q["is_logged_in":2], str
    assert_match "ga('set', key, value)", str

    @current_member  = members(:f_admin)
    assert get_dimensions_hash[:is_logged_in]
    str = render_gtac()
    assert_match %Q["is_logged_in":2], str
    assert_match "ga('set', key, value)", str

    @current_member = nil
    assert_false get_dimensions_hash[:is_logged_in]
    assert_equal "", get_dimensions_hash[:org_name]
    str = render_gtac()
    assert_match %Q["is_logged_in":2], str
    assert_match "ga('set', key, value)", str

    @current_user = users(:f_admin)
    @current_program = @current_user.program
    @current_organization = @current_program.organization
    assert get_dimensions_hash[:is_logged_in]
    assert_equal "#{@current_organization.account_name} - #{@current_organization.name}", get_dimensions_hash[:org_name]
    str = render_gtac()
    assert_match %Q["is_logged_in":2], str
    assert_match "ga('set', key, value)", str
  end

  def test_render_gtac_for_is_admin
    @current_user = nil
    @current_member = nil
    assert_false get_dimensions_hash[:is_admin]
    str = render_gtac()
    assert_match %Q["is_admin":3], str
    assert_match "ga('set', key, value)", str

    @current_user = users(:f_mentor)
    @current_program = @current_user.program
    @current_member = nil
    assert_false get_dimensions_hash[:is_admin]
    str = render_gtac()
    assert_match %Q["is_admin":3], str
    assert_match "ga('set', key, value)", str

    @current_user = users(:f_admin)
    assert get_dimensions_hash[:is_admin]
    str = render_gtac()
    assert_match %Q["is_admin":3], str
    assert_match "ga('set', key, value)", str

    @current_user = nil
    @current_member = members(:f_mentor)
    assert_false get_dimensions_hash[:is_admin]
    str = render_gtac()
    assert_match %Q["is_admin":3], str
    assert_match "ga('set', key, value)", str

    @current_program = nil
    @current_member = members(:f_admin)
    assert get_dimensions_hash[:is_admin]
    str = render_gtac()
    assert_match %Q["is_admin":3], str
    assert_match "ga('set', key, value)", str
  end
  
  def test_render_gtac_with_str
    str = render_gtac("this is the string.")
    
    assert_not_nil str
    assert_match "this is the string.", str
  end
  
  def test_request_trackable
    # By default request is trackable for test and production envs and
    # without the ignore cookie
    assert_equal(true, request_trackable?)
    
    @cookies = {'_groups_ignore' => '1'}
    assert_equal(false, request_trackable?)
  end

  private
  def get_current_url
    @current_url || 'http://temp.' + DEFAULT_DOMAIN_NAME + '/nothing'
  end
  
  def cookies
    @cookies || {}
  end
  
  def logged_in_program?
    !current_user.nil?
  end
  
  def session
    mock(:session_id => '123')
  end

  def request
    mock(:post? => @simulate_post)
  end

  def logged_in_organization?
    !!current_member
  end

  def program_view?
    !!@current_program
  end

  def logged_in_at_current_level?
    program_view? ? logged_in_program? : logged_in_organization?
  end

  def current_user_or_member
    program_view? ? current_user : current_member
  end
end
