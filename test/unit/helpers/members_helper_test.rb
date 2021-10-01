require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/members_helper"

class MembersHelperTest < ActionView::TestCase
  include ProfileAnswersHelper
  include ProfileQuestionsHelper
  include RoleQuestionsHelper

  def setup
    super
    helper_setup
  end

  def test_get_basic_section_questions
    @current_organization = programs(:org_primary)
    profile_questions = @current_organization.profile_questions_with_email_and_name
    assert_equal @current_organization.sections.default_section.first, get_basic_section_questions(profile_questions.email_question)[:section]
    assert_equal @current_organization.sections.default_section.first, get_basic_section_questions([profile_questions.last])[:section]
    assert_equal @current_organization.sections.default_section.first, get_basic_section_questions([])[:section]
  end

  def test_render_mentoring_settings_section_false
    assert render_mentoring_settings_section(false)
  end

  def test_render_mentoring_settings_section_true
    assert render_mentoring_settings_section(true)
  end

  def test_get_availability_flash_and_scroll_to_id
    Program.any_instance.stubs(:consider_mentoring_mode?).returns(true)
    user = users(:f_mentor)
    set_availability_flash = ". Please set your availability for the selected mentoring mode(s)."
    assert_equal [nil, nil], get_availability_flash_and_scroll_to_id(user, true, true, false)

    user.mentoring_mode = User::MentoringMode::ONE_TIME_AND_ONGOING
    assert_equal [nil, nil], get_availability_flash_and_scroll_to_id(user, false, false, true)

    user.mentoring_mode = User::MentoringMode::ONE_TIME_AND_ONGOING
    assert_equal [set_availability_flash, "#settings_section_ongoing"], get_availability_flash_and_scroll_to_id(user, true, false, true)
    assert_equal [set_availability_flash, "#settings_section_onetime"], get_availability_flash_and_scroll_to_id(user, false, true, true)

    user.mentoring_mode = User::MentoringMode::ONGOING
    assert_equal [set_availability_flash, "#settings_section_ongoing"], get_availability_flash_and_scroll_to_id(user, true, false, true)
    assert_equal [nil, nil], get_availability_flash_and_scroll_to_id(user, false, true, true)
    assert_equal [nil, nil], get_availability_flash_and_scroll_to_id(user, false, false, true)

    user.mentoring_mode = User::MentoringMode::ONE_TIME
    assert_equal [set_availability_flash, "#settings_section_onetime"], get_availability_flash_and_scroll_to_id(user, false, true, true)
    assert_equal [nil, nil], get_availability_flash_and_scroll_to_id(user, true, false, true)
    assert_equal [nil, nil], get_availability_flash_and_scroll_to_id(user, false, false, true)
  end

  def test_get_member_edit_title
    assert_equal "Complete Your Mentor Profile", get_member_edit_title(MembersController::EditSection::PROFILE , "Mentor", members(:f_mentor))
    assert_equal "Welcome Good unique name", get_member_edit_title(MembersController::EditSection::SETTINGS , "Mentor", members(:f_mentor))
  end

  def test_link_to_member
    member1 = create_member(:last_name => "first_test_member")
    user11 = create_user(:member => member1, :role_names => ['student'], :program => programs(:albers))

    member2 = create_member(:last_name => "second_test_member")
    user21 = create_user(:member => member2, :role_names => ['student'], :program => programs(:albers))
    self.expects(:wob_member).at_least(0).returns(member2)

    fetch_role(:albers, :student).remove_permission('view_students')
    assert_false user11.can_view_students?
    self.expects(:program_view?).at_least(0).returns(false)

    assert_equal("Anonymous", link_to_member(member1, check_visibility?(member1)))

    user21.add_role(RoleConstants::MENTOR_NAME)
    set_response_text(link_to_member(member1, check_visibility?(member1)))
    assert_select "a[href=?]", member_path(member1), :text => member1.name

    fetch_role(:albers, :mentor).remove_permission('view_students')
    assert_equal("Anonymous", link_to_member(member1, check_visibility?(member1)))

    user12 = create_user(:member => member1, :role_names => ['student'], :program => programs(:moderated_program))
    assert_equal("Anonymous", link_to_member(member1.reload, check_visibility?(member1)))

    user22 = create_user(:member => member2, :role_names => ['student'], :program => programs(:moderated_program))
    self.expects(:wob_member).at_least(0).returns(member2.reload)
    set_response_text(link_to_member(member1, check_visibility?(member1)))
    assert_select "a[href=?]", member_path(member1), :text => member1.name

    fetch_role(:moderated_program, :student).remove_permission('view_students')
    assert_equal("Anonymous", link_to_member(member1, check_visibility?(member1)))
  end

  def test_get_member_groups_tab_details
    albers = programs(:albers)
    albers_mentor = users(:f_mentor)
    albers_student = users(:mkr_student)
    pbe = programs(:pbe)
    pbe_mentor = users(:f_mentor_pbe)
    pbe_student = users(:f_student_pbe)

    tab_details = get_member_groups_tab_details(albers, albers_mentor, albers_mentor.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)"], tab_details.collect{|filter_field| filter_field[:label] }
    assert_equal [true, false, false], tab_details.collect{|filter_field| filter_field[:active] }
    assert_equal [GroupsController::StatusFilters::Code::ONGOING, GroupsController::StatusFilters::Code::CLOSED, GroupsController::StatusFilters::Code::DRAFTED].collect {|number| member_path(albers_mentor.member, {tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: number, page: 1})}, tab_details.collect{|filter_field| filter_field[:url] }
    tab_details = get_member_groups_tab_details(albers, albers_student, albers_student.groups, GroupsController::StatusFilters::Code::CLOSED)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)"], tab_details.collect{|filter_field| filter_field[:label] }
    assert_equal [false, true, false], tab_details.collect{|filter_field| filter_field[:active] }
    assert_equal [GroupsController::StatusFilters::Code::ONGOING, GroupsController::StatusFilters::Code::CLOSED, GroupsController::StatusFilters::Code::DRAFTED].collect {|number| member_path(albers_student.member, {tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: number, page: 1})}, tab_details.collect{|filter_field| filter_field[:url] }

    role = albers.roles.for_mentoring.first
    role.add_permission(RolePermission::PROPOSE_GROUPS)
    role.reload

    tab_details = get_member_groups_tab_details(albers, albers_mentor, albers_mentor.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)"], tab_details.collect{|tab_detail| tab_detail[:label] }
    assert_equal [true, false, false], tab_details.collect{|tab_detail| tab_detail[:active] }
    assert_equal [GroupsController::StatusFilters::Code::ONGOING, GroupsController::StatusFilters::Code::CLOSED, GroupsController::StatusFilters::Code::DRAFTED].collect {|number| member_path(albers_mentor.member, {tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: number, page: 1})}, tab_details.collect{|tab_detail| tab_detail[:url] }

    tab_details = get_member_groups_tab_details(albers, albers_student, albers_student.groups, GroupsController::StatusFilters::Code::CLOSED)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)"], tab_details.collect{|tab_detail| tab_detail[:label] }
    assert_equal [false, true, false], tab_details.collect{|tab_detail| tab_detail[:active] }
    assert_equal [GroupsController::StatusFilters::Code::ONGOING, GroupsController::StatusFilters::Code::CLOSED, GroupsController::StatusFilters::Code::DRAFTED].collect {|number| member_path(albers_student.member, {tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: number, page: 1})}, tab_details.collect{|tab_detail| tab_detail[:url] }

    pbe.groups.where(status: [Group::Status::PROPOSED, Group::Status::REJECTED]).created_by(pbe_student).destroy_all

    tab_details = get_member_groups_tab_details(pbe, pbe_mentor, pbe_mentor.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)", "Available (0)", "Proposed (2)", "Rejected (1)", "Withdrawn (1)"], tab_details.collect{|tab_detail| tab_detail[:label] }
    assert_equal [true, false, false, false, false, false, false], tab_details.collect{|tab_detail| tab_detail[:active] }
    assert_equal [
      GroupsController::StatusFilters::Code::ONGOING,
      GroupsController::StatusFilters::Code::CLOSED,
      GroupsController::StatusFilters::Code::DRAFTED,
      GroupsController::StatusFilters::Code::PENDING,
      GroupsController::StatusFilters::Code::PROPOSED,
      GroupsController::StatusFilters::Code::REJECTED,
      GroupsController::StatusFilters::Code::WITHDRAWN
    ].collect {|number| member_path(pbe_mentor.member, {tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: number, page: 1})}, tab_details.collect{|tab_detail| tab_detail[:url] }

    pbe_mentor.groups.where(status: Group::Status::WITHDRAWN).destroy_all
    tab_details = get_member_groups_tab_details(pbe, pbe_mentor, pbe_mentor.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)", "Available (0)", "Proposed (2)", "Rejected (1)"], tab_details.collect{|tab_detail| tab_detail[:label] }

    pbe.groups.reload

    tab_details = get_member_groups_tab_details(pbe, pbe_student, pbe_student.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (1)", "Available (0)"], tab_details.collect{|tab_detail| tab_detail[:label] }

    pbe.groups.where(status: [Group::Status::PROPOSED, Group::Status::REJECTED]).destroy_all

    tab_details = get_member_groups_tab_details(pbe, pbe_mentor, pbe_mentor.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)", "Available (0)"], tab_details.collect{|tab_detail| tab_detail[:label] }    

    tab_details = get_member_groups_tab_details(pbe, pbe_student, pbe_student.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (1)", "Available (0)"], tab_details.collect{|tab_detail| tab_detail[:label] }

    role = pbe.roles.for_mentoring.first
    role.add_permission(RolePermission::PROPOSE_GROUPS)
    role.reload
    tab_details = get_member_groups_tab_details(pbe, pbe_mentor, pbe_mentor.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (0)", "Available (0)", "Proposed (0)", "Rejected (0)"], tab_details.collect{|tab_detail| tab_detail[:label] }
    tab_details = get_member_groups_tab_details(pbe, pbe_student, pbe_student.groups, GroupsController::StatusFilters::Code::ONGOING)
    assert_equal ["Ongoing (1)", "Closed (0)", "Drafted (1)", "Available (0)", "Proposed (0)", "Rejected (0)"], tab_details.collect{|tab_detail| tab_detail[:label] }
  end

  def test_need_profile_complete_sidebar
    @current_user = users(:f_mentor_student)
    assert need_profile_complete_sidebar?(@current_user)
    # Hide for the session
    session[UsersController::SessionHidingKey::PROFILE_COMPLETE_SIDEBAR] = true
    assert_false need_profile_complete_sidebar?(@current_user)
    # Hide forever
    session[UsersController::SessionHidingKey::PROFILE_COMPLETE_SIDEBAR] = nil
    assert need_profile_complete_sidebar?(@current_user)
    @current_user.hide_profile_completion_bar!
    assert_false need_profile_complete_sidebar?(@current_user)
  end

  def test_get_org_level_connection_status
    member = members(:f_admin)
    connection_status = get_org_level_connection_status(member)
    assert_equal User::ConnectionStatusForGA::NEVER, connection_status

    member = members(:f_student)
    connection_status = get_org_level_connection_status(member)
    assert_equal User::ConnectionStatusForGA::CURRENT, connection_status

    member = members(:student_4)
    connection_status = get_org_level_connection_status(member)
    assert_equal User::ConnectionStatusForGA::PAST, connection_status

    member = members(:foster_mentor2)
    connection_status = get_org_level_connection_status(member)
    assert_equal User::ConnectionStatusForGA::NA, connection_status
  end

  def test_remove_member_prompt
    @member = users(:f_mentor_student).member
    active_prompt = remove_member_prompt(@member)
    assert_equal active_prompt, ["<div class=\"help_text\">You are about to remove Mentor Studenter from the programs. Did you intend to suspend the membership instead?</div>", true]
    @member.state = Member::Status::SUSPENDED
    assert_equal @member.state, Member::Status::SUSPENDED
    suspended_prompt = remove_member_prompt(@member)
    assert_equal suspended_prompt,["<div class=\"help_text\">You are about to remove Mentor Studenter from the programs.</div>", false]
  end

  def test_render_section_questions_xhr
    current_user_is :f_mentor
    section = sections(:sections_3)
    @profile_member = :f_mentor
    expended = true
    last_section = false
    result_html = render_section_questions_xhr(section, expended, last_section)
    assert_match /collapsible_section_content_#{section.id}/, result_html
    assert_match /fill_section_profile_detail\.js\?last_section=false/, result_html
  end

  def test_edit_tab_title
    assert_select to_html(edit_tab_title(MembersController::Tabs::PROFILE)), "span.m-r-xxs.m-l-xs.hidden-xs" , :text=>"Profile"
    assert_select to_html(edit_tab_title(MembersController::Tabs::PROFILE)), "div.visible-xs" , :text=>"Profile"
    assert_match /fa-user/ , edit_tab_title(MembersController::Tabs::PROFILE)
    assert_no_match /fa-bell/ , edit_tab_title(MembersController::Tabs::PROFILE)
    assert_no_match /fa-cog/ , edit_tab_title(MembersController::Tabs::PROFILE)

    assert_select to_html(edit_tab_title(MembersController::Tabs::SETTINGS)), "span.m-r-xxs.m-l-xs.hidden-xs" , :text=>"Settings"
    assert_select to_html(edit_tab_title(MembersController::Tabs::SETTINGS)), "div.visible-xs" , :text=>"Settings"
    assert_match /fa-cog/ , edit_tab_title(MembersController::Tabs::SETTINGS)
    assert_no_match /fa-bell/ , edit_tab_title(MembersController::Tabs::SETTINGS)
    assert_no_match /fa-user/ , edit_tab_title(MembersController::Tabs::SETTINGS)
    assert_select to_html(edit_tab_title(MembersController::Tabs::NOTIFICATIONS)), "span.m-r-xxs.m-l-xs.hidden-xs" , :text=>"Notifications"
    assert_select to_html(edit_tab_title(MembersController::Tabs::NOTIFICATIONS)), "div.visible-xs" , :text=>"Notifications"
    assert_match /fa-bell/ , edit_tab_title(MembersController::Tabs::NOTIFICATIONS)
    assert_no_match /fa-cog/ , edit_tab_title(MembersController::Tabs::NOTIFICATIONS)
    assert_no_match /fa-user/ , edit_tab_title(MembersController::Tabs::NOTIFICATIONS)
  end

  def test_current_notification_setting_values
    @profile_user = users(:f_admin)
    notification_settings = UserNotificationSetting.find_or_initialize_by(:notification_setting_name=>UserNotificationSetting::SettingNames::END_USER_COMMUNICATION ,:user_id=>@profile_user.id)
    notification_settings.update_attributes(:disabled => true)
    notification_settings = UserNotificationSetting.find_or_initialize_by(:notification_setting_name=>UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT ,:user_id=>@profile_user.id)
    notification_settings.update_attributes(:disabled => false)
    a = current_notification_settting_values(@profile_user)
    assert a[UserNotificationSetting::SettingNames::END_USER_COMMUNICATION]
    assert_false a[UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT]
    assert_false a[UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS]
  end

  def test_render_default_questions
    admin = members(:f_admin)
    admin_user = users(:f_admin)
    admin_2 = members(:ram)
    admin_user_2 = users(:ram)
    member = members(:f_student)
    member_user = users(:f_student)
    org = programs(:org_primary)
    program = programs(:albers)
    form = mock()
    form.stubs(:label).returns("")
    form.stubs(:input).returns("")
    form.stubs(:hidden_field).returns("")
    @current_organization = programs(:org_primary)

    # Case 1: admin_2 editing admin's profile

    current_user_is admin_user_2
    self.stubs(:wob_member).returns(admin_2)
    self.stubs(:current_user_or_member).returns(admin_user_2)
    self.stubs(:current_user).returns(admin_user_2)
    form.stubs(:object).returns(admin)
    grouped_role_questions = program.role_questions_for(admin_user.role_names, user: admin_user_2, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    options = { skip_validation_hash: true, disable: {} }
    options[:disable][@current_organization.name_question.id] = options[:disable][@current_organization.email_question.id] = disable_name_or_email_field(admin)
    content, skip_validation_hash = render_default_questions(admin_user, grouped_role_questions, form, options)

    assert_match /Name/, content
    assert_match /Email/, content
    assert_false skip_validation_hash[ProfileQuestion::Type::NAME]
    assert_false skip_validation_hash[ProfileQuestion::Type::EMAIL]

    # Case 2: admin editing member's profile

    current_user_is admin_user
    self.stubs(:wob_member).returns(admin)
    self.stubs(:current_user_or_member).returns(admin_user)
    self.stubs(:current_user).returns(admin_user)
    form.stubs(:object).returns(member)
    grouped_role_questions = program.role_questions_for(member_user.role_names, user: admin_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    options[:disable][@current_organization.name_question.id] = options[:disable][@current_organization.email_question.id] = disable_name_or_email_field(member)
    content, skip_validation_hash = render_default_questions(member_user, grouped_role_questions, form, options)

    assert_match /Name \*/, content
    assert_match /Email \*/, content
    assert_match /This field will be visible to user, users with whom they are connected, and administrators./, content
    assert_false skip_validation_hash[ProfileQuestion::Type::NAME]
    assert_false skip_validation_hash[ProfileQuestion::Type::EMAIL]

    # Case 3: member editing member's profile

    current_user_is member_user
    self.stubs(:wob_member).returns(member)
    self.stubs(:current_user_or_member).returns(member_user)
    self.stubs(:current_user).returns(member_user)
    form.stubs(:object).returns(member)
    grouped_role_questions = program.role_questions_for(member_user.role_names, user: member_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    options[:disable][@current_organization.name_question.id] = options[:disable][@current_organization.email_question.id] = disable_name_or_email_field(member)
    content, skip_validation_hash = render_default_questions(member_user, grouped_role_questions, form, options)

    assert_match /Name \*/, content
    assert_match /Email \*/, content
    assert_match /This field will be visible to you, users with whom you are connected, and administrators./, content
    assert_false skip_validation_hash[ProfileQuestion::Type::NAME]
    assert_false skip_validation_hash[ProfileQuestion::Type::EMAIL]

    org.default_questions.each do |question|
      question.role_questions.each do |role_question|
        role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
      end
    end
    # Default questions are admin-only viewable

    # Case 4: admin_2 editing admin's profile

    current_user_is admin_user_2
    self.stubs(:wob_member).returns(admin_2)
    self.stubs(:current_user_or_member).returns(admin_user_2)
    self.stubs(:current_user).returns(admin_user_2)
    form.stubs(:object).returns(admin)
    grouped_role_questions = program.role_questions_for(admin_user.role_names, user: admin_user_2, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    options[:disable][@current_organization.name_question.id] = options[:disable][@current_organization.email_question.id] = disable_name_or_email_field(admin)
    content, skip_validation_hash = render_default_questions(admin_user, grouped_role_questions, form, options)

    assert_match /Name/, content
    assert_match /Email/, content
    assert_false skip_validation_hash[ProfileQuestion::Type::NAME]
    assert_false skip_validation_hash[ProfileQuestion::Type::EMAIL]

    # Case 5: admin editing member's profile

    current_user_is admin_user
    self.stubs(:wob_member).returns(admin)
    self.stubs(:current_user_or_member).returns(admin_user)
    self.stubs(:current_user).returns(admin_user)
    form.stubs(:object).returns(member)
    grouped_role_questions = program.role_questions_for(member_user.role_names, user: admin_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    options[:disable][@current_organization.name_question.id] = options[:disable][@current_organization.email_question.id] = disable_name_or_email_field(member)
    content, skip_validation_hash = render_default_questions(member_user, grouped_role_questions, form, options)

    assert_match /Name/, content
    assert_match /Email/, content
    assert_equal 4, content.scan(/This field will be visible only to the program administrators/).size
    assert_false skip_validation_hash[ProfileQuestion::Type::NAME]
    assert_false skip_validation_hash[ProfileQuestion::Type::EMAIL]

    # Case 6: member editing member's profile

    current_user_is member_user
    self.stubs(:wob_member).returns(member)
    self.stubs(:current_user_or_member).returns(member_user)
    self.stubs(:current_user).returns(member_user)
    form.stubs(:object).returns(member)
    grouped_role_questions = program.role_questions_for(member_user.role_names, user: member_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    options[:disable][@current_organization.name_question.id] = options[:disable][@current_organization.email_question.id] = disable_name_or_email_field(member)
    content, skip_validation_hash = render_default_questions(member_user, grouped_role_questions, form, options)
    assert_match /Name/, content
    assert_no_match(/Email/, content)
    assert skip_validation_hash[ProfileQuestion::Type::NAME]
    assert skip_validation_hash[ProfileQuestion::Type::EMAIL]

    # Membership form scenarios
    org.default_questions.each do |question|
      question.role_questions.each do |role_question|
        role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
      end
    end
    membership_request = membership_requests(:membership_request_0)
    form.stubs(:object).returns(membership_request)
    grouped_role_questions = membership_request.program.role_questions.where(profile_question_id: @current_organization.default_question_ids).group_by(&:profile_question_id)

    # Case 7: New request when default questions are viewable and editable

    options = { membership_form: true, disable: {} }
    options[:disable][org.name_question.id] = false
    options[:disable][org.email_question.id] = true
    membership_request = membership_requests(:membership_request_0)
    self.stubs(:current_user).returns(nil)
    self.stubs(:current_user_or_member).returns(nil)

    content = render_default_questions(membership_request, grouped_role_questions, form, options)
    assert_match /Name \*/, content
    assert_match(/Email \*/, content)
    assert_equal 4, content.scan(/This field will be visible to you and administrators./).size

    # Case 8: Edit request when default questions are viewable and editable

    options = { membership_form: true, disable: {} }
    options[:disable][org.name_question.id] = false
    options[:disable][org.email_question.id] = false
    membership_request = membership_requests(:membership_request_0)
    self.stubs(:wob_member).returns(admin_user)
    self.stubs(:current_user).returns(admin_user)
    self.stubs(:current_user_or_member).returns(admin_user)

    content = render_default_questions(membership_request, grouped_role_questions, form, options)
    assert_match /Name \*/, content
    assert_match(/Email \*/, content)
    assert_equal 4, content.scan(/This field will be visible to user and administrators./).size

    org.default_questions.each do |question|
      question.role_questions.each do |role_question|
        role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
      end
    end

    # Case 9: New request when default questions are admin only viewable and editable

    options = { membership_form: true, disable: {} }
    options[:disable][org.name_question.id] = false
    options[:disable][org.email_question.id] = true
    membership_request = membership_requests(:membership_request_0)
    self.stubs(:current_user).returns(nil)
    self.stubs(:current_user_or_member).returns(nil)
      @is_self_view = true

    content = render_default_questions(membership_request, grouped_role_questions, form, options)
    assert_match /Name/, content
    assert_match(/Email/, content)
    assert_no_match(/This field will be visible to you and administrators./, content)

    # Case 10: Edit request when default questions are admin only viewable and editable

    options = { membership_form: true, disable: {} }
    options[:disable][org.name_question.id] = false
    options[:disable][org.email_question.id] = false
    membership_request = membership_requests(:membership_request_0)
    self.stubs(:wob_member).returns(admin_user)
    self.stubs(:current_user).returns(admin_user)
    self.stubs(:current_user_or_member).returns(admin_user)

    content = render_default_questions(membership_request, grouped_role_questions, form, options)
    assert_match /Name/, content
    assert_match(/Email/, content)
    assert_no_match(/This field will be visible to user and administrators./, content)
  end

  def test_get_first_profile_section
    @current_organization = programs(:org_primary)
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::TEXT, required: 1)
    q1 = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::TEXT, required: 1)
    pending_profile_questions = programs(:albers).required_profile_questions_except_default_for(users(:f_mentor).role_names)
    assert_equal_hash get_first_profile_section(pending_profile_questions), {:section=> q.section, :section_title=>q.section.title, :questions=>[q,q1], :section_id=>q.section.id, :file_present=>false}

    q2 = create_question(:role_names => [RoleConstants::STUDENT_NAME], :question_type => ProfileQuestion::Type::TEXT, required: 1)
    q3 = create_question(:role_names => [RoleConstants::STUDENT_NAME], :question_type => ProfileQuestion::Type::TEXT, required: 1)
    pending_profile_questions = programs(:albers).required_profile_questions_except_default_for(users(:f_student).role_names)
    assert_equal_hash get_first_profile_section(pending_profile_questions), {:section=> q2.section, :section_title=>q2.section.title, :questions=>[q2,q3], :section_id=>q2.section.id, :file_present=>false}
  end

  def test_get_green_and_gray_profile_sections
    all_profile_section_ids = [1,2,3,4]
    profile_questions_per_section = {1 => [2]}
    sections_filled = [1.to_s]
    assert_equal [[1,2,3,4], []], get_green_and_gray_profile_sections(all_profile_section_ids, profile_questions_per_section, sections_filled)

    all_profile_section_ids = [2,3,MembersController::EditSection::MENTORING_SETTINGS]
    profile_questions_per_section = {2 => [2]}
    assert_equal [[3], [2, MembersController::EditSection::MENTORING_SETTINGS]], get_green_and_gray_profile_sections(all_profile_section_ids, profile_questions_per_section, sections_filled)

    all_profile_section_ids = [2,3,MembersController::EditSection::MENTORING_SETTINGS]
    profile_questions_per_section = {2 => [2], 3 => [4]}
    assert_equal [[], [2, 3, MembersController::EditSection::MENTORING_SETTINGS]], get_green_and_gray_profile_sections(all_profile_section_ids, profile_questions_per_section, sections_filled)

    all_profile_section_ids = [2,3,MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS]
    profile_questions_per_section = {2 => [2], 3 => [4]}
    sections_filled = [2.to_s,3.to_s,MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS]
    assert_equal [[2, 3, MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS], []], get_green_and_gray_profile_sections(all_profile_section_ids, profile_questions_per_section, sections_filled)

    all_profile_section_ids = [2,3,MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS]
    profile_questions_per_section = {2 => [2], 3 => [4]}
    sections_filled = [MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS]
    assert_equal [[MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS], [2, 3]], get_green_and_gray_profile_sections(all_profile_section_ids, profile_questions_per_section, sections_filled)

    all_profile_section_ids = [2,3,MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS]
    profile_questions_per_section = {}
    sections_filled = [MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS]
    assert_equal [[2, 3, MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS], []], get_green_and_gray_profile_sections(all_profile_section_ids, profile_questions_per_section, sections_filled)

  end

  def test_get_first_time_profile_section_title
    all_profile_section_titles_hash = {2 => "Section 1", 3 => "Section 2"}
    section_id = MembersController::EditSection::MENTORING_SETTINGS
    assert_equal "feature.profile.label.mentoring_preferences".translate(:Mentoring => _Mentoring), get_first_time_profile_section_title(all_profile_section_titles_hash, section_id)

    section_id = MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS
    assert_equal "program_settings_strings.tab.calendar".translate, get_first_time_profile_section_title(all_profile_section_titles_hash, section_id)

    section_id = 2
    assert_equal "Section 1", get_first_time_profile_section_title(all_profile_section_titles_hash, section_id)

    section_id = 3
    assert_equal "Section 2", get_first_time_profile_section_title(all_profile_section_titles_hash, section_id)
  end

  def test_get_guidance_popup_action_label
    src = OneTimeFlag::Flags::Popups::MENTEE_GUIDANCE_POPUP_TAG
    assert_equal 'verify_organization_page.label.get_started'.translate, get_guidance_popup_action_label(src)
    
    src = nil
    assert_equal "feature.user.label.find_mentor".translate(a_mentor: _a_mentor), get_guidance_popup_action_label(src)

    src = EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE
    assert_equal "feature.user.label.find_mentor".translate(a_mentor: _a_mentor), get_guidance_popup_action_label(src)
  end

  def test_render_add_role_without_approval
    program = programs(:albers)
    mentor_user = users(:f_mentor)
    mentee_user = users(:f_student)
    student_role = roles("#{program.id}_student")
    mentor_role = roles("#{program.id}_mentor")
    mentor_user.stubs(:get_applicable_role_to_add_without_approval).returns(nil)
    mentee_user.stubs(:get_applicable_role_to_add_without_approval).returns(nil)
    assert_nil render_add_role_without_approval(mentor_user, program)
    assert_nil render_add_role_without_approval(mentee_user, program)

    mentor_user.stubs(:get_applicable_role_to_add_without_approval).returns(student_role)
    content = render_add_role_without_approval(mentor_user, program)
    assert_select_helper_function_block "div.text-center", content do
      assert_select "p", "Would you like to join the program as a student as well?"
      assert_select "u" do
        assert_select "a[href='javascript:void(0)']", text: "Click here"
      end
    end

    mentee_user.stubs(:get_applicable_role_to_add_without_approval).returns(mentor_role)
    content = render_add_role_without_approval(mentee_user, program)
    assert_select_helper_function_block "div.text-center", content do
      assert_select "p", "Would you like to join the program as a mentor as well?"
      assert_select "u" do
        assert_select "a[href='javascript:void(0)']", text: "Click here"
      end
    end
  end

  private

  def _mentor
    "mentor"
  end

  def _a_mentor
    "a_mentor"  
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

  def _Mentoring
    "Mentoring"
  end

  def _mentoring
    "mentoring"
  end

  def _program
    "program"
  end

  def simple_form_for(obj, options, &block)
    yield
  end
end