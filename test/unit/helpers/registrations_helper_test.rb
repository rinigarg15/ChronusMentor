require_relative './../../test_helper.rb'

class RegistrationsHelperTest < ActionView::TestCase

  def test_csv_hint_text_should_contain_template
    content = csv_hint_text
    assert_match "profile_fields_template\.csv", content
    assert_select_helper_function "a", content, text: "this template"
  end

  def test_csv_hint_text_should_contain_spec
    content = csv_hint_text
    assert_match "profile_fields_csv_spec\.txt", content
    assert_select_helper_function "a", content, text: "format specification"
  end

  def test_csv_hint_text_should_be_correct
    content = csv_hint_text
    assert_match "Provide CSV file with profile questions", content
    assert_match "Please use", content
    assert_match "Also please read", content
    assert_match "Name and email fields will be added by default and please dont include it in CSV", content
  end

  def test_get_heading_for_signup_page_when_program_invitation
    program_invitation = program_invitations(:mentor)
    program = program_invitation.program
    self.expects(:current_program).at_least(1).returns(program)
    assert_equal "Welcome! You have been invited to join #{program.name} as a Mentor.", get_heading_for_signup_page(program_invitation, nil)

    program_invitation.role_type = ProgramInvitation::RoleType::ALLOW_ROLE
    assert_equal "Welcome! You have been invited to join #{program.name}.", get_heading_for_signup_page(program_invitation, nil)
  end

  def test_get_heading_for_signup_page_when_password
    member = members(:f_admin)
    password = Password.create!(member: member)
    assert_equal "Welcome, #{member.name(name_only: true)}!", get_heading_for_signup_page(nil, password)
  end

  def test_get_title_for_signup_form
    chronus_auth = programs(:org_primary).chronus_auth
    custom_auth = AuthConfig.new(title: "University Login")
    custom_auth.stubs(:indigenous?).returns(false)

    self.stubs(:logged_in_organization?).returns(false)
    assert_equal "Sign up", get_title_for_signup_form(nil)
    assert_equal "Sign up", get_title_for_signup_form(nil, true)
    assert_equal "Sign up with Password", get_title_for_signup_form(chronus_auth)
    assert_equal "Sign up with Email", get_title_for_signup_form(chronus_auth, true)
    assert_equal "Sign up with University Login", get_title_for_signup_form(custom_auth, false)
    assert_equal "Sign up with University Login", get_title_for_signup_form(custom_auth, true)

    self.stubs(:logged_in_organization?).returns(true)
    assert_equal "Sign up", get_title_for_signup_form(nil)
    assert_equal "Sign up", get_title_for_signup_form(chronus_auth)
    assert_equal "Sign up", get_title_for_signup_form(custom_auth, true)
  end

  def test_get_url_and_method_for_signup_form_when_program_invitation
    program_invitation = program_invitations(:student)
    signup_url, signup_method = get_url_and_method_for_signup_form(program_invitation, nil)
    assert_equal registrations_url(invite_code: program_invitation.code), signup_url
    assert_equal :post, signup_method
  end

  def test_get_url_and_method_for_signup_form_when_password
    member = members(:f_admin)
    password = Password.create!(member: member)
    signup_url, signup_method = get_url_and_method_for_signup_form(nil, password)
    assert_equal registration_url(member, reset_code: password.reset_code), signup_url
    assert_equal :patch, signup_method
  end
end