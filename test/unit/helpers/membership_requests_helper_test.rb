require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/membership_requests_helper"
require_relative "./../../../app/helpers/profile_answers_helper"

class MembershipRequestsHelperTest < ActionView::TestCase
  include TranslationsService

  def test_actions_for_pending_request
    req = create_membership_request
    assert(req.pending?)
    self.expects(:render).with(partial: 'membership_requests/response_actions', locals: { membership_request: req })
    response_actions(req, users(:f_admin))
  end

  def test_status_for_accepted_request
    req = create_membership_request
    req.admin = users(:f_admin)
    req.status = MembershipRequest::Status::ACCEPTED
    req.accepted_as = RoleConstants::STUDENT_NAME
    req.save!
    assert(req.reload.accepted?)

    set_response_text(membership_request_status(req, req.admin))
    assert_select "span.cui_acceptance_info", text: "Accepted"
  end

  def test_status_for_rejected_request
    req = create_membership_request
    req.admin = users(:f_admin)
    req.status = MembershipRequest::Status::REJECTED
    req.response_text = "Whatever"
    req.save!
    assert(req.reload.rejected?)

    set_response_text(membership_request_status(req, req.admin))
    assert_select "span.cui_rejection_info", text: "Rejected"
  end

  def test_membership_request_status_row_values_for_accepted_request
    req = create_membership_request
    req.admin = users(:f_admin)
    req.status = MembershipRequest::Status::ACCEPTED
    req.accepted_as = RoleConstants::STUDENT_NAME
    req.save!
    assert req.reload.accepted?
    content = membership_request_status_row_values(req, 'pending')
    assert_blank content

    content = membership_request_status_row_values(req, 'accepted')
    set_response_text(content)
    assert_select "td", text: 'Freakin Admin (Administrator)'
    assert_select "td", text: 'less than a minute ago'
    assert_select "td", text: 'Student'

    req.status = MembershipRequest::Status::REJECTED
    req.accepted_as = nil
    req.response_text = "Whatever"
    req.save!
    content = membership_request_status_row_values(req, 'rejected')
    set_response_text(content)
    assert_select "td", text: 'Freakin Admin (Administrator)'
    assert_select "td", text: 'less than a minute ago'
    assert_select "td", text: 'Whatever'

  end

  def test_listing_display_name
    @current_organization = programs(:org_primary)
    member = members(:f_mentor)
    program_1 = programs(:albers)
    program_2 = programs(:no_mentor_request_program)
    organization_admin = members(:f_admin)
    program_1_only_admin = members(:ram)
    program_2_only_admin = members(:no_mreq_admin)
    assert programs(:org_primary).org_profiles_enabled?
    assert_false member.dormant?

    membership_request = create_membership_request(member: member, roles: [RoleConstants::STUDENT_NAME], program: program_1)
    assert_equal "<a class=\"nickname\" title=\"#{member.name}\" href=\"/p/albers/members/#{member.id}\">#{member.name}</a>", listing_display_name(membership_request, organization_admin)
    assert_equal "<a class=\"nickname\" title=\"#{member.name}\" href=\"/p/albers/members/#{member.id}\">#{member.name}</a>", listing_display_name(membership_request, program_1_only_admin)

    membership_request = create_membership_request(member: member, roles: [RoleConstants::STUDENT_NAME], program: program_2)
    assert_equal "<a class=\"nickname\" title=\"#{member.name}\" href=\"/members/#{member.id}\">#{member.name}</a>", listing_display_name(membership_request, organization_admin)
    assert_equal "#{member.name} (<a href=\"mailto:#{member.email}\">#{member.email}</a>)", listing_display_name(membership_request, program_2_only_admin)

    member.stubs(:dormant?).returns(true)
    Organization.any_instance.stubs(:org_profiles_enabled?).returns(false)
    assert_equal "#{member.name} (<a href=\"mailto:#{member.email}\">#{member.email}</a>)", listing_display_name(membership_request, organization_admin)
    assert_equal "#{member.name} (<a href=\"mailto:#{member.email}\">#{member.email}</a>)", listing_display_name(membership_request, program_2_only_admin)
  end

  def test_membership_user_info_for_listing
    current_program_is programs(:albers)
    membership_request = MembershipRequest.last
    members(:f_admin)
    row = membership_user_info_for_listing(membership_request, members(:f_admin), programs(:albers))
    assert_equal "<td><a content_method=\"name\" class=\"nickname\" title=\"mentor_l chronus\" href=\"/p/albers/members/36\">mentor_l</a></td><td><a content_method=\"name\" class=\"nickname\" title=\"mentor_l chronus\" href=\"/p/albers/members/36\">chronus</a></td><td><a href=\"mailto:mentor_11@example.com\">mentor_11@example.com</a></td>", row
    row2 = membership_user_info_for_listing(membership_request, members(:ram), programs(:albers))
    assert_equal "<td><a content_method=\"name\" class=\"nickname\" title=\"mentor_l chronus\" href=\"/p/albers/members/36\">mentor_l</a></td><td><a content_method=\"name\" class=\"nickname\" title=\"mentor_l chronus\" href=\"/p/albers/members/36\">chronus</a></td><td><a href=\"mailto:mentor_11@example.com\">mentor_11@example.com</a></td>", row2
  end

  def test_get_membership_question_id
    detail = {}
    detail[:id] = profile_questions(:education_q).id
    assert_equal "#edu_cur_list_#{detail[:id]}", get_membership_question_id(detail)
    detail[:id] = profile_questions(:experience_q).id
    assert_equal "#exp_cur_list_#{detail[:id]}", get_membership_question_id(detail)
    detail[:id] = profile_questions(:publication_q).id
    assert_equal "#publication_cur_list_#{detail[:id]}", get_membership_question_id(detail)
    detail[:id] = profile_questions(:manager_q).id
    assert_equal "#manager_cur_list_#{detail[:id]}", get_membership_question_id(detail)
    detail[:id] = profile_questions(:mentor_file_upload_q).id
    assert_equal "#profile_answers_#{detail[:id]}", get_membership_question_id(detail)
    profile_questions(:student_string_q).update_attributes(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 3)
    profile_questions(:student_string_q).question_choices.create!(text: "Some info")
    detail[:id] = profile_questions(:student_string_q).id
    assert_equal "#profile_answers_#{detail[:id]}_0", get_membership_question_id(detail)
  end

  def test_get_membership_request_title_header
    q1 = profile_questions(:education_q)
    q2 = profile_questions(:experience_q)
    questions = [q1, q2]
    content = get_membership_request_title_header(questions, 'id', 'asc', 'pending')
    set_response_text(content)
    assert_select "th", text: q1.question_text
    assert_select "th", text: q2.question_text
  end

  def test_membership_user_info_header
    content = membership_user_info_header('last_name', 'desc')
    css_class = "pointer cjs_sortable_element truncate-with-ellipsis whitespace-nowrap"
    set_response_text(content)
    assert_select "th[data-sort=?][class=?]", "first_name", "sort_both #{css_class}", text: 'First name'
    assert_select "th[data-sort=?][class=?]", "last_name", "sort_desc #{css_class}", text: 'Last name'
    assert_select "th[data-sort=?][class=?]", "email", "sort_both #{css_class}", text: 'Email'

    content = membership_user_info_header('first_name', 'asc')
    set_response_text(content)
    assert_select "th[data-sort=?][class=?]", "first_name", "sort_asc #{css_class}", text: 'First name'
    assert_select "th[data-sort=?][class=?]", "last_name", "sort_both #{css_class}", text: 'Last name'
    assert_select "th[data-sort=?][class=?]", "email", "sort_both #{css_class}", text: 'Email'
  end

  def test_membership_request_status_header
    assert_blank membership_request_status_header('pending')
    assert_equal "<th class=\"truncate-with-ellipsis whitespace-nowrap\" data-toggle=\"tooltip\" data-title=\"Accepted By\">Accepted By</th><th class=\"truncate-with-ellipsis whitespace-nowrap\" data-toggle=\"tooltip\" data-title=\"Accepted on\">Accepted on</th><th class=\"truncate-with-ellipsis whitespace-nowrap\" data-toggle=\"tooltip\" data-title=\"Accepted Role\">Accepted Role</th>", membership_request_status_header('accepted')
    assert_equal "<th class=\"truncate-with-ellipsis whitespace-nowrap\" data-toggle=\"tooltip\" data-title=\"Rejected By\">Rejected By</th><th class=\"truncate-with-ellipsis whitespace-nowrap\" data-toggle=\"tooltip\" data-title=\"Rejected on\">Rejected on</th><th class=\"truncate-with-ellipsis whitespace-nowrap\" data-toggle=\"tooltip\" data-title=\"Reason for rejection\">Reason for rejection</th>", membership_request_status_header('rejected')
  end

  def test_get_membership_request_row_values
    req = create_membership_request
    q1 = profile_questions(:profile_questions_10)
    req.member.profile_answers.create!(answer_value: {answer_text: "Accounting", question: q1}, profile_question_id: q1.id)
    req.reload
    MembershipRequestsHelperTest.any_instance.expects(:get_user_answer).times(1)
    MembershipRequestsHelperTest.any_instance.expects(:format_user_answers).times(1).returns('Accounting')
    content = get_membership_request_row_values(req, [q1], 'pending')
    set_response_text(content)
    assert_select "td#answer_#{req.id}_#{q1.id}", text: 'Accounting'
  end

  def test_format_membership_request_answers
    req = create_membership_request
    q1 = profile_questions(:profile_questions_10)
    req.member.profile_answers.create!(answer_value: {answer_text: "Accounting", question: q1}, profile_question_id: q1.id)
    profile_answers = req.member.profile_answers.group_by(&:profile_question_id)
    MembershipRequestsHelperTest.any_instance.expects(:get_user_answer).times(1)
    MembershipRequestsHelperTest.any_instance.expects(:format_user_answers).times(1)
    format_membership_request_answers(q1, profile_answers)

    MembershipRequestsHelperTest.any_instance.expects(:get_user_answer).times(0)
    MembershipRequestsHelperTest.any_instance.expects(:format_user_answers).times(0)
    assert_nil format_membership_request_answers(profile_questions(:profile_questions_1), profile_answers)
  end

  def test_display_membership_instruction
    instruction_text = display_membership_instruction("Instruction", nil)
    assert_select_helper_function_block("div", instruction_text, class: "alert alert-info") do
      assert_select("div", class: "media-left p-r-0")
      assert_select("i", class: "fa fa-info-circle")
      assert_select("div", class: "media-body", text: "<p>Instruction</p>")
    end

    instruction_text = display_membership_instruction("Instruction", true)
    assert_select_helper_function_block("div", instruction_text, class: "alert alert-info") do
      assert_select("div", class: "media-left p-r-0")
      assert_select("i", class: "fa fa-info-circle")
      assert_select("div", class: "media-body", text: "<p>Instruction</p>")
    end

    instruction_text = display_membership_instruction(nil, true)
    assert_select_helper_function_block("div", instruction_text, class: "alert alert-info") do
      assert_select("div", class: "media-left p-r-0")
      assert_select("i", class: "fa fa-info-circle")
      assert_select("div", class: "media-body", text: "Please click on the button below to submit your application.")
    end

    instruction_text = display_membership_instruction(nil, false)
    assert_select_helper_function_block("div", instruction_text, class: "alert alert-info") do
      assert_select("div", class: "media-left p-r-0")
      assert_select("i", class: "fa fa-info-circle")
      assert_select("div", class: "media-body", text: "Please complete the registration form provided below. Fields marked with asterisks (“*”) are mandatory. You can edit your profile anytime after signing up.")
    end
  end

  def test_construct_role_options
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    roles = @current_program.roles.allowing_join_now
    roles.each { |role| role.update_attributes!(description: "") }
    content = construct_role_options(roles, false)
    assert_match "<input type=\"radio\" name=\"roles\" id=\"roles_mentor\" value=\"mentor\" class=\"cjs_signup_role \" />", content
    assert_match "<input type=\"radio\" name=\"roles\" id=\"roles_student\" value=\"student\" class=\"cjs_signup_role \" />", content
    assert_match "Mentor</span>", content
    assert_match "are professionals who guide and advise students in their career paths to help them succeed. A mentor's role is to inspire, encourage, and support their students.", content
    assert_match "are students who want guidance and advice to further their careers and to be successful.  can expect to strengthen and build their networks, and gain the skills and confidence necessary to excel.", content
    assert_match "Student</span>", content
    assert_no_match(/description of mentor role/, content)
    assert_no_match(/input type=\"radio\" name=\"roles\" id=\"roles_mentor__student\" value=\"mentor, student\" class=\"cjs_signup_role \" \/>/, content)
    assert_no_match(/span class=\"strong has-before-2\">Mentor and Student/, content)

    mentor_role = roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentor_role.update_attributes(description: "description of mentor role")
    content = construct_role_options(roles.reload, false)
    assert_match "description of mentor role", content

    content = construct_role_options(roles, true)
    assert_match "<input type=\"radio\" name=\"roles\" id=\"roles_mentor__student\" value=\"mentor, student\" class=\"cjs_signup_role \" />", content
    assert_match "Mentor and Student</span>", content
  end

  def test_construct_role_options_third_role
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    role = [@current_program.get_role("user")]

    content = construct_role_options(role, false)
    assert_match "type=\"radio\" name=\"roles\" id=\"roles_user\" value=\"user\" class=\"cjs_signup_role hide\"", content
    assert_match "User</span>", content
  end

  def test_construct_role_options_for_single_role
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    roles = @current_program.roles.allowing_join_now.limit(1)
    assert roles && roles.length == 1

    content = construct_role_options(roles, false)
    assert_match "type=\"radio\" name=\"roles\" id=\"roles_mentor\" value=\"mentor\" class=\"cjs_signup_role hide\"", content
    assert_match "Mentor</span>", content
  end

  def test_construct_role_options_for_single_role_and_allow_multiple_roles
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    roles = @current_program.roles.allowing_join_now.limit(1)
    assert roles && roles.length == 1

    content = construct_role_options(roles, true)
    assert_match "type=\"radio\" name=\"roles\" id=\"roles_mentor\" value=\"mentor\" class=\"cjs_signup_role hide\"", content
    assert_match "<span class=\"font-bold m-l-sm\">Mentor</span>", content
  end

  def test_verified_using_sso_text
    @current_organization = programs(:org_primary)
    auth_config = @current_organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    assert_nil verified_using_sso_text

    session[:new_custom_auth_user] = { @current_organization.id => "12345", auth_config_id: auth_config.id }
    assert_nil verified_using_sso_text

    session[:new_custom_auth_user][:is_uid_email] = true
    assert_match /Verified as.*12345/, verified_using_sso_text

    session[:new_user_import_data] = { @current_organization.id => { "Member" => { "email" => "sun@mail.com" } } }
    assert_match(/Verified as.*sun@mail.com/, verified_using_sso_text)

    session[:new_user_import_data][@current_organization.id]["Member"] = { "first_name" => "Sundar", "last_name" => "Raja" }
    assert_match(/Verified as.*Sundar Raja/, verified_using_sso_text)
  end

  def test_get_page_action_for_join_instruction
    page_action = get_page_action_for_join_instruction
    assert_equal "Update Join Instructions", page_action[:label]
    assert_equal "btn btn-primary btn-large", page_action[:class]
    assert_equal %Q[jQueryShowQtip(null, null, '#{get_instruction_form_membership_request_instructions_path}')], page_action[:js]
  end

  def test_membership_requests_bulk_actions
    content = membership_requests_bulk_actions(MembershipRequest::FilterStatus::PENDING)
    assert_select_helper_function "a.cjs_membership_request_bulk_update", content, count: 3
    assert_select_helper_function "a.cjs_bulk_send_message", content
    assert_select_helper_function "a.cjs_membership_request_export", content, count: 2
    assert_select_helper_function "a.cjs_membership_request_bulk_update", content, text: "Accept", data_url: new_bulk_action_membership_requests_path(status: MembershipRequest::Status::ACCEPTED)
    assert_select_helper_function "a.cjs_membership_request_bulk_update", content, text: "Reject", data_url: new_bulk_action_membership_requests_path(status: MembershipRequest::Status::REJECTED)
    assert_select_helper_function "a.cjs_membership_request_bulk_update", content, text: "Ignore", data_url: new_bulk_action_membership_requests_path
    assert_select_helper_function "a.cjs_bulk_send_message", content, text: "Send Message", data_url: new_bulk_admin_message_admin_messages_path
    assert_select_helper_function "a.cjs_membership_request_export", content, text: "Export as CSV", data_url: export_membership_requests_path(tab: MembershipRequest::FilterStatus::PENDING, format: :csv)
    assert_select_helper_function "a.cjs_membership_request_export", content, text: "Export as PDF", data_url: export_membership_requests_path(tab: MembershipRequest::FilterStatus::PENDING, format: :js)

    content = membership_requests_bulk_actions(MembershipRequest::FilterStatus::ACCEPTED)
    assert_select_helper_function "a.cjs_membership_request_bulk_update", content, count: 0
    assert_select_helper_function "a.cjs_bulk_send_message", content, count: 0
    assert_select_helper_function "a.cjs_membership_request_export", content, count: 2
    assert_select_helper_function "a.cjs_membership_request_export", content, text: "Export as CSV", data_url: export_membership_requests_path(tab: MembershipRequest::FilterStatus::ACCEPTED, format: :csv)
    assert_select_helper_function "a.cjs_membership_request_export", content, text: "Export as PDF", data_url: export_membership_requests_path(tab: MembershipRequest::FilterStatus::ACCEPTED, format: :js)
  end

  def test_membership_requests_listing_params
    data = {
      sort_field: "first_name",
      sort_order: "desc",
      filters: "something"
    }
    assert_equal_hash( { filters: "something" }, membership_requests_listing_filter_params(data))
    assert_equal_hash( { sort: "first_name", order: "desc" }, membership_requests_listing_non_filter_params(data))
    assert_equal_hash( { sort: "first_name", order: "desc", items_per_page: 10 }, membership_requests_listing_non_filter_params(data, 10))
    assert_equal_hash( { sort: "first_name", order: "desc" }, membership_requests_listing_non_filter_params(data))
    assert_equal_hash( { }, membership_requests_listing_filter_params())
  end

  private
  # Stub the mentor and mentee name helpers
  def _mentor
    "mentor"
  end

  def _mentee
    "student"
  end

  def _mentors
    "mentors"
  end

  def _mentees
    "students"
  end

  def _Mentee
    "Student"
  end

  def _Mentor
    "Mentor"
  end
end