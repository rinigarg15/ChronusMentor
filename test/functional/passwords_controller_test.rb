require_relative './../test_helper.rb'

class PasswordsControllerTest < ActionController::TestCase

  def test_should_get_new_for_non_logged_in_user
    current_program_is :albers
    get :new
    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:password)
  end

  def test_should_create_a_reset_password_entry_for_a_user_from_organization_level
    current_organization_is :org_primary
    @controller.stubs(:simple_captcha_valid?).returns(true)
    ForgotPassword.expects(:forgot_password).times(1).returns(stub(:deliver_now))
    post :create, xhr: true, params: { member_email: { email: users(:f_admin).email }}
    flash_message = "If #{assigns(:password).email} is a registered member of the " + (assigns(:current_program) ? "#{assigns(:current_program).name}" : "#{assigns(:current_organization).name}") + ", instructions to reset your password will be sent to that address immediately. If you do not receive the email, please contact your " + (assigns(:current_program) ? "<a href='#{contact_admin_url}'>program administrator </a>" : "program administrator")
    assert_equal flash_message, flash[:notice]
    assert_xhr_redirect program_root_path
  end

  def test_should_create_a_reset_password_entry_for_a_user_from_organization_level_with_back_url
    current_organization_is :org_primary
    @controller.expects(:back_url).at_least(0).returns('/users')
    @controller.stubs(:simple_captcha_valid?).returns(true)
    ForgotPassword.expects(:forgot_password).times(1).returns(stub(:deliver_now))
    post :create, xhr: true, params: { member_email: { email: users(:f_admin).email }}
    flash_message = "If #{assigns(:password).email} is a registered member of the " + (assigns(:current_program) ? "#{assigns(:current_program).name}" : "#{assigns(:current_organization).name}") + ", instructions to reset your password will be sent to that address immediately. If you do not receive the email, please contact your " + (assigns(:current_program) ? "<a href='#{contact_admin_url}'>program administrator </a>" : "program administrator")
    assert_equal flash_message, flash[:notice]
    assert_xhr_redirect program_root_path
  end

  def test_forgot_password_captcha_fails
    current_organization_is :org_primary
    @controller.stubs(:simple_captcha_valid?).returns(false)
    ForgotPassword.expects(:forgot_password).never
    post :create, xhr: true, params: { member_email: { email: users(:f_admin).email }}
    assert_equal "Word verification failed. Please try again.", assigns(:error_message)
  end

  def test_should_not_create_a_reset_password_entry_for_a_non_member_user
    current_program_is :ceg
    post :create, xhr: true, params: { member_email: { email: 'nouser@fake.com' }}
    flash_message = "If #{assigns(:password).email} is a registered member of the " + (assigns(:current_program) ? "#{assigns(:current_program).name}" : "#{assigns(:current_organization).name}") + ", instructions to reset your password will be sent to that address immediately. If you do not receive the email, please contact your " + (assigns(:current_program) ? "<a href=\"#{contact_admin_url}\" class=\"no-waves\">program administrator</a>" : "program administrator")
    assert_equal flash_message, flash[:notice]
    assert_xhr_redirect program_root_path
  end

  # Reset password page without logging in and with a valid code should render
  # reset password page.
  def test_should_get_reset_password_page_if_not_logged_in
    user = users(:ram)
    p = Password.create!(member: user.member)

    current_program_is :albers
    get :reset, params: { reset_code: p.reset_code, signup_roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]}
    assert_response :success
    assert_template 'reset'
    assert_equal p, assigns(:password)
    assert_equal user.member, assigns(:member)
    assert_equal_hash( { programs(:albers).root => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME] }, @request.session[:signup_roles])
  end

  def test_reset_when_invalid_reset_code
    current_program_is :albers

    # Invalid reset code.
    get :reset, params: { reset_code: 'asda'}
    assert_equal "Invalid reset code", flash[:error]
    assert_redirected_to program_root_path
    assert_nil @request.session[:signup_roles]

    # No reset code
    get :reset
    assert_equal "Invalid reset code", flash[:error]
    assert_redirected_to program_root_path
    assert_nil @request.session[:signup_roles]
  end

  def test_update_password
    user = users(:ram)
    program = user.program
    password = Password.create!(member: user.member)

    Member.any_instance.expects(:sign_out_of_other_sessions)
    current_program_is program
    assert_difference "Password.count", -1 do
      https_post :update_password, params: { member: { password: "some password", password_confirmation: "some password"}, reset_code: password.reset_code}
    end
    assert_redirected_to login_path(auth_config_id: program.organization.chronus_auth.id)
    assert_equal "Your password has been successfully changed. Please login with your new password.", flash[:notice]
    assert_equal user.email, session[:email]
  end

  def test_update_password_when_loggedin_user
    Member.any_instance.expects(:sign_out_of_other_sessions)
    current_user_is :ram
    https_post :update_password, params: { member: { password: 'some password', password_confirmation: 'some password', current_password: "monkey" }}
    assert_redirected_to program_root_path
    assert_equal "Your password has been successfully changed", flash[:notice]
    assert_equal assigns(:current_member), assigns(:member)
  end

  def test_update_password_when_wrong_current_password
    Member.any_instance.expects(:sign_out_of_other_sessions).never
    current_user_is :ram
    https_post :update_password, params: { member: { password: 'some password', password_confirmation: 'some password', current_password: "random" }}
    assert_equal assigns(:current_member), assigns(:member)
    assert_equal ["is invalid"], assigns(:member).errors[:current_password]
  end

  def test_update_password_when_suspended_member
    user = users(:ram)
    member = user.member
    member.update_attribute(:state, Member::Status::SUSPENDED)
    member.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).update_term(term: "Track")
    setup_admin_custom_term

    Member.any_instance.expects(:sign_out_of_other_sessions).never
    current_user_is user
    https_post :update_password, params: { member: { password: 'some password', password_confirmation: 'some password', current_password: "monkey" }}
    assert_redirected_to account_settings_path
    assert_equal "Your password was not successfully updated since we are facing trouble with your account. Please contact the track super admin.", flash[:error]
    assert_equal assigns(:current_member), assigns(:member)
  end

  def test_update_password_when_password_mismatch
    password = Password.create!(member: members(:ram))

    Member.any_instance.expects(:sign_out_of_other_sessions).never
    current_program_is :albers
    assert_no_difference "Password.count" do
      https_post :update_password, params: { member: { password: 'some one', password_confirmation: 'some password', current_password: 'monkey' }, reset_code: password.reset_code}
    end
    assert_response :success
    assert_equal password, assigns(:password)
    assert_not_nil assigns(:member) # User record's password attribute should have been attempted to be saved.
    assert_equal 'some one', assigns(:member).password
    assert_equal 'some password', assigns(:member).password_confirmation
  end

  def test_update_password_when_password_requirements_unsatisfied
    password = Password.create!(member: members(:ram))

    Member.any_instance.expects(:sign_out_of_other_sessions).never
    current_program_is :albers
    assert_no_difference 'Password.count' do
      # password shorter than minimum requirement.
      https_post :update_password, params: { member: { password: 'asd', password_confirmation: 'asd' }, reset_code: password.reset_code}
    end
    assert_response :success
    assert_equal password, assigns(:password)
  end

  def test_create_when_invalid_email
    current_program_is :ceg
    post :create, xhr: true, params: { member_email: { email: "abc" }}
    assert_response :success
    assert_equal "Please enter a valid email address", assigns(:error_message)
  end

  def test_create_when_email_blank
    current_program_is :ceg
    post :create, xhr: true, params: { member_email: { email: "" }}
    assert_response :success
    assert_equal "Please enter a valid email address", assigns(:error_message)
  end

  def test_create
    ForgotPassword.expects(:forgot_password).never
    current_program_is :ceg
    post :create, params: { member_email: { email: "abcd@efgh.com" }}
    assert_redirected_to program_root_path
    flash_message = "If #{assigns(:password).email} is a registered member of the " + (assigns(:current_program) ? "#{assigns(:current_program).name}" : "#{assigns(:current_organization).name}")+", instructions to reset your password will be sent to that address immediately. If you do not receive the email, please contact your " + (assigns(:current_program) ? "<a href=\"#{contact_admin_url}\" class=\"no-waves\">program administrator</a>" : "program administrator")
    assert_equal flash_message, flash[:notice]
  end

  def test_update_password_when_reactivation
    member = members(:ram)
    organization = member.organization
    organization.security_setting.update_attributes!(maximum_login_attempts: 1)
    2.times { member.increment_login_counter! }
    password = Password.create!(member: member)

    current_organization_is organization
    assert_difference "Password.count", -1 do
      https_post :update_password, params: { member: { password: "some password", password_confirmation: "some password" }, reset_code: password.reset_code}
    end
    assert_redirected_to login_path(auth_config_id: organization.chronus_auth.id)
    assert_equal "Your account has been successfully reactivated. Please login with your new password.", flash[:notice]
    assert_equal 0, member.reload.failed_login_attempts
  end

  def test_reactivate_account
    current_program_is :albers
    assert_emails 1 do
      get :reactivate_account, params: { email: users(:ram).email}
    end
    assert_equal "If the email address is the address of a registered member of the program, instructions to reactivate your account will be sent to that address immediately.", flash[:notice]
    assert_redirected_to program_root_path
  end

  def test_reactivate_account_when_unregistered_email
    current_program_is :albers
    assert_no_emails do
      get :reactivate_account, params: { email: "random@random.com"}
    end
    assert_equal "If the email address is the address of a registered member of the program, instructions to reactivate your account will be sent to that address immediately.", flash[:notice]
    assert_redirected_to program_root_path
  end

  def test_update_password_when_should_not_contain_login_name
    user = users(:ram)
    user.member.organization.security_setting.update_attributes(can_contain_login_name: false)

    current_user_is user
    https_post :update_password, params: { member: { current_password: 'monkey', password: 'Raman123', password_confirmation: 'Raman123' }}
    assert_redirected_to account_settings_path
    assert_equal ["should not contain your name or your email address"], assigns(:member).errors[:password]
  end

  def test_reset_when_reset_code
    member = members(:ram)
    password = Password.create!(member: member)

    current_program_is :albers
    get :reset, params: { reset_code: password.reset_code, password_expiry: true}
    assert_response :success
    assert_equal "Reset Password", assigns(:title)
    assert_template "reset"
    assert_equal password, assigns(:password)
    assert_equal member, assigns(:member)
  end

  def test_update_password_when_history_enabled
    user = users(:f_mentor)
    member = user.member
    member.organization.security_setting.update_attributes!(password_history_limit: 2)
    member.password = "chronus"
    member.password_confirmation = "chronus"
    member.save!

    current_user_is user
    assert_difference "member.versions.size", 1 do
      https_post :update_password, params: { member: { current_password: 'chronus', password: 'some password', password_confirmation: 'some password' }}
    end
    crypted_password_1 = member.encrypt("chronus")
    crypted_password_2 = member.encrypt("some password")
    assert_equal member.versions.last.modifications["crypted_password"], [crypted_password_1, crypted_password_2]
  end

  def test_update_password_fail_when_history_enabled
    user = users(:f_mentor)
    member = user.member
    member.organization.security_setting.update_attributes!(password_history_limit: 2)
    member.password = "chronus"
    member.password_confirmation = "chronus"
    member.save!

    current_user_is user
    assert_no_difference "member.versions.size" do
      https_post :update_password, params: { member: { current_password: 'chronus', password: 'chronus', password_confirmation: 'chronus' }}
    end
    assert_redirected_to account_settings_path
    assert_equal "Your new password must differ from your last 2 passwords", flash[:error]
  end

  def test_update_password_when_history_enabled_and_reset_code
    user = users(:f_mentor)
    member = user.member
    member.organization.security_setting.update_attributes!(password_history_limit: 2)
    password = Password.create!(member: member)
    member.password = "chronus"
    member.password_confirmation = "chronus"
    member.save!

    current_user_is user
    assert_difference "member.versions.size", 1 do
      https_post :update_password, params: { member: { password: 'some password', password_confirmation: 'some password' }, reset_code: password.reset_code}
    end
    crypted_password_1 = member.encrypt("chronus")
    crypted_password_2 = member.encrypt("some password")
    assert_equal member.versions.last.modifications["crypted_password"], [crypted_password_1, crypted_password_2]
  end

  def test_update_password_when_regex_string_configured
    user = users(:f_mentor)
    member = user.member
    password = Password.create!(member: member)
    member.password = "test123"
    member.password_confirmation = "test123"
    member.save!

    chronus_auth = member.organization.chronus_auth
    chronus_auth.password_message = "should be at least 8 characters long and have 1 upper case, 1 lower case, 1 numeric and 2 special characters"
    chronus_auth.regex_string = "(?=.{8,})(?=.*\\d)(?=.*[a-z])(?=.*[A-Z])(?=(.*[~!@\#$%^&*-+=`.,?/:;_|(){}<>\\[\\]]){2,})"
    chronus_auth.save!

    current_user_is user
    https_post :update_password, params: { member: { password: 'chronus', password_confirmation: 'chronus' }, reset_code: password.reset_code}
    assert_match "Password is invalid", response.body
  end

  def test_sha2_migration_with_password_history
    user = users(:f_mentor)
    member = user.member
    password = Password.create!(member: member)

    # update a sha1 password for the member for testing
    crypted_password = Member.sha1_digest("chronus", member.salt)
    member.update_attributes!(encryption_type: Member::EncryptionType::SHA1, crypted_password: crypted_password)
    # update a sha1 password for the member for testing
    crypted_password = Member.sha1_digest("monkey", member.salt)
    member.update_attributes!(encryption_type: Member::EncryptionType::SHA1, crypted_password: crypted_password)
    assert_no_difference "member.versions.size" do
      # Migrate SHA1 to SHA1_SHA2(INTERMEDIATE) and it should not version the password
      member.migrate_pwd_to_intermediate
      assert_equal Member::EncryptionType::INTERMEDIATE, member.encryption_type
      assert_equal member.crypted_password, member.encrypt("monkey")
    end

    # Migrating to SHA2 through resetting the password
    current_user_is user
    assert_difference "member.versions.size", 1 do
      https_post :update_password, params: { member: { password: "chronus1", password_confirmation: "chronus1" }, reset_code: password.reset_code}
    end
    assert_equal member.reload.encryption_type, Member::EncryptionType::SHA2
    assert_equal member.encrypt('chronus1'), member.crypted_password

    # Check if the password_history works with both old SHA1 passwords and old SHA2 passwords
    member.organization.security_setting.update_attributes!(password_history_limit: 3)
    member.reload
    member.password = "chronus"
    assert_false member.can_update_password?
    member.password = "monkey"
    assert_false member.can_update_password?
    member.password = "chronus1"
    assert_false member.can_update_password?
    member.password = "chronus2"
    assert member.can_update_password?
  end
end
