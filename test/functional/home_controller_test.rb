require_relative './../test_helper.rb'

class HomeControllerTest < ActionController::TestCase

  def test_landing_page_requires_super_login
    get :default
    assert_redirected_to super_login_path
  end

  def test_landing_page_renders_after_super_login
    login_as_super_user
    get :default
    assert_response :success
    assert_template 'default'
    assert_select 'html'

    assert_match /ga\('create'/, @response.body
    assert_match /ga\('set'/, @response.body
    assert_match /ga\('set', 'anonymizeIp', true\)/, @response.body
    assert_match /ga\('send', 'pageview', Analytics.getPageUrlForGA\(window.location.href\)\)/, @response.body
    assert_false assigns(:invalid_browser)
  end

  def test_when_a_logged_in_user_accesses_default_page_after_it_should_redirect_to_program_home_page
    login_as_super_user
    current_user_is :f_mentor

    get :default
    assert_response :success
    assert_template 'default'
    assert_select 'html'
  end

  #Privacy Policy Tests
  def test_privacy_policy_does_not_need_login
    current_program_is :albers
    get :privacy_policy
    assert_response :success
    assert_template 'privacy_policy'
  end

  def test_should_get_privacy_outside_program
    get :privacy_policy
    assert_response :success
    assert !assigns(:is_program_privacy)
    assert !assigns(:program_privacy)
  end

  def test_should_get_program_privacy_inside_program
    current_program_is :albers
    programs(:org_primary).update_attribute :privacy_policy, 'Hello great!'
    get :privacy_policy, params: { p: true}
    assert_response :success
    assert assigns(:is_program_privacy)
    assert_equal 'Hello great!', assigns(:program_privacy)
    assert_select 'ul.nav-tabs'
    assert_match 'Hello great!', @response.body
  end

  def test_inline_edit_organizations
    login_as_super_user
    current_program_is :albers
    post :inline_edit_organizations, xhr: true, params: { id: 1, account_name: "new_account_name"}
    assert_equal 'new_account_name', programs(:org_primary).account_name
  end

  def test_should_get_chronus_privacy_inside_program
    current_program_is :albers
    programs(:org_primary).update_attribute :privacy_policy, 'Hello great!'
    get :privacy_policy
    assert_response :success
    assert !assigns(:is_program_privacy)
    assert_equal 'Hello great!', assigns(:program_privacy)
    assert_select 'ul.nav-tabs'
    assert_no_match(/Hello great!/, @response.body)
  end

  def test_chronus_privacy_policy_when_program_privacy_policy_blank
    current_program_is :albers
    assert programs(:org_primary).privacy_policy.blank?
    get :privacy_policy, params: { p: true}
    assert_response :success
    assert !assigns(:is_program_privacy)
    assert assigns(:program_privacy).blank?
    assert_select 'div.terms_and_pp'
  end

  def test_terms_does_not_need_login
    current_program_is :albers
    get :terms
    assert_response :success
    assert_template 'terms'
  end


  def test_should_get_terms_outside_program
    get :terms
    assert_response :success
    assert !assigns(:is_program_terms)
    assert !assigns(:program_terms)
  end

  def test_terms_both_chronus_and_customer_added
    current_program_is :albers
    programs(:org_primary).update_attribute :agreement, 'Hello great!'
    get :terms
    assert_response :success
    assert_match(/Hello great!/, @response.body)
    assert_select "div#custom_terms"
    assert_select "div#chronus_terms"
  end

  def test_should_get_only_chronus_terms
    current_program_is :albers
    programs(:org_primary).update_attribute :agreement, nil
    get :terms
    assert_no_match(/Hello\ great!/, @response.body)
    assert_response :success
    assert_select "div#custom_terms", count: 0
    assert_select "div#chronus_terms"
  end

  def test_display_custom_terms_only
    current_program_is :albers
    programs(:org_primary).update_attributes(agreement: 'Hello great!', privacy_policy: 'Hello great!', display_custom_terms_only: true)
    get :terms
    assert_match(/Hello\ great!/, @response.body)
    assert_select "div#custom_terms"
    assert_select "div#chronus_terms", count: 0
  end

  def test_display_custom_terms_only_privacy_policy
    current_program_is :albers
    programs(:org_primary).update_attributes(agreement: 'Hello great!', privacy_policy: 'Hello great!', display_custom_terms_only: true)
    get :privacy_policy
    assert_false assigns(:is_program_privacy)
    assert_equal 'Hello great!', assigns(:program_privacy)
    assert_select "div#custom_privacy_policy"
    get :privacy_policy, params: { p: true}
    assert assigns(:is_program_privacy)
    assert_equal 'Hello great!', assigns(:program_privacy)
    assert_select "div#custom_privacy_policy"
  end

  def test_chronus_terms_when_program_terms_blank
    current_program_is :albers
    assert programs(:org_primary).agreement.blank?
    get :terms, params: { p: true}
    assert_response :success
    assert !assigns(:is_program_terms)
    assert assigns(:program_terms).blank?
    assert_select 'div#chronus_terms'
  end

  def test_check_chronus_terms_and_policy_when_customer_terms_and_policy_is_nil
    current_program_is :albers
    programs(:org_primary).update_attributes(agreement: nil, privacy_policy: nil, display_custom_terms_only: true)
    get :privacy_policy
    assert_select "div#custom_privacy_policy", count: 0
    assert_select 'div.terms_and_pp'
    get :terms
    assert_select "div#custom_terms", count: 0
    assert_select "div#chronus_terms"

    programs(:org_primary).update_attributes(agreement: 'Hello great!', privacy_policy: nil, display_custom_terms_only: true)
    get :privacy_policy
    assert_select "div#custom_privacy_policy", count: 0
    assert_select 'div.terms_and_pp'
    get :terms
    assert_match(/Hello\ great!/, @response.body)
    assert_select "div#custom_terms"
    assert_select "div#chronus_terms", count: 0

    programs(:org_primary).update_attributes(agreement: nil, privacy_policy: 'Hello great!', display_custom_terms_only: true) 
    get :privacy_policy
    assert_match(/Hello\ great!/, @response.body)
    assert_select "div#custom_privacy_policy"
    assert_false assigns(:is_program_privacy)
    get :terms
    assert_select "div#custom_terms", count: 0
    assert_select "div#chronus_terms"

    programs(:org_primary).update_attributes(agreement: 'Hello great!', privacy_policy: nil, display_custom_terms_only: false) 
    get :privacy_policy
    assert_select "div#custom_privacy_policy", count: 0
    assert_select 'div.terms_and_pp'
    get :terms
    assert_match(/Hello\ great!/, @response.body)
    assert_select "div#custom_terms"
    assert_select "div#chronus_terms"
  end

  # Be careful testing with cookies: https://wincent.com/wiki/Testing_cookies_in_Rails
  def test_should_not_render_analytics_code_when_accessed_with_ignore_cookie
    login_as_super_user
    @request.cookies['_groups_ignore'] = "1"
    get :default
    assert_response :success
    assert_template 'default'
    assert_select 'html'

    assert_no_match(/pageTracker/, @response.body)
  end

  def test_should_display_orgs_redirect
    get :organizations
    assert_redirected_to super_login_path
  end

  def test_should_display_orgs
    login_as_super_user
    get :organizations
    org = programs(:org_primary)
    assert_equal 58, assigns(:member_count)[org.id]
    assert_equal 56, assigns(:active_member_count)[org.id]
    assert_response :success
    assert_template 'organizations'
  end

  def test_feature_report_without_super_login
    get :feature_report
    assert_redirected_to super_login_path
  end

  def test_feature_report_html
    login_as_super_user
    get :feature_report
    assert_response :success
  end

  def test_feature_report_csv
    login_as_super_user
    get :feature_report, params: { format: :csv}

    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    assert_response :success
    csv_response = @response.body.split("\n")
    expected_header = ["Program ID", "Organization ID", "Active Org", "Program Name", "Organization Name", "Account Name"]
    Feature.all.each do |f|
      expected_header << f.name
    end
    assert_match expected_header.join(","), csv_response[0]
    assert_equal Program.count+1, csv_response.size
  end

  def test_feature_report_json
    login_as_super_user
    get :feature_report, params: { format: :json}
    assert_response :success

    response_hash = ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(@response.body))
    assert_equal_unordered ["program_id", "organization_id", "active", "program_name", "organization_name", "account_name"], response_hash[:header][0..5].collect{|a| a[:field]}
    assert_equal_unordered Feature.pluck(:name).map{|a| a.downcase.gsub(/ +/,'_')}, response_hash[:header][6..-1].collect{|a| a[:field]}

    program = programs(:albers)

    assert_equal Program.count, response_hash[:all_program_array].count
    albers_hash = response_hash[:all_program_array].select { |program_hash| program_hash[:program_id] == program.id.to_s }.first
    Feature.all.each do |f|
      assert_equal albers_hash[f.name.downcase.gsub(/ +/,'_').to_sym], program.has_feature?(f.name).to_s
    end
  end

  def test_should_display_deactivate_redirect
    get :deactivate
    assert_redirected_to super_login_path
  end

  def test_should_display_deactivate
    login_as_super_user
    current_organization_is :org_primary
    get :deactivate
    assert_response :success
    assert_match("#{programs(:org_primary).name} is currently active. Would you like to deactivate it?", @response.body)
    assert_select "input#organization_active[type=checkbox]"
  end

  def test_upgrade_browser
    current_organization_is :org_primary

    @controller.stubs(:is_unsupported_browser?).returns(true)
    get :upgrade_browser
    assert_match "You are currently using a browser that appears to be out of date", assigns(:browser_warning_content)
    assert_response :success

    @controller.stubs(:is_unsupported_browser?).returns(false)
    get :upgrade_browser
    assert_redirected_to root_path
  end

  def test_upgrade_browser_for_nil_organization
    @controller.stubs(:is_unsupported_browser?).returns(true)
    get :upgrade_browser
    assert_response :success
    assert_nil @current_organization
    assert_match "You are currently using a browser that appears to be out of date", assigns(:browser_warning_content)
  end

  def test_upgrade_browser_for_nil_organization_with_different_locale
    @controller.stubs(:is_unsupported_browser?).returns(true)
    I18n.stubs(:locale).returns(:"fr-CA")
    get :upgrade_browser
    assert_response :success
    assert_nil @current_organization
    assert_match "You are currently using a browser that appears to be out of date", assigns(:browser_warning_content)
  end

  def test_csreport
    login_as_super_user
    get :csreport, params: { active: true, format: :csv}
    assert_response :success
  end

  def test_handle_redirect
    redirect_path = "https://www.chronus.com"

    @controller.expects(:use_browsertab_for_external_link?).once.returns("No")
    get :handle_redirect, params: { redirect_path: redirect_path}
    assert_response :success
    assert_equal CGI.unescape(redirect_path), assigns(:redirect_path)
    assert_equal "No", assigns(:use_browsertab)
  end
end