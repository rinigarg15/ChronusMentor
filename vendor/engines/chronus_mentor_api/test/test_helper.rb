# load main application test helper to load fixtures, helper methods, etc.
require File.expand_path('../../../../../test/test_helper', __FILE__)

class Api::V2::BasicControllerTest < ActionController::TestCase
  def setup
    super
    @member = members(:f_admin)
    @member.enable_api!
    @member.reload
    @program = programs(:albers)
    current_program_is(:albers)
    Matching.expects(:perform_users_delta_index_and_refresh).at_least(0).returns(nil)
    Matching.expects(:remove_user).at_least(0).returns(nil)
    @routes = ChronusMentorApi::Engine.routes
  end

  protected

  # api 404 tests
  def self.make_not_found_tests_for(methods_list, formats = [:xml, :json])
    methods_list.each do |method, action|
      # for all formats
      formats.each do |format|
        define_method(:"test_#{action}_#{format}_should_respond_404_if_not_found") do
          assert_not_found_as method, action, format
        end
      end
    end
  end

  # api security check
  def self.make_security_tests_for(methods_list, formats = [:xml, :json])
    methods_list.each do |method, action, params|
      # for all formats
      formats.each do |format|
        # errors checking
        # - inactive user
        define_method(:"test_#{action}_#{format}_should_not_accept_inactive_user") do
          suspend_member!
          assert_forbidden method, action, credentials(params || {})
        end
        # - invalid api-key
        define_method(:"test_#{action}_#{format}_should_not_accept_anauthorized_user") do
          assert_forbidden method, action, credentials( { api_key: "incorrect" }.merge(params || {}))
        end
        # - blank api-key
        define_method(:"test_#{action}_#{format}_should_not_success_if_api_key_is_blank") do
          assert_forbidden method, action, credentials( { api_key: "" }.merge(params || {}))
        end

        # - blank api-key
        define_method(:"test_#{action}_#{format}_should_not_success_non_admin_api_key") do
          mentor = members(:f_mentor)
          mentor.enable_api!
          mentor.reload
          assert_false mentor.admin?
          assert_forbidden method, action, credentials( { api_key: mentor.api_key }.merge(params || {}))
        end
      end
    end
  end

  # catch not-found
  def assert_not_found_as(method, action, format)
    https_request method, action, params: credentials(format: format, id: -9999)
    assert_response 404
    assert_match /-9999/, @response.body
    assert_match /not found/, @response.body
  end

  # catch 403
  def assert_forbidden(method, action, options)
    https_request method, action, params: options
    assert_response 403
  end

  def credentials(options = {})
    { api_key: @member.api_key,
      format:  "xml"
    }.merge(options)
  end

  def suspend_member!
    @member.update_attribute(:state, Member::Status::SUSPENDED)
  end

  def presenter
    raise "#{self.class}#presenter method should be implemented"
  end

  # make sure we have actual program each time we call it
  def program
    @program.reload
  end

  def organization
    @program.organization.reload
  end
end