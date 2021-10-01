require_relative './../../test_helper.rb'

class UsersHelperTest < ActionView::TestCase
  include UserFavoritesHelper
  include ProfileAnswersHelper
  include GroupsHelper
  include ProgramsHelper
  include MeetingsHelper
  include AutoCompleteMacrosHelper
  include PreferencesHelper

  def setup
    super
    helper_setup
  end

  def test_disable_name_or_email_field
    member = Member.new(:organization => programs(:org_primary))
    assert_false disable_name_or_email_field(member, members(:f_admin))

    member = members(:f_mentor)
    assert_false disable_name_or_email_field(member, members(:f_mentor))
    assert_false disable_name_or_email_field(member, members(:f_admin))
    assert disable_name_or_email_field(member, members(:ram))
  end

  def test_check_admin_of_user_in_all_programs
    user = members(:f_mentor)
    assert check_admin_of_user_in_all_programs(user, members(:f_admin))
    assert_false check_admin_of_user_in_all_programs(user, members(:ram))
  end

  # Should link to all the mentors profile
  def test_mentor_links
    # mentor_links expects _Mentors attr
    def _Mentors;  "Mentors"; end

    # Student doesnt have any mentor
    self.expects(:current_user).at_least(1).returns(users(:rahim))
    student = users(:f_student)
    mentor = users(:mentor_2)
    assert student.mentors.empty?
    assert_nil mentor_links_in_container(student)
    assert_nil mentor_links_in_container(student, [mentor])

    # Student has one mentor
    mentor_1 = users(:f_mentor)
    student.expects(:mentors).at_least(1).returns([mentor_1])
    assert_nil mentor_links_in_container(student)
    assert_nil mentor_links_in_container(student, [mentor])

    self.expects(:current_user).at_least(1).returns(student)
    assert_nil mentor_links_in_container(student)
    assert_nil mentor_links_in_container(student, [mentor])

    #Should Display For Admin
    self.expects(:current_user).at_least(1).returns(users(:ram))
    assert_match mentor_1.name, mentor_links_in_container(student)
    assert_match mentor.name, mentor_links_in_container(student, [mentor])

    # Student has two mentors
    mentor_2 = users(:f_mentor_student)
    student.expects(:mentors).returns([mentor_1, mentor_2])
    assert_match mentor_1.name, mentor_links_in_container(student)
    assert_match mentor.name, mentor_links_in_container(student, [mentor])

    self.expects(:current_user).at_least(1).returns(users(:f_mentor))
    assert_nil mentor_links_in_container(student)
    assert_nil mentor_links_in_container(student, [mentor])
  end

  # Check roles of the users
  def test_user_role_str
    assert_equal "a student", user_role_str(users(:f_student))
    assert_equal "a mentor", user_role_str(users(:f_mentor))
    assert_equal "an administrator", user_role_str(users(:f_admin))
    assert_equal "a mentor and student", user_role_str(users(:f_mentor_student))
  end

  def test_link_to_user_for_admin
    user = users(:f_mentor)
    content = link_to_user_for_admin(user)
    assert_select_helper_function "a[class=\"nickname\"][href=\"/members/#{user.id}\"][title=\"#{user.name}\"]" , content, text: "#{user.name}"
    user = users(:f_student)
    assert_select_helper_function "a[class=\"nickname\"][content_method=\"name\"][href=\"/members/#{user.id}\"][title=\"#{user.name}\"]", link_to_user_for_admin(user, :content_text => user.name), text:"#{user.name}"
  end

  def test_link_to_user_should_return_you_if_current_user_option_matches_user
    assert_equal("You", link_to_user(users(:f_mentor), :current_user => users(:f_mentor)))

    str = link_to_user(users(:f_student), :current_user => users(:f_mentor))
    assert_not_equal("You", str)
  end

  def test_link_to_user_should_return_you_only_if_current_user_is_passed
    self.stubs(:current_user).returns(users(:f_mentor))
    assert_equal users(:f_mentor), current_user

    assert_equal("You", link_to_user(users(:f_mentor), :current_user => users(:f_mentor)))
    assert_match(/.*a.*href.*Good unique name.*/, link_to_user(users(:f_mentor)))
  end

  def test_link_to_user_should_return_anonymous_if_the_person_is_not_visible_to_the_viewer
    fetch_role(:albers, :student).remove_permission('view_mentors')
    assert_false users(:f_student).reload.can_view_mentors?
    self.expects(:current_user).at_least(0).returns(users(:f_student))
    assert_equal("Anonymous", link_to_user(users(:f_mentor), :current_user => users(:f_student)))
    assert_equal("You", link_to_user(users(:f_student), :current_user => users(:f_student)))

    self.expects(:current_user).at_least(0).returns(users(:student_2))
    assert_equal("Anonymous", link_to_user(users(:f_mentor)))

    self.expects(:current_user).at_least(0).returns(users(:f_mentor_student))
    set_response_text(link_to_user(users(:f_mentor)))
    assert_select "a[href=?]", member_path(members(:f_mentor)), :text => users(:f_mentor).name

    self.expects(:current_user).at_least(0).returns(users(:student_2))
    assert_equal("Anonymous", link_to_user(users(:f_mentor)))

    fetch_role(:albers, :student).remove_permission('view_students')
    assert_false users(:f_student).reload.can_view_students?
    assert_false users(:student_2).reload.can_view_students?
    assert users(:f_mentor_student).reload.can_view_students?

    self.expects(:current_user).at_least(0).returns(users(:f_student))
    assert_equal("Anonymous", link_to_user(users(:student_2)))

    self.expects(:current_user).at_least(0).returns(users(:student_2))
    assert_equal("Anonymous", link_to_user(users(:f_student)))

    self.expects(:current_user).at_least(0).returns(users(:f_student))
    assert_equal("You", link_to_user(users(:f_student), :current_user => users(:f_student)))

    self.expects(:current_user).at_least(0).returns(users(:f_mentor_student))
    assert_not_equal("Anonymous", link_to_user(users(:f_student)))
  end

  def test_link_to_user_with_favorite_links
    set_response_text(link_to_user(users(:f_mentor), show_favorite_links: true, favorite_preferences_hash: {3=>2}))
    assert_select "span.display-inline.animated.mentor_favorite_#{users(:f_mentor).id}"

    set_response_text(link_to_user(users(:f_mentor)))
    assert_no_select "span.display-inline.animated.mentor_favorite_#{users(:f_mentor).id}"

    set_response_text(link_to_user(users(:f_mentor), show_favorite_links: true, favorite_preferences_hash: {3=>2}, current_user: users(:f_mentor)))
    assert_no_select "span.display-inline.animated.mentor_favorite_#{users(:f_mentor).id}"
  end

  def test_users_listing_page_actions_with_mentor_role
    program = users(:f_admin).program
    user = users(:f_admin)
    UsersHelperTest.any_instance.expects(:mentors_listing_page_actions).times(2).with(user, program).returns([])
    assert_equal [{:label=>"Manage Mentors", :url=>"/mentors"}], users_listing_page_actions(user, RoleConstants::MENTOR_NAME, program)

    program.admin_views.where(default_view: AbstractView::DefaultType::MENTORS).first.destroy
    assert_equal [], users_listing_page_actions(user, RoleConstants::MENTOR_NAME, program.reload)
  end

  def test_users_listing_page_actions_with_student_role
    role_name = RoleConstants::STUDENT_NAME
    program = programs(:albers)
    actions = users_listing_page_actions(users(:f_admin), role_name, program)
    assert_equal ["Manage Students", "Invite Students", "Add Students Directly"], actions.collect {|action| action[:label]}

    remove_role_permission(fetch_role(:albers, :admin), 'add_non_admin_profiles')
    assert !users(:f_admin).reload.can_add_non_admin_profiles?
    actions = users_listing_page_actions(users(:f_admin), role_name, program)
    assert_equal ["Manage Students", "Invite Students"], actions.collect {|action| action[:label]}

    actions = users_listing_page_actions(users(:f_student), role_name, program)
    assert_equal ["Invite Students"], actions.collect {|action| action[:label]}

    assert_equal [], users_listing_page_actions(users(:f_mentor), role_name, program)
  end

  def test_mentors_listing_page_actions
    org = programs(:org_primary)
    org.enable_feature(FeatureName::CALENDAR)
    org.reload
    program = programs(:albers)
    role_name = RoleConstants::MENTOR_NAME

    action_array = mentors_listing_page_actions(users(:f_admin), program)
    assert_equal 2, action_array.size

    remove_role_permission(fetch_role(:albers, :admin), 'add_non_admin_profiles')
    assert !users(:f_admin).reload.can_add_non_admin_profiles?

    action_array = mentors_listing_page_actions(users(:f_admin), program)
    assert_equal 1, action_array.size

    action_array = mentors_listing_page_actions(users(:f_mentor), program)
    assert_equal 1, action_array.size

    viewer = users(:f_student); viewer.expects(:student_of_moderated_groups?).returns(true)
    action_array = mentors_listing_page_actions(viewer, program)
    assert_equal 1, action_array.size
  end

  def test_mentors_listing_page_actions_for_non_logged_in_user_for_unmoderated_group
    program = programs(:albers)
    assert program.matching_by_mentee_alone?

    action_array = mentors_listing_page_actions(nil, program)
    assert_equal 1, action_array.size
    assert_equal "Join Program", action_array.first[:label]
    assert_equal new_membership_request_path, action_array.first[:url]
  end

  def test_mentors_listing_page_actions_for_non_logged_in_user_for_mem_requests_disabled
    program = programs(:albers)
    mentor_role = program.find_role('mentor')
    mentor_role.membership_request = false
    mentor_role.save
    mentee_role = program.find_role('student')
    mentee_role.membership_request = false
    mentee_role.save

    assert program.matching_by_mentee_alone?
    assert_false program.allow_join_now?

    action_array = mentors_listing_page_actions(nil, program)
    assert_nil action_array.first
  end

  def test_mentors_listing_page_actions_for_non_logged_in_user_for_mem_requests_or_join_directly_with_sso
    program = programs(:custom_domain)
    program.find_role('mentor').update_attributes(:join_directly_only_with_sso => true, :membership_request => false)
    program.find_role('student').update_attribute(:membership_request, false)

    assert_false program.matching_by_mentee_alone?
    assert program.allow_join_now?

    action_array = mentors_listing_page_actions(nil, program)
    assert_equal "Join Program", action_array.first[:label]
  end

  def test_mentors_listing_page_actions_for_non_logged_in_user_for_moderated_group
    program = programs(:moderated_program)
    assert program.matching_by_mentee_and_admin?

    action_array = mentors_listing_page_actions(nil, program)
    assert_equal 1, action_array.size
    assert_equal new_mentor_request_path, action_array.first[:url]
    assert_equal "Request a mentor", action_array.first[:label]
  end

  def test_mentors_listing_page_actions_for_non_logged_in_user_for_moderated_group_mentor_request_not_allowed
    program = programs(:moderated_program)
    assert program.matching_by_mentee_and_admin?
    program.update_attribute(:allow_mentoring_requests, false)

    action_array = mentors_listing_page_actions(nil, program)
    assert_equal 1, action_array.size
    assert_equal new_membership_request_path, action_array.first[:url]
    assert_equal "Join Program", action_array.first[:label]
  end

  def test_role_listing_page_actions
    program = programs(:albers)
    assert_equal [], role_listing_page_actions(nil, RoleConstants::MENTOR_NAME, program)

    actions = role_listing_page_actions(users(:f_admin), RoleConstants::MENTOR_NAME, program)
    assert_equal ["Invite Mentors", "Add Mentors Directly"], actions.collect {|action| action[:label]}
    assert_match /invite_users.*from.*admin.*role.*mentor/, actions[0][:url]
    assert_match /users.*new.*role.*mentor/, actions[1][:url]

    remove_role_permission(fetch_role(:albers, :admin), "invite_#{RoleConstants::MENTOR_NAME.pluralize}")
    actions = role_listing_page_actions(users(:f_admin).reload, RoleConstants::MENTOR_NAME, program)
    assert_equal ["Add Mentors Directly"], actions.collect {|action| action[:label]}

    remove_role_permission(fetch_role(:albers, :admin), "add_non_admin_profiles")
    assert_equal [], role_listing_page_actions(users(:f_admin).reload, RoleConstants::MENTOR_NAME, program)
  end

  def test_role_listing_page_actions_for_portal
    program = programs(:primary_portal)
    assert_equal [], role_listing_page_actions(nil, RoleConstants::EMPLOYEE_NAME, program)

    actions = role_listing_page_actions(users(:portal_admin), RoleConstants::EMPLOYEE_NAME, program)
    assert_equal ["Invite Employees", "Add Employees Directly"], actions.collect {|action| action[:label]}
    assert_match /invite_users.*from.*admin.*role.*employee/, actions[0][:url]
    assert_match /users.*new.*role.*employee/, actions[1][:url]

    remove_role_permission(fetch_role(:primary_portal, :admin), "invite_#{RoleConstants::EMPLOYEE_NAME.pluralize}")
    actions = role_listing_page_actions(users(:portal_admin).reload, RoleConstants::EMPLOYEE_NAME, program)
    assert_equal ["Add Employees Directly"], actions.collect {|action| action[:label]}

    remove_role_permission(fetch_role(:primary_portal, :admin), "add_non_admin_profiles")
    assert_equal [], role_listing_page_actions(users(:portal_admin).reload, RoleConstants::EMPLOYEE_NAME, program)
  end

  def test_unanswered_question_in_sidebar
    user = users(:f_mentor)
    question = programs(:org_primary).profile_questions.skype_question.first
    # Not required question
    # question.expects(:required_for).returns(false)
    response = unanswered_question_in_sidebar(question, user, :url => edit_member_path(user.member, src: "profile_c", prof_c: true, :scroll_to => question.id), :home_page => true)
    set_response_text(response)
    assert_select "a[href=?]", edit_member_path(user.member, src: "profile_c", prof_c: true, :scroll_to => question.id), :text => /#{question.question_text}/
    assert_select "a[data-url=?]", skip_answer_member_path(user.member, :question_id => question.id, :home_page => true, :format => :js), :text => /Mark N\/A/
    assert_select 'a', :text => /Undo/
    # Required question
    question.expects(:required_for).returns(true)
    response = unanswered_question_in_sidebar(question, user, :url => edit_member_path(user.member, src: "profile_c", prof_c: true, :scroll_to => question.id), :home_page => false)
    set_response_text(response)
    assert_select 'a', :text => /Undo/, :count => 0
    assert_select 'a', :text => /Mark N\/A/, :count => 0
    # Profile image
    response = unanswered_question_in_sidebar(nil, user, :url => edit_member_profile_picture_path(user.member, :src => "profile_c"), :home_page => false, :image => true)
    set_response_text(response)
    assert_select "a[href=?]", edit_member_profile_picture_path(user.member, :src => "profile_c"), :text => /Upload your profile picture/
    assert_select "a[data-url=?]", skip_answer_member_path(user.member, :profile_picture => true, :home_page => false, :format => :js), :text => /Mark N\/A/
    assert_select 'a', :text => /Undo/
  end

  def test_actions_for_other_non_administrative_user_listing
    teacher = users(:pbe_teacher_0)
    assert_equal [[], ""], actions_for_other_non_administrative_user_listing(teacher, teacher)

    mentor = users(:pbe_mentor_0)
    actions, dropdown_title = actions_for_other_non_administrative_user_listing(teacher, mentor)
    assert_equal "Actions", dropdown_title
    assert_equal ["<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"], actions.collect { |action| action[:label] }

    admin = users(:f_admin_pbe)
    actions, dropdown_title = actions_for_other_non_administrative_user_listing(teacher, admin)
    assert_equal "Actions", dropdown_title
    assert_equal ["<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"], actions.collect { |action| action[:label] }
  end

  def test_actions_for_mentor_listing_for_mentor
    profile_user = users(:f_mentor)
    profile_viewer = users(:mentor_0)

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Actions", dropdown_title
    assert_equal ["<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"], actions.collect { |action| action[:label] }
  end

  def test_actions_for_mentor_listing_same_user
    profile_user = users(:f_mentor_student)
    profile_viewer = users(:f_mentor_student)

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "", dropdown_title
    assert_equal [], actions
  end

  def test_actions_for_mentor_listing_for_mentee
    @current_program = programs(:albers)
    profile_user = users(:f_mentor_student)
    profile_viewer = users(:f_student)

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    send_message = "<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"
    request_mentoring = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Request Mentoring Connection"
    assert_equal [request_mentoring, send_message], actions.collect { |action| action[:label] }
  end

  def test_mentors_listing_action_for_admin
    profile_user = users(:f_mentor)
    profile_viewer = users(:f_admin)

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Actions", dropdown_title
    assert_equal ["<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"], actions.collect { |action| action[:label] }
  end

  def test_mentors_listing_action_with_mentor_not_allowing_onetime_meeting
    @current_organization = programs(:org_primary)
    @current_organization.enable_feature(FeatureName::CALENDAR)

    @current_program = programs(:albers)
    @current_program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    profile_user = users(:f_mentor_student)
    profile_viewer = users(:f_student)
    request_meeting_label = "<i class=\"fa fa-calendar fa-fw m-r-xs\"></i>Request Meeting"
    request_meeting_label_disabled = "<i class=\"fa fa-ban fa-fw m-r-xs\"></i>Request Meeting"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    action = actions.find { |action| action[:label] == request_meeting_label }
    assert_nil actions.find { |action| action[:label] == request_meeting_label_disabled }
    assert_equal "Connect", dropdown_title
    assert action.present?
    assert_nil action[:disabled]

    profile_user.update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    action = actions.find { |action| action[:label] == request_meeting_label_disabled }
    assert_nil actions.find { |action| action[:label] == request_meeting_label }
    assert_equal true, action[:disabled]
  end

  def test_mentors_listing_action_with_mentor_not_allowing_ongoing_mentoring
    @current_program = programs(:albers)
    @current_program.enable_feature(FeatureName::CALENDAR)
    @current_program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    profile_user = users(:f_mentor_student)
    profile_viewer = users(:f_student)
    request_mentoring_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Request Mentoring Connection"
    request_mentoring_label_disabled = "<i class=\"fa fa-ban fa-fw m-r-xs\"></i>Request Mentoring Connection"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    action = actions.find { |action| action[:label] == request_mentoring_label }
    assert_nil actions.find { |action| action[:label] == request_mentoring_label_disabled }
    assert_equal "Connect", dropdown_title
    assert action.present?
    assert_nil action[:disabled]

    profile_user.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    action = actions.find { |action| action[:label] == request_mentoring_label_disabled }
    assert_nil actions.find { |action| action[:label] == request_mentoring_label }
    assert_equal true, action[:disabled]
  end

  def test_mentors_listing_action_with_mentor_not_having_available_slots
    @current_program = programs(:albers)
    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    request_mentoring_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Request Mentoring Connection"
    request_mentoring_label_disabled = "<i class=\"fa fa-ban fa-fw m-r-xs\"></i>Request Mentoring Connection"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user, {:mentors_with_slots => {}})
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == request_mentoring_label_disabled }[:disabled]
    assert_nil actions.find { |action| action[:label] == request_mentoring_label }

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == request_mentoring_label_disabled }[:disabled]
    assert_nil actions.find { |action| action[:label] == request_mentoring_label }

    profile_user.stubs(:can_receive_mentoring_requests?).returns(true)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    action = actions.find { |action| action[:label] == request_mentoring_label }
    assert_nil actions.find { |action| action[:label] == request_mentoring_label_disabled }
    assert action.present?
    assert_nil action[:disabled]
  end

  def test_mentors_listing_action_for_disabled_add_to_preferred_mentors
    @current_program = programs(:moderated_program)
    @current_organization = programs(:org_primary)
    @current_program.enable_feature(FeatureName::CALENDAR)
    @current_program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    profile_user = users(:moderated_mentor)
    profile_viewer = users(:moderated_student)
    assert @current_program.matching_by_mentee_and_admin?
    assert @current_program.matching_by_mentee_and_admin_with_preference?
    assert !Group.involving(profile_user, profile_viewer).any?
    add_to_preferred_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Add to preferred mentors"
    add_to_preferred_label_disabled = "<i class=\"fa fa-ban fa-fw m-r-xs\"></i>Add to preferred mentors"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    action = actions.find { |action| action[:label] == add_to_preferred_label }
    assert_nil actions.find { |action| action[:label] == add_to_preferred_label_disabled }
    assert_equal "Connect", dropdown_title
    assert action.present?
    assert_nil action[:disabled]

    profile_user.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    action = actions.find { |action| action[:label] == add_to_preferred_label_disabled }
    assert_nil actions.find { |action| action[:label] == add_to_preferred_label }
    assert_equal "Connect", dropdown_title
    assert_equal true, action[:disabled]
  end

  def test_mentors_listing_action_for_moderated_program_student_with_preference
    @current_program = programs(:moderated_program)
    @current_organization = programs(:org_primary)

    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    assert @current_program.matching_by_mentee_and_admin?
    assert @current_program.matching_by_mentee_and_admin_with_preference?
    assert !Group.involving(profile_user, profile_viewer).any?
    add_to_preferred_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Add to preferred mentors"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    action = actions.find { |action| action[:label] == add_to_preferred_label }
    assert_equal "Connect", dropdown_title
    assert action.present?
    assert_nil action[:disabled]

    profile_viewer = users(:mkr_student)
    group = groups(:mygroup)
    assert group.has_member?(profile_user)
    assert group.has_member?(profile_viewer)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.collect { |action| action[:label] }.include? "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Go to #{h(group.name)}"
  end

  def test_mentors_listing_action_for_moderated_program_student_without_preference
    @current_program = programs(:moderated_program)
    @current_organization = programs(:org_primary)
    @current_program.update_attributes!(:allow_preference_mentor_request => false)

    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    assert @current_program.matching_by_mentee_and_admin?
    assert_false @current_program.matching_by_mentee_and_admin_with_preference?
    assert !Group.involving(profile_user, profile_viewer).any?
    add_to_preferred_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Add to preferred mentors"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    action = actions.find { |action| action[:label] == add_to_preferred_label }
    assert_nil action

    profile_viewer = users(:mkr_student)
    group = groups(:mygroup)
    assert group.has_member?(profile_user)
    assert group.has_member?(profile_viewer)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.collect { |action| action[:label] }.include? "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Go to #{h(group.name)}"
  end

  def test_mentors_listing_action_for_moderated_student_without_permission
    @current_program = programs(:moderated_program)
    @current_organization = programs(:org_primary)
    remove_mentor_request_permission_for_students

    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    assert !Group.involving(profile_user, profile_viewer).any?
    add_to_preferred_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Add to preferred mentors"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    action = actions.find { |action| action[:label] == add_to_preferred_label }
    assert_nil action

    profile_viewer = users(:mkr_student)
    group = groups(:mygroup)
    assert group.has_member?(profile_user)
    assert group.has_member?(profile_viewer)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.collect { |action| action[:label] }.include? "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Go to #{h(group.name)}"
  end

  def test_mentors_listing_action_for_non_moderated_program_student_without_group
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)

    profile_user = users(:mentor_3)
    profile_viewer = users(:f_student)
    request_mentoring_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Request Mentoring Connection"
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user, {student_can_connect_to_mentor: true})
    action = actions.find { |action| action[:label] == request_mentoring_label }
    assert_equal "Connect", dropdown_title
    assert action.present?
    assert_nil action[:disabled]

    # Busy mentor. Do not show "Request mentoring"
    User.any_instance.expects(:can_receive_mentoring_requests?).at_least(0).returns(false)
    assert !profile_user.can_receive_mentoring_requests?
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_nil actions.find { |action| action[:label] == request_mentoring_label }
  end

  def test_mentors_listing_action_for_non_moderated_program_when_sending_mentoring_requests_not_allowed
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    @current_program.update_attribute(:allow_mentoring_requests, false)

    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    request_mentoring_label = "<i class=\"fa fa-ban fa-fw m-r-xs\"></i>Request Mentoring Connection"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user, { student_can_connect_to_mentor: true } )
    action = actions.find { |action| action[:label] == request_mentoring_label }
    assert_equal "Connect", dropdown_title
    assert action.present?
    assert_equal true, action[:disabled]
    assert_equal "The program administrator does not allow you to send any requests.", action[:tooltip]
  end

  def test_mentors_listing_action_for_moderated_program_student_with_preference_when_sending_mentoring_requests_not_allowed
    @current_program = programs(:moderated_program)
    @current_organization = programs(:org_primary)
    @current_program.update_attribute(:allow_mentoring_requests, false)

    profile_viewer = users(:moderated_student)
    profile_user = users(:moderated_mentor)
    assert @current_program.matching_by_mentee_and_admin?
    assert @current_program.matching_by_mentee_and_admin_with_preference?
    assert_false Group.involving(profile_user, profile_viewer).any?
    add_to_preferred_label = "<i class=\"fa fa-ban fa-fw m-r-xs\"></i>Add to preferred mentors"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    action = actions.find { |action| action[:label] == add_to_preferred_label }
    assert_equal "Connect", dropdown_title
    assert action.present?
    assert_equal true, action[:disabled]
    assert_equal "The program administrator does not allow you to send any requests.", action[:tooltip]
  end

  def test_mentors_listing_action_for_non_moderated_program_student_doesnot_have_permission
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)

    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    remove_mentor_request_permission_for_students
    request_mentoring_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Request Mentoring Connection"
    add_to_preferred_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Add to preferred mentors"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_nil actions.find { |action| action[:label] == request_mentoring_label }
    assert_nil actions.find { |action| action[:label] == add_to_preferred_label }
  end

  def test_mentors_listing_action_for_non_moderated_program_student_with_group
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)

    group = create_group
    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    request_mentoring_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Request Mentoring Connection"
    goto_mentoring_connection = "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Go to #{h(group.name)}"

    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert_nil actions.find { |action| action[:label] == request_mentoring_label }
    assert actions.find { |action| action[:label] == goto_mentoring_connection }
  end

  def test_mentors_listing_action_for_program_with_disabled_ongoing_mentoring
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)

    profile_user = users(:f_mentor)
    profile_user.update_attribute(:max_connections_limit, 13)
    profile_viewer = users(:f_student)
    request_mentoring_label = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Request Mentoring Connection"

    # changing engagement type of program to career and ongoing based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == request_mentoring_label }

    # changing engagement type of program to career based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert_nil actions.find { |action| action[:label] == request_mentoring_label }
  end

  def test_status_indicator
    @current_organization = programs(:org_primary)
    @current_program = programs(:albers)

    # Current user not set
    self.expects(:current_user).at_least(0).returns(nil)
    assert !users(:inactive_user).active?
    assert !users(:not_requestable_mentor).reload.can_receive_mentoring_requests?
    assert !users(:pending_user).active?
    assert_nil status_indicator(users(:inactive_user))
    assert_nil status_indicator(users(:not_requestable_mentor))
    assert_nil status_indicator(users(:pending_user))

    # Deactivated User
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    content = status_indicator(users(:inactive_user))
    assert_not_nil content
    assert_match /Membership deactivated/, content

    # Deactivated User - Seen by non-admin
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    assert_nil status_indicator(users(:inactive_user))

    # User with unpublished profile - Seen by Admin
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    content = status_indicator(users(:pending_user))
    assert_not_nil content
    assert_match /profile not published/, content

    # User with unpublished profile - Seen by non-admin
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    assert_nil status_indicator(users(:pending_user))

    # Mentor with no slots
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    content = status_indicator(users(:not_requestable_mentor), consider_user_as_mentor: true, show_availability: true)
    assert_not_nil content
    assert_match /Mentor has reached maximum student limit and is available for messaging only/, content
    assert_match /unavailable/, content

    content = status_indicator(users(:not_requestable_mentor), {consider_user_as_mentor: true, :mentors_with_slots => {users(:not_requestable_mentor).id => 1}})
    assert_blank content

    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    assert_blank status_indicator(users(:not_requestable_mentor), consider_user_as_mentor: true)

    content = status_indicator(users(:not_requestable_mentor), {consider_user_as_mentor: true, :mentors_with_slots => {users(:not_requestable_mentor).id => 1}})
    assert_blank content

    # Do not show availability to other mentors.
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    assert_blank status_indicator(users(:not_requestable_mentor), consider_user_as_mentor: true)

    # Show availability if the mentor is a student too.
    self.expects(:current_user).at_least(0).returns(users(:f_mentor_student))
    content = status_indicator(users(:not_requestable_mentor), consider_user_as_mentor: true, show_availability: true)
    assert_not_nil content
    assert_match /Mentor has reached maximum student limit and is available for messaging only/, content
    assert_match /unavailable/, content

    content = status_indicator(users(:not_requestable_mentor), {consider_user_as_mentor: true, :mentors_with_slots => {users(:not_requestable_mentor).id => 1}})
    assert_blank content

    self.expects(:current_user).at_least(0).returns(users(:f_student))
    assert_blank status_indicator(users(:robert), consider_user_as_mentor: true)

    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    assert_blank status_indicator(users(:robert), consider_user_as_mentor: true)

    # Show connection link and do not show 'unavailable' for a student connected to the mentor.
    self.expects(:current_user).at_least(0).returns(users(:mkr_student))
    g = Group.involving(users(:mkr_student), users(:f_mentor)).first
    assert_not_nil g
    users(:f_mentor).expects(:can_receive_mentoring_requests?).at_least(0).returns(false)
    assert !users(:f_mentor).can_receive_mentoring_requests?
    content = status_indicator(users(:f_mentor), consider_user_as_mentor: true)
    assert_no_match(/unavailable/, content)
    assert_match /my mentor/, content

    # Show the slots available if logged in as admin
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    users(:f_mentor).expects(:can_receive_mentoring_requests?).at_least(0).returns(true)
    content = status_indicator(users(:robert), consider_user_as_mentor: true, show_availability: true, from_preferred_mentoring: true)
    assert_match /preferred to have at most/, content
    assert_match /slots available/, content

    # Multiple tags
    self.expects(:current_user).at_least(0).returns(users(:mkr_student))
    users(:mkr_student).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    users(:f_mentor).expects(:can_receive_mentoring_requests?).at_least(0).returns(false)
    users(:f_mentor).expects(:profile_incomplete_for?).at_least(0).returns(true)
    labels = status_indicator(users(:f_mentor), return_hash: true, consider_user_as_mentor: true, show_availability: true).collect { |label| label[:content] }
    assert_equal_unordered ["mandatory fields missing", "unavailable"], labels

    self.expects(:current_user).at_least(0).returns(users(:mkr_student))
    users(:mkr_student).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    users(:f_mentor).expects(:can_receive_mentoring_requests?).at_least(0).returns(false)
    users(:f_mentor).expects(:profile_incomplete_for?).at_least(0).returns(true)
    labels = status_indicator(users(:f_mentor), return_hash: true, consider_user_as_mentor: true).collect { |label| label[:content] }
    assert_equal_unordered ["mandatory fields missing", "my mentor"], labels

    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    users(:f_mentor).expects(:can_receive_mentoring_requests?).at_least(0).returns(true)
    users(:robert).expects(:profile_incomplete_for?).at_least(0).returns(true)
    users(:robert).update_attribute(:state, 'suspended')
    content = status_indicator(users(:robert), consider_user_as_mentor: true)
    assert_match /Membership deactivated/, content
    assert_match /mandatory fields missing/, content
    assert_no_match(/slots available/, content)

    # testing for show availability tags option
    users(:f_mentor).expects(:can_receive_mentoring_requests?).at_least(0).returns(false)
    content = status_indicator(users(:f_mentor), consider_user_as_mentor: true, show_availability: true)
    assert_match /unavailable/, content
    content = status_indicator(users(:f_mentor), consider_user_as_mentor: true)
    assert_no_match(/unavailable/, content)

    #Availability labels not to be shown for PBE
    @current_program = programs(:albers)
    Program.any_instance.expects(:career_based?).at_least(0).returns(false)
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    users(:robert).expects(:can_receive_mentoring_requests?).at_least(0).returns(false)
    users(:robert).expects(:profile_incomplete_for?).at_least(0).returns(true)
    users(:robert).update_attribute(:state, 'suspended')
    content = status_indicator(users(:robert), consider_user_as_mentor: true, :show_availability => true)
    assert_match /Membership deactivated/, content
    assert_match /mandatory fields missing/, content
    assert_no_match(/slots available/, content)
  end

  def test_status_indicator_for_active_users_whose_profile_is_incomplete
    @current_program = programs(:albers)
    mentor = users(:f_mentor)
    create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], :required => true)
    student = users(:f_student)
    text = status_indicator(mentor, consider_user_as_mentor: true)
    assert_match(/mandatory fields missing/, text)
    text = status_indicator(student, consider_user_as_student: true)
    assert_no_match(/mandatory fields missing/, text)
  end

  def test_show_last_logged_in
    self.expects(:current_user).at_least(1).returns(users(:f_admin))
    user = users(:f_mentor)
    user.update_attribute(:last_seen_at, nil)
    assert_equal "Never logged in", show_last_logged_in(user) { |last_logged_in| last_logged_in }
    assert_equal "Never logged in", show_last_logged_in(user, with_prefix: true) { |last_logged_in| last_logged_in }
    assert_nil show_last_logged_in(user, no_placeholder: true) { |last_logged_in| last_logged_in }

    last_seen = 2.hours.ago
    user.update_attribute(:last_seen_at, last_seen)
    assert_false user.reload.last_seen_at.nil?
    assert_equal "about 2 hours ago", show_last_logged_in(user) { |last_logged_in| last_logged_in }
    assert_equal "Last login about 2 hours ago", show_last_logged_in(user, with_prefix: true) { |last_logged_in| last_logged_in }
    assert_equal last_seen.to_i, show_last_logged_in(user, no_format: true) { |last_logged_in| last_logged_in.to_i }

    last_seen = Time.zone.parse "Mon, 25 Apr 2011 06:31:27"
    Time.zone = last_seen.zone
    user.update_attribute(:last_seen_at, last_seen)
    assert_false user.reload.last_seen_at.nil?
    assert_equal "April 25, 2011 at 06:31 AM", show_last_logged_in(user) { |last_logged_in| last_logged_in }
    assert_equal "Last login April 25, 2011 at 06:31 AM", show_last_logged_in(user, with_prefix: true) { |last_logged_in| last_logged_in }
    assert_equal last_seen, show_last_logged_in(user, no_format: true) { |last_logged_in| last_logged_in }

    self.expects(:current_user).at_least(1).returns(users(:f_student))
    User.any_instance.expects(:last_seen_at).never
    assert_nil show_last_logged_in(user) { |last_logged_in| last_logged_in }

    self.expects(:current_user).at_least(1).returns(nil)
    User.any_instance.expects(:last_seen_at).never
    assert_nil show_last_logged_in(user) { |last_logged_in| last_logged_in }
  end

  def test_hover_actions_for_skype_link
    user = users(:f_mentor)
    group = user.groups.first
    admin_viewer = users(:f_admin)
    @current_program = programs(:albers)

    assert_nil user.skype_id
    content = get_hovercard_actions(admin_viewer, user, group)
    assert_no_match /"Skype"/, content

    skype_question = programs(:org_primary).profile_questions.skype_question.first
    ans = ProfileAnswer.create!(:profile_question => skype_question, :ref_obj => members(:f_mentor), :answer_text => '')
    ans.update_attribute :answer_text, 'vikram.venkat'

    content = get_hovercard_actions(admin_viewer, user, group)
    assert_match "<a data-activity=\"Skype Call\" class=\"cjs_track_js_ei_activity\" href=\"skype:vikram.venkat?call\">Skype</a>", content
  end

  def test_remove_user_prompt
    @current_organization = programs(:org_primary)
    @user = users(:f_mentor)
    content, show_suspend_message = remove_user_prompt(@user)
    assert_match(/You are about to remove #{users(:f_mentor).name} from the program. Did you intend to deactivate the membership instead?/, content)
    assert_equal show_suspend_message, true

    @user.state = User::Status::SUSPENDED
    @user.save
    assert_equal @user.state, User::Status::SUSPENDED
    content, show_suspend_message = remove_user_prompt(@user)
    assert_match(/You are about to remove Good unique name from the program./, content)
    assert_equal show_suspend_message, false

  end

  def test_mentors_listing_action_for_student
    time = Time.now
    Time.stubs(:now).returns(time)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)

    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)

    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([false, ""])
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user, { student_can_connect_to_mentor: true } )
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == "<i class=\"fa fa-calendar fa-fw m-r-xs\"></i>Request Meeting" }
  end

  def test_name_with_id_blank
    assert_equal [],name_with_id([])
  end

  def test_name_with_id
    first_user_id = User.first.id
    last_user = users(:no_subdomain_admin)
    last_user_id = last_user.id
    first_member_id = User.first.member.id
    last_member_id = last_user.member.id
    output = name_with_id([first_user_id, last_user_id])
    assert_equal 2, output.count
    assert_match /Freakin Admin/, output.first
    assert_match /data-memberlink=\"\/members\/#{first_member_id}\"/, output.first
    assert_match /data-userid=\"#{first_member_id}\"/, output.first
    assert_match /data-memberlink=\"\/members\/#{last_member_id}\"/, output.last
    assert_match /No Subdomain Admin/, output.last
    assert_match /data-userid=\"#{last_member_id}\"/, output.last
  end

  def test_send_message_in_mentors_listing_for_unconnected_guys
    program = programs(:albers)
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)

    profile_user = users(:f_mentor)
    profile_viewer = users(:f_student)
    send_message = "<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"
    view_pending_request = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>View your pending request"

    # preferred mode
    program.mentor_request_style = Program::MentorRequestStyle::NONE
    program.save!
    program.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }

    # mentee directly requesting mentor mode
    program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_ADMIN
    program.save!
    program.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }

    # admin assigns mode
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    program.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }

    # student has sent a mentor request
    profile_viewer.reload
    create_mentor_request
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }
    assert actions.find { |action| action[:label] == view_pending_request }

    # setting disabled
    programs(:albers).update_attributes!(:allow_user_to_send_message_outside_mentoring_area => false)
    assert_false programs(:albers).reload.allow_user_to_send_message_outside_mentoring_area?
    profile_viewer.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user, {student_can_connect_to_mentor: true})
    assert_nil actions.find { |action| action[:label] == send_message }
    assert actions.find { |action| action[:label] == view_pending_request }

    # options passed
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user, {:active_received_requests => {}, student_can_connect_to_mentor: true})
    assert_nil actions.find { |action| action[:label] == view_pending_request }

  end

  def test_send_message_in_mentors_listing_for_connected_guys
    program = programs(:albers)
    @current_program = program
    @current_organization = programs(:org_primary)
    profile_user = users(:f_mentor)
    profile_viewer = users(:mkr_student)
    group = groups(:mygroup)

    # the profile_user and profile_mentor are already connected
    goto_mentoring_connection = "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Go to #{h(group.name)}"
    send_message = "<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }
    assert actions.find { |action| action[:label] == goto_mentoring_connection }

    # preferred mode
    program.mentor_request_style = Program::MentorRequestStyle::NONE
    program.save!
    program.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }

    # mentee directly requesting mentor mode
    program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_ADMIN
    program.save!
    program.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }

    # admin assigns mode
    program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_MENTOR
    program.save!
    program.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }

    # setting disabled, but since connected, send message should be displayed
    programs(:albers).update_attributes!(:allow_user_to_send_message_outside_mentoring_area => false)
    assert_false programs(:albers).reload.allow_user_to_send_message_outside_mentoring_area?
    profile_viewer.reload
    actions, dropdown_title = actions_for_mentor_listing(profile_viewer, profile_user)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == send_message }
    assert actions.find { |action| action[:label] == goto_mentoring_connection }
  end

  def test_actions_for_mentees_listing
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    program = programs(:albers)
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)

    profile_viewer = users(:f_mentor)
    profile_viewer.update_attribute(:max_connections_limit, 10)
    profile_user = users(:mkr_student)
    sample_student = users(:student_2)
    group_1 = groups(:mygroup)
    group_2 = create_group(name: "C23", mentor: profile_viewer, student: profile_user)
    group_3 = create_group(name: "Drafted C23", mentor: profile_viewer, student: profile_user)

    goto_group_1 = "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Go to #{h(group_1.name)}"
    goto_group_2 = "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Go to #{h(group_2.name)}"
    send_message = "<i class=\"fa fa-envelope fa-fw m-r-xs\"></i>Send Message"
    find_mentor = "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Find a Mentor"
    offer_mentoring = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Offer Mentoring"
    add_as_mentee = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Add as Mentee"

    # the profile_user and profile_mentor are already connected
    mentee_groups_map = {}
    mentee_groups_map[profile_user] = Group.involving(profile_user, profile_viewer)
    students_with_no_limit = {}
    offer_pending = {}
    offer_pending[sample_student.id] = sample_student.id
    options = { viewer_can_find_mentor: false, viewer_can_offer: true, students_with_no_limit: students_with_no_limit , mentee_groups_map: mentee_groups_map, offer_pending: offer_pending }
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == goto_group_1 }
    assert actions.find { |action| action[:label] == goto_group_2 }
    assert actions.find { |action| action[:label] == send_message }

    profile_viewer = users(:f_admin)
    profile_user = users(:mkr_student)
    programs(:albers).update_attributes!(max_connections_for_mentee: 1)
    options.merge!(viewer_can_find_mentor: true, mentee_groups_map: {})
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_equal "Actions", dropdown_title
    assert actions.find { |action| action[:label] == find_mentor }
    assert actions.find { |action| action[:label] == send_message }

    profile_viewer = users(:mentor_0)
    profile_user = users(:mkr_student)
    options.merge!(viewer_can_find_mentor: false)
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_equal "Connect", dropdown_title
    assert_nil actions.find { |action| action[:label] == add_as_mentee }
    assert actions.find { |action| action[:label] == send_message }

    profile_viewer = users(:f_student)
    program.update_attributes!(:allow_user_to_send_message_outside_mentoring_area => false)
    assert_false program.reload.allow_user_to_send_message_outside_mentoring_area?
    profile_viewer.reload
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_nil actions.find { |action| action[:label] == send_message }

    # mentor with onetime mentoring mode cannot offer mentoring
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    profile_viewer = users(:mentor_0)
    profile_user = users(:mkr_student)
    profile_viewer.program.reload
    students_with_no_limit = {}
    options = { viewer_can_offer: true, students_with_no_limit: students_with_no_limit }
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == offer_mentoring }

    # changing mentoring mode to onetime
    profile_viewer.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_nil actions.find { |action| action[:label] == offer_mentoring }
  end

  def test_actions_for_mentees_listing_for_program_with_disabled_ongoing_mentoring
    @current_program = programs(:albers)
    profile_viewer = users(:mentor_0)
    profile_user = users(:mkr_student)
    students_with_no_limit = {}
    options = {viewer_can_offer: true, students_with_no_limit: students_with_no_limit, viewer_can_find_mentor: true}

    offer_mentoring = "<i class=\"fa fa-user-plus fa-fw m-r-xs\"></i>Offer Mentoring"
    find_mentor = "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Find a Mentor"

    # changing engagement type of program to career and ongoing based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_equal "Connect", dropdown_title
    assert actions.find { |action| action[:label] == offer_mentoring }
    assert actions.find { |action| action[:label] == find_mentor }

    # changing engagement type of program to career based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    actions, dropdown_title = actions_for_mentees_listing(profile_viewer, profile_user, options)
    assert_nil actions.find { |action| action[:label] == offer_mentoring }
    assert_nil actions.find { |action| action[:label] == find_mentor }
  end

  def test_get_reasons_for_not_removing_role_name
    user = users(:f_user)
    mentor_user = users(:f_mentor)
    student_user = users(:mkr_student)
    student_user2 = users(:f_student)
    mentor_student = users(:f_mentor_student)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)

    #creating mentor requests
    mentor_req_1 = create_mentor_request(:student => student_user, :mentor => mentor_user)
    mentor_req_2 = create_mentor_request(:student => student_user, :mentor => mentor_student)
    meeting_req_1 = create_meeting_request(:student => student_user, :mentor => mentor_student)

    list0 = get_reasons_for_not_removing_role_name(user, program.find_role('user'), program)
    reasons = get_reasons_for_not_removing_roles(mentor_user, program)
    list1 = reasons[RoleConstants::MENTOR_NAME]
    list2 = reasons[RoleConstants::STUDENT_NAME]
    list3 = get_reasons_for_not_removing_roles(student_user, program, [student_role])[RoleConstants::STUDENT_NAME]

    assert list0.empty?
    assert_equal 3, list1.size
    assert list1.include?("Has an ongoing Mentoring Connection")
    assert list1.include?("Has 12 pending mentor requests")
    assert list1.include?("Has a pending meeting request")
    assert_false list1.include?("Has a pending mentor offer")
    assert list2.empty?
    assert_equal 3, list3.size
    assert list3.include?("Has an ongoing Mentoring Connection")
    assert list3.include?("Has 2 pending mentor requests")
    assert list3.include?("Has a pending meeting request")

    meeting_req_2 = create_meeting_request(:student => student_user, :mentor => mentor_user)
    list3_1 = get_reasons_for_not_removing_roles(student_user, program, [student_role])[RoleConstants::STUDENT_NAME]
    assert_equal 3, list3_1.size
    assert list3_1.include?("Has 2 pending meeting requests")

    #marking a group closed
    group = mentor_user.groups.first
    group.status = Group::Status::CLOSED
    group.closed_at = Time.now
    group.closed_by  = users(:f_admin)
    group.termination_reason = "Test"
    group.termination_mode = Group::TerminationMode::ADMIN
    group.closure_reason_id = group.get_auto_terminate_reason_id
    group.save!

    student_user2.received_meeting_requests.destroy_all
    student_user2.sent_meeting_requests.destroy_all
    #creating mentoring offers
    mentor_offer1 = create_mentor_offer(:mentor => mentor_user, :group => groups(:mygroup))
    mentor_offer2 = create_mentor_offer(:mentor => mentor_student, :student => student_user2)
    list4 = get_reasons_for_not_removing_role_name(student_user2.reload, student_role, program)
    list5 = get_reasons_for_not_removing_role_name(mentor_user.reload, mentor_role, program)
    reasons = get_reasons_for_not_removing_roles(mentor_student.reload, program)
    list6 = reasons[RoleConstants::MENTOR_NAME]
    list7 = reasons[RoleConstants::STUDENT_NAME]

    assert_equal 1, list4.size
    assert list4.include?("Has 2 pending mentor offers")
    assert_equal 3, list5.size
    assert_false list5.include?("Has an ongoing Mentoring Connection")
    assert list5.include?("Has 12 pending mentor requests")
    assert list5.include?("Has a pending mentor offer")
    assert list5.include?("Has a pending meeting request")
    assert_equal 3, list6.size
    assert list6.include?("Has a pending mentor offer")
    assert list6.include?("Has a pending mentor request")
    assert list6.include?("Has a pending meeting request")
    assert list7.empty?

    # Marking mentor offer and request as accepted
    mentor_offer1.mark_accepted!
    mentor_req_1.mark_accepted!

    list8 = get_reasons_for_not_removing_role_name(mentor_user.reload, mentor_role, program)
    list9 = get_reasons_for_not_removing_role_name(student_user2.reload, student_role, program)

    assert_equal 3, list8.size
    assert list8.include?("Has 2 ongoing Mentoring Connections")
    assert_false list8.include?("Has a pending mentor offer")
    assert list8.include?("Has 11 pending mentor requests")
    assert list8.include?("Has a pending meeting request")
    assert_equal 2, list9.size
    assert list9.include?("Has an ongoing Mentoring Connection")
    assert list9.include?("Has a pending mentor offer")
  end

  def test_get_reasons_for_not_removing_role_name_project_requests
    mentor_user = users(:f_mentor_pbe)
    program = programs(:pbe)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    program.roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    assert_false mentor_user.can_send_project_request?
    mentor_user.add_role(RoleConstants::STUDENT_NAME)
    mentor_user.reload
    assert mentor_user.can_send_project_request?
    create_project_request(groups(:group_pbe_2), mentor_user)
    list1 = get_reasons_for_not_removing_role_name(mentor_user, student_role, program)
    assert list1.include?("Has a pending mentoring connection request")
    req = mentor_user.sent_project_requests.first
    req.status = AbstractRequest::Status::REJECTED
    req.receiver = users(:f_admin_pbe)
    req.response_text = "Sorry, can't acccept you two-role guy!"
    req.save!
    mentor_user.reload
    assert_empty get_reasons_for_not_removing_role_name(mentor_user, student_role, program)
  end

  def test_reason_list
    list1 = reason_list(['text'])
    assert_equal "<div>text</div>", list1
    list2 = reason_list(['text1', 'text2'])
    assert_equal "<ul><li class=\"tooltip-list\">text1</li><li class=\"tooltip-list\">text2</li></ul>", list2
  end

  def test_render_user_role_check_boxes
    current_user = users(:f_admin)
    program = programs(:albers)
    self.expects(:current_user).at_least(1).returns(current_user)

    set_response_text(render_user_role_check_boxes({:program => program}))
    assert_select "input[type=checkbox][value=?]", 'admin'
    assert_select "label", :text => _Admin
    assert_select "input[type=checkbox][value=?]", 'mentor'
    assert_select "label", :text => 'Mentor'
    assert_select "input[type=checkbox][value=?]", 'student'
    assert_select "label", :text => 'Student'

    # Admin option
    remove_role_permission(fetch_role(:albers, :admin), 'manage_admins')
    assert_false users(:f_admin).reload.can_manage_admins?
    set_response_text(render_user_role_check_boxes({:program => program}))
    assert_select "input[type=checkbox][value=?]", 'mentor'
    assert_select "label", :text => 'Mentor'
    assert_select "input[type=checkbox][value=?]", 'student'
    assert_select "label", :text => 'Student'

    remove_role_permission(fetch_role(:albers, :admin), 'add_non_admin_profiles')
    assert_false users(:f_admin).reload.can_add_non_admin_profiles?
    set_response_text(render_user_role_check_boxes({:program => program}))
    assert_select "input[type=checkbox]", count: 0
  end

  def test_render_user_role_check_boxes_from_other_program
    roles = programs(:albers).roles_without_admin_role
    set_response_text(render_user_role_check_boxes_from_other_program(roles))
    assert_select "label", text: "Mentor" do
      assert_select "input[type=checkbox][value=mentor]"
    end
    assert_select "label", text: "Student" do
      assert_select "input[type=checkbox][value=student]"
    end
    assert_select "label", text: "User" do
      assert_select "input[type=checkbox][value=user]"
    end

    roles = programs(:primary_portal).roles_without_admin_role
    set_response_text(render_user_role_check_boxes_from_other_program(roles))
    assert_select "label", text: "Employee" do
      assert_select "input[type=checkbox][value=employee]"
    end
  end

  def test_import_members_enabled
    current_user = users(:f_admin)
    self.expects(:current_user).at_least(0).returns(current_user)
    @current_organization = programs(:org_primary)

    # for standalone program
    @current_organization.expects(:standalone?).at_least(0).returns(true)
    current_user.expects(:import_members_from_subprograms?).at_least(0).returns(true)
    assert_false import_members_enabled?
    # import enabled for program
    @current_organization.expects(:standalone?).at_least(0).returns(false)
    current_user.expects(:import_members_from_subprograms?).at_least(0).returns(true)
    assert import_members_enabled?
  end

  def test_drafted_connections_indicator_with_drafted_connections
    organization = programs(:org_primary)
    user = users(:student_1)

    content = drafted_connections_indicator(user, organization)
    assert_match /1 drafted mentoring connection/, content[:content]
    assert_match /a[href=\/members\/#{user.member_id}?filter=4&amp;tab=manage_connections]/, content[:content]

    options = {}
    options[:draft_count] =  {user.id => 2}
    content = drafted_connections_indicator(user, organization, options)
    assert_match /2 drafted mentoring connections/, content[:content]
    assert_match /a[href=\/members\/#{user.member_id}?filter=4&amp;tab=manage_connections]/, content[:content]

    options[:draft_count] =  {users(:f_student).id => 2}
    content = drafted_connections_indicator(user, organization, options)
    assert_nil content

    group = groups(:group_5)
    group.update_attribute(:status, Group::Status::DRAFTED)
    content = drafted_connections_indicator(user, organization)
    assert_match /2 drafted mentoring connections/, content[:content]
    assert_match /a[href=\/members\/#{user.member_id}?filter=4&amp;tab=manage_connections]/, content[:content]

    content = drafted_connections_indicator(user, organization, options)
    assert_nil content
  end

  def test_drafted_connections_indicator_without_drafted_connections
    organization = programs(:org_primary)
    user = users(:f_admin)
    content = drafted_connections_indicator(user, organization)
    assert_nil content
  end

  def test_get_add_member_bulk_actions_box
    action_box_output = get_add_member_bulk_actions_box
    assert_select_helper_function_block "a[id=\"cjs_add_to_program\"][title=\"\"]", action_box_output, text: "Add to Program" do
      "i[class=\"fa fa-plus fa-fw m-r-xs\"]"
    end
  end

  def test_display_match_score
    self.expects(:current_program).at_least(1).returns(programs(:albers))
    assert_match "feature.user.label.not_a_match".translate, display_match_score(0)
    assert_match "feature.user.label.match".translate, display_match_score(10)
    assert_match "display_string.NA".translate, display_match_score(nil)

    # in listing page
    content = display_match_score(0, in_listing: true)
    assert_match /data-title=\"Not a match\" data-toggle=\"tooltip\">Not a Match/, content
    assert_no_match(/text-navy/, content)

    content = display_match_score(0, in_listing: true, match_score_color_class: "text-danger")
    assert_match "data-title=\"Not a match\" data-toggle=\"tooltip\">Not a Match", content
    assert_match "text-danger", content

    content = display_match_score(90, in_listing: true, tooltip_options: { second_person: "Mentee" })
    assert_match /data-title=\"This shows the compatibility percentage between Mentee and the mentor. Matching will be based on similar fields.\" data-toggle=\"tooltip\">/, content
    assert_match /text-navy/, content
    assert_match /90%.*span.*match/, content

    content = display_match_score(nil, in_listing: true)
    assert_match /data-title=\"Match score for this user is not available at this time, please try again later\" data-toggle=\"tooltip\">NA/, content
    assert_no_match(/text-navy/, content)

    content = display_match_score(90, in_listing: true, from_quick_connect: true)
    assert_no_match(/text-navy/, content)

    content = display_match_score(90, in_listing: true, show_favorite_ignore_links: true, mentor_id: 4)
    set_response_text(content)
    assert_select "h4.no-margins" do
        assert_select "span.mentor_favorite_4", 1
    end
  end

  def test_render_show_favorite_links
    content = render_show_favorite_links({mentor_id: 6})
    set_response_text(content)
    assert_select "span.mentor_favorite_6", 1
  end

  def test_display_match_score_with_label
    content = display_match_score(90, in_listing: true, tooltip_options: { second_person: "Mentee"}, mentor_id: 1)
    set_response_text(content)
    assert_match /data-title=\"This shows the compatibility percentage between Mentee and the mentor. Matching will be based on similar fields.\" data-toggle=\"tooltip\">/, content
    assert_match /text-navy/, content
    assert_match /90%.*span.*match/, content

    content = display_match_score(90, in_listing: true, tooltip_options: { second_person: "Mentee"}, mentor_id: 1)
    set_response_text(content)
    assert_match /data-title=\"This shows the compatibility percentage between Mentee and the mentor. Matching will be based on similar fields.\" data-toggle=\"tooltip\">/, content
    assert_match /text-navy/, content
    assert_match /90%.*span.*match/, content
    assert_select "a.cjs_show_match_details", 0
  end

  def test_render_ignore_preference_link
    content = render_ignore_preference_link({mentor_id: 5, ignore_preferences_hash: {3=>4, 5=>6}})
    set_response_text content
    assert_select "div.mentor_ignore_5"
  end

  def test_render_ignore_preference_dropdown
    set_response_text render_ignore_preference_dropdown({mentor_id: 5, recommendations_view: "explicit_pre_rec",show_match_config_matches: false})
    assert_select "div.btn-group" do
      assert_select "ul.dropdown-menu" do
        assert_select "a.cjs_create_ignore_preference", text: "Don't show again"
      end
    end
  end

  def test_display_alert
    content = display_alert("Matching in progress", "alert-warning")
    assert_match /Matching in progress/, content
    assert_select_helper_function "div.alert-warning.alert-dismissable", content do
      assert_select "button.close" do
        assert_select "i.fa-times"
      end
      assert_select "i.fa-info-circle"
    end
  end

  def test_get_result_pane_alert
    assert_nil get_result_pane_alert
    instance_variable_set(:@match_view, true)
    instance_variable_set(:@student_document_available, true)
    assert_nil get_result_pane_alert
    instance_variable_set(:@student_document_available, false)
    self.expects(:display_match_score_unavailable_flash).twice
    get_result_pane_alert
    instance_variable_set(:@from_global_search, true)
    User.any_instance.stubs(:can_manage_user_states?).returns(true)
    get_result_pane_alert
    instance_variable_set(:@match_view, false)
    self.expects(:display_deactivated_users_omitted_flash)
    get_result_pane_alert
  end

  def test_display_match_score_unavailable_flash
    self.expects(:display_alert).with("feature.user.content.match_score_not_available_yet".translate(mentors: _mentors), "alert-warning")
    display_match_score_unavailable_flash
  end

  def test_display_deactivated_users_omitted_flash
    all_users = link_to("feature.admin_view.content.all_users".translate, admin_view_all_users_path)
    self.expects(:display_alert).with("feature.user.content.deactivated_not_listed_html".translate(all_users: all_users), "alert-info")
    display_deactivated_users_omitted_flash
  end

  def test_show_compatibility_link
    can_see_match_label = false
    show_match_details = false
    match_score = 0
    assert_false show_compatibility_link?(can_see_match_label, show_match_details, match_score)

    can_see_match_label = true
    assert_false show_compatibility_link?(can_see_match_label, show_match_details, match_score)

    show_match_details = true
    assert_false show_compatibility_link?(can_see_match_label, show_match_details, match_score)

    match_score = nil
    assert_false show_compatibility_link?(can_see_match_label, show_match_details, match_score)
    
    match_score = 10
    assert show_compatibility_link?(can_see_match_label, show_match_details, match_score)
  end

  def test_display_profile_summary
    user = users(:f_mentor)
    program = programs(:albers)

    education = program.organization.profile_questions.where(question_text: "Education").first
    work = program.organization.profile_questions.where(question_text: "Work").first
    assert work.position > education.position
    save_positions = [ education.position, work.position ]
    education.position , work.position = [ work.position, education.position ]  # swapping positions
    education.save!
    work.save!

    in_summary_questions = program.in_summary_role_profile_questions_excluding_name_type(RoleConstants::MENTOR_NAME, users(:f_admin))

    self.expects(:current_user).at_least(1).returns(users(:f_admin))
    content = display_profile_summary(user, in_summary_questions)
    assert_match /.*Location.*<i class=\"fa fa-map-marker m-r-xs\"><\/i>Chennai, Tamil Nadu, India/, content
    assert_match /.*Education.*<i class=\"text-muted\">Not Specified/, content
    assert_match /.*Work.*<i class=\"text-muted\">Not Specified/, content
    # Test that Work is displayed before Education
    assert_match /Work.*Education/, content

    # Revert old positions as other tests might depend on them
    education.position, work.position = save_positions
    education.save!
    work.save!
  end

  def test_display_profile_summary_in_hovercard
    user = users(:f_mentor)
    program = programs(:albers)
    in_summary_questions = program.in_summary_role_profile_questions_excluding_name_type(RoleConstants::MENTOR_NAME, users(:f_admin))

    self.expects(:current_user).at_least(1).returns(users(:f_admin))
    content = display_profile_summary(user, in_summary_questions, true)

    set_response_text content
    assert_select "div[class=\"form-horizontal\"]" do
      assert_select "div[class=\"m-b-xs form-group form-group-sm\"]" do
        assert_select "label[class=\"col-sm-3 text-right m-b-0 m-t-xxs h6 font-600 word_break\"][valign=\"top\"]", text: "Location"
        assert_select "div[class=\"col-sm-9\"]", text: "Chennai, Tamil Nadu, India" do
          assert_select "i[class=\"fa fa-map-marker m-r-xs\"]"
        end
      end
    end
  end

  def test_group_in_hovercard
    user = users(:f_mentor)
    profile_viewer = users(:f_admin)
    group = user.groups.first

    html_content = to_html(group_in_hovercard(group, user, profile_viewer))
    assert_select html_content, "div.media" do
      assert_select "div.media-left" do
        assert_select "img"
      end

      assert_select html_content, "div.media-body" do
        assert_select "div", :text => group.name + RoleConstants.human_role_string(user.role_names, :program => user.program)
      end
    end
  end

  def test_show_user_groups_in_hovercard
    profile_user = users(:f_mentor)
    profile_viewer = users(:f_admin)
    groups = profile_user.groups

    html_content = to_html(show_user_groups_in_hovercard(groups, profile_user, profile_viewer))
    assert_select html_content, "div" do
      groups.each do |group|
        group_in_hovercard(group, profile_user, profile_viewer)
      end
    end
  end

  def test_display_hovercard_actions
    viewer = users(:f_admin)
    action_1 = link_to("link1", "#")
    action_2 = link_to("link2", "#")

    assert_equal content_tag(:span, action_1, class: "small"), display_hovercard_actions([action_1], viewer, 1)

    assert_equal "<span class=\"small\"><a href=\"#\">link1</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><div class=\"group-filters btn-group\"><a data-toggle=\"dropdown\" href=\"javascript:void(0);\">Manage<i class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"></i></a><ul class=\"dropdown-menu\"><li><a href=\"#\">link2</a></li></ul></div></span>", display_hovercard_actions([action_1, action_2], viewer, 1)
    assert_equal "<span class=\"small\"><a href=\"#\">link1</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><div class=\"group-filters btn-group\"><a data-toggle=\"dropdown\" href=\"javascript:void(0);\">Actions<i class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"></i></a><ul class=\"dropdown-menu\"><li><a href=\"#\">link2</a></li></ul></div></span>", display_hovercard_actions([action_1, action_2], users(:f_mentor), 1)
    assert_equal "<span class=\"small\"><a href=\"#\">link1</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><a href=\"#\">link2</a></span>", display_hovercard_actions([action_1, action_2], users(:f_mentor), 2)
  end

  def test_dropdown_in_hovercard
    action_1 = link_to("link1", "#")
    action_2 = link_to("link2", "#")
    actions = [action_1, action_2]
    title = "title"

    html_content = to_html(dropdown_in_hovercard(title, actions))

    assert_select html_content, "div.group-filters.btn-group" do
      assert_select "a", :text => title, :count => 1
      assert_select "ul.dropdown-menu" do
        actions.each do |action|
          content_tag(:li, action)
        end
      end
    end
  end

  def test_get_hovercard_actions_for_admin
    admin_viewer = users(:f_admin)
    mentor = users(:f_mentor)
    student = users(:f_student)
    @current_organization = programs(:org_primary)
    @current_program = programs(:albers)
    @current_program.update_attribute(:max_connections_for_mentee, 1)

    # admin views mentor - Message
    content = get_hovercard_actions(admin_viewer, mentor, mentor.groups.first)

    assert_equal "<span class=\"small\"><a href=\"/messages/new?receiver_id=3&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><a class=\"wob_link user_action_link\" rel=\"nofollow\" data-method=\"post\" href=\"/users/#{mentor.id}/work_on_behalf\">Work on Behalf</a></span>", content

    # admin views mentee - Message and Find a mentor
    content = get_hovercard_actions(admin_viewer, student, student.groups.first)

    assert_equal "<span class=\"small\"><a href=\"/messages/new?receiver_id=2&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><a class=\"wob_link user_action_link\" rel=\"nofollow\" data-method=\"post\" href=\"/users/2/work_on_behalf\">Work on Behalf</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><div class=\"group-filters btn-group\"><a data-toggle=\"dropdown\" href=\"javascript:void(0);\">Manage<i class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"></i></a><ul class=\"dropdown-menu\"><li><a href=\"/users/matches_for_student?src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}&amp;student_name=student+example+%3Crahim%40example.com%3E\">Find a Mentor</a></li></ul></div></span>", content

    # Checking the same if organization subscription type is basic
    @current_organization.organization_features.map(&:destroy)
    @current_organization.subscription_type = Organization::SubscriptionType::BASIC
    @current_organization.save!
    @current_organization.make_subscription_changes
    @current_organization.programs.each{|p| p.make_subscription_changes}

    content = get_hovercard_actions(admin_viewer, student, student.groups.first)
    assert_equal "<span class=\"small\"><a href=\"/messages/new?receiver_id=2&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><a class=\"wob_link user_action_link\" rel=\"nofollow\" data-method=\"post\" href=\"/users/2/work_on_behalf\">Work on Behalf</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><div class=\"group-filters btn-group\"><a data-toggle=\"dropdown\" href=\"javascript:void(0);\">Manage<i class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"></i></a><ul class=\"dropdown-menu\"><li><a href=\"/users/matches_for_student?src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}&amp;student_name=student+example+%3Crahim%40example.com%3E\">Find a Mentor</a></li></ul></div></span>", content
  end

  def test_get_hovercard_actions_for_mentor_viewing_mentee
    mentor_viewer = users(:f_mentor)
    connected_mentee = users(:mkr_student)
    non_connected_mentee = users(:f_student)
    @current_program = programs(:albers)
    @current_program.enable_feature(FeatureName::CALENDAR, true)
    @current_program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    programs(:org_primary).enable_feature(FeatureName::OFFER_MENTORING, true)
    @current_program.reload

    # Connected - Message, Go to mentoring area
    content = get_hovercard_actions(mentor_viewer, connected_mentee, false)
    assert_match "<a href=\"/groups/#{groups(:mygroup).id}?src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Go to #{h(groups(:mygroup).name)}</a>", content
    assert_match "<a href=\"/messages/new?receiver_id=#{connected_mentee.member_id}&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a>", content

    # Non-Connected - Offer doesnt need acceptance - Messages, Add as mentee
    content = get_hovercard_actions(mentor_viewer, non_connected_mentee, false)
    assert_match "<a href=\"/messages/new?receiver_id=#{non_connected_mentee.member_id}&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a>", content
    assert_match "<a data-click=\"OfferMentoring.renderPopup(&#39;/mentor_offers/new?src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}&amp;student_id=#{non_connected_mentee.id}&#39;)\" href=\"javascript:void(0)\">Offer Mentoring</a>", content

    # Non-Connected - Offer needs acceptance - Messages, New mentor offer
    @current_program.update_attribute(:mentor_offer_needs_acceptance, true)
    content = get_hovercard_actions(mentor_viewer, non_connected_mentee, false)
    assert_match "<a href=\"/messages/new?receiver_id=#{non_connected_mentee.member_id}&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a>", content
    assert_match "<a data-click=\"OfferMentoring.renderPopup(&#39;/mentor_offers/new?src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}&amp;student_id=#{non_connected_mentee.id}&#39;)\" href=\"javascript:void(0)\">Offer Mentoring</a>", content

    # mentor does not opt for ongoing mentoring
    mentor_viewer.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    content = get_hovercard_actions(mentor_viewer, non_connected_mentee, false)
    assert_no_match /Offer Mentoring/, content

    # offer mentoring is not enabled
    @current_program.enable_feature(FeatureName::OFFER_MENTORING, false)
    content = get_hovercard_actions(mentor_viewer, non_connected_mentee, false)
    assert_no_match /Offer Mentoring/, content

    # Non-Connected - Offer pending - Messages, Offer Pending
    @current_program.enable_feature(FeatureName::OFFER_MENTORING, true)
    mentor_viewer.update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    create_mentor_offer
    content = get_hovercard_actions(mentor_viewer, non_connected_mentee, false)
    assert_match "<a href=\"/messages/new?receiver_id=#{non_connected_mentee.member_id}&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a>", content
    assert_match "<a class=\"dim\" href=\"javascript:void(0);\">Mentoring Offer Pending</a>", content
    assert_no_match /dropdown-toggle/, content

    # checking conditions for offer mentoring
    @current_program = programs(:pbe)
    content = get_hovercard_actions(users(:pbe_mentor_1), users(:pbe_student_3), false)
    assert_no_match /Offer Mentoring/, content
  end

  def test_get_hovercard_actions_for_mentee_viewing_mentor
    time = Time.now
    Time.stubs(:now).returns(time)
    mentee_viewer = users(:mkr_student)
    connected_mentor = users(:f_mentor)
    group = Group.involving(mentee_viewer, connected_mentor).active.first
    non_connected_mentor = users(:f_mentor_student)

    @current_program = programs(:albers)
    @current_program.enable_feature(FeatureName::CALENDAR, true)
    @current_program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([false, ""])
    @current_program.reload

    # Connected - Message, Go to mentoring area and Meeting - Dropdown, more than 2 actions
    content = get_hovercard_actions(mentee_viewer, connected_mentor, nil)
    assert_select_helper_function "a[href=\"/groups/#{groups(:mygroup).id}?src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"]", content, text: "Go to #{groups(:mygroup).name}"
    assert_select_helper_function "a[href=\"/messages/new?receiver_id=#{connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"]", content, text: "Message"
    assert_select_helper_function "a[data-click=\"Meetings.renderMiniPopup('/meetings/mini_popup?member_id=3&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}')\"][href=\"javascript:void(0)\"][id=\"\"][title=\"\"]", content, text: "Request Meeting"
    assert_select_helper_function_block "a[data-toggle=\"dropdown\"][href=\"javascript:void(0);\"]", content, text: "Actions" do
      assert_select "i[class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"]"
    end

    # Non Connected - Message, New mentor request and Meeting - Dropdown, more than 2 actions
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_select_helper_function "a[class=\" cjs_request_mentoring_button mentor_request\"][data-url=\"/mentor_requests/new.js?mentor_id=5&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"][href=\"javascript:void(0)\"][id=\"\"][title=\"\"]", content, {text: "Request Mentoring Connection"}
    assert_select_helper_function "a[href=\"/messages/new?receiver_id=#{non_connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"]", content, text: "Message"
    assert_select_helper_function "a[data-click=\"Meetings.renderMiniPopup('/meetings/mini_popup?member_id=#{non_connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}')\"][href=\"javascript:void(0)\"][id=\"\"][title=\"\"]", content, text: "Request Meeting"
    assert_select_helper_function_block "a[data-toggle=\"dropdown\"][href=\"javascript:void(0);\"]", content, text: "Actions" do
      assert_select "i[class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"]"
    end

    # changing engagement type of program to project based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_no_match /Request Mentoring Connection/, content

    # mentor does not opt for ongoing mentoring
    @current_program.enable_feature(FeatureName::CALENDAR, true)
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    @current_program.reload
    non_connected_mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_match /Request Mentoring Connection/, content
    assert_match "Mentor is not available for ongoing mentoring.", content

    # Non Connected - Not allowed to send mentor request
    non_connected_mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING)
    @current_program.update_attribute(:allow_mentoring_requests, false)
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_no_match /mentor_requests\/new/, content
    assert_match "The program administrator does not allow you to send any requests.", content
    assert_select_helper_function "a[href=\"/messages/new?receiver_id=#{non_connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"]", content, text: "Message"
    assert_select_helper_function "a[data-click=\"Meetings.renderMiniPopup('/meetings/mini_popup?member_id=#{non_connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}')\"][href=\"javascript:void(0)\"][id=\"\"][title=\"\"]", content, text: "Request Meeting"
    assert_select_helper_function_block "a[data-toggle=\"dropdown\"][href=\"javascript:void(0);\"]", content, text: "Actions" do
      assert_select "i[class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"]"
    end

    # Non Connected - Message, View mentor requests and Meeting - Dropdown, more than 2 actions
    @current_program.update_attribute(:allow_mentoring_requests, true)
    mentor_request = create_mentor_request(mentor: non_connected_mentor, student: mentee_viewer)
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_select_helper_function "a[class=\"\"][href=\"/mentor_requests?filter=by_me&mentor_request_id=#{mentor_request.id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"]", content
    assert_select_helper_function "a[href=\"/messages/new?receiver_id=#{non_connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"]", content, text: "Message"
    assert_select_helper_function "a[data-click=\"Meetings.renderMiniPopup('/meetings/mini_popup?member_id=#{non_connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}')\"][href=\"javascript:void(0)\"][id=\"\"][title=\"\"]", content, text: "Request Meeting"
    assert_select_helper_function_block "a[data-toggle=\"dropdown\"][href=\"javascript:void(0);\"]", content, text: "Actions" do
      assert_select "i[class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"]"
    end
    # mentor is not opting for one time mentoring
    non_connected_mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_match /Request Meeting/, content
    assert_match /Mentor is not available for meetings./, content

    # Connected - Provide a rating
    mentee_viewer.program.enable_feature(FeatureName::COACH_RATING)
    content = get_hovercard_actions(mentee_viewer, connected_mentor, group)
    assert_select_helper_function_block "span[class=\"small\"]", content do
      assert_select "a[href=\"/messages/new?receiver_id=#{connected_mentor.id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\"]", text: "Message"
      assert_select "small > small" do
        assert_select "i[class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"]"
      end
      assert_select "div[class=\"group-filters btn-group\"]" do
        assert_select "a[data-toggle=\"dropdown\"][href=\"javascript:void(0);\"]", text: "Actions" do
          assert_select "i[class=\"fa fa-caret-down m-r-0 m-l-xxs fa-fw m-r-xs\"]"
        end
        assert_select "ul.dropdown-menu" do
          assert_select "li > a[data-click=\"Meetings.renderMiniPopup('/meetings/mini_popup?member_id=#{connected_mentor.member_id}&src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}')\"][href=\"javascript:void(0)\"][id=\"\"][title=\"\"]", text: "Request Meeting"
          assert_select "li > a[class=\"cjs_mentor_rating\"][data-url=\"/feedback_responses/new?group_id=1&recipient_id=3\"][href=\"javascript:void(0)\"][id=\"mentor_rating_#{connected_mentor.id}\"]", text: "Provide a rating"
        end
      end
    end

    # Only admin is allowed to assign mentoring request
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    @current_program.update_attribute(:mentor_request_style, Program::MentorRequestStyle::NONE)
    non_connected_mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_no_match /Request Mentoring Connection/, content
  end

  def test_get_hovercard_actions_for_mentee_viewing_mentor_meeting_limit_reached
    time = Time.now
    Time.stubs(:now).returns(time)
    mentee_viewer = users(:mkr_student)
    connected_mentor = users(:f_mentor)
    group = Group.involving(mentee_viewer, connected_mentor).active.first
    non_connected_mentor = users(:f_mentor_student)

    @current_program = programs(:albers)
    @current_program.enable_feature(FeatureName::CALENDAR, true)
    @current_program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    @current_program.reload
    # mentor capacity has been reached
    non_connected_mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING)
    time = Time.now
    Time.stubs(:now).returns(time)
    non_connected_mentor.user_setting.update_attributes!(:max_meeting_slots => 0)
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_match /Request Meeting/, content
    assert_match "#{non_connected_mentor.name(name_only: true)} has already reached the limit for the number of meetings and is not available for meetings", content

    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([false, ""])
    content = get_hovercard_actions(mentee_viewer, non_connected_mentor, nil)
    assert_match /Request Meeting/, content
    assert_no_match "#{non_connected_mentor.name(name_only: true)} has already reached the limit for the number of meetings and is not available for meetings", content
  end

  def test_get_hovercard_actions_for_non_mentoring_user
    viewer = users(:f_admin)
    user = users(:f_user)
    @current_program = programs(:albers)

    content = get_hovercard_actions(viewer, user, nil)
    assert_equal "<span class=\"small\"><a href=\"/messages/new?receiver_id=4&amp;src=#{EngagementIndex::Src::MessageUsers::HOVERCARD}\">Message</a><small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs fa-fw m-r-xs\"></i></small></small><a class=\"wob_link user_action_link\" rel=\"nofollow\" data-method=\"post\" href=\"/users/4/work_on_behalf\">Work on Behalf</a></span>", content
  end

  def test_status_filter_links_ajax
    filter_fields = [{:value=>"calendar_availability", :label=>"Available for a meeting", :class=>"available_for_a_meeting"}, {:value=>"available", :label=>"Available for a long term mentoring connection", :class=>"long_term_availability"}]
    content = status_filter_links_ajax(filter_fields, nil, true, {show_as_radio: false})
    assert_nil content.match(/type=\"radio\"/)
    assert_not_nil content.match(/name=\"filter\"/)
    assert_not_nil content.match(/type=\"checkbox\"/)
    content = status_filter_links_ajax(filter_fields, nil, true, {show_as_radio: true})
    assert_not_nil content.match(/type=\"radio\"/)
    assert_not_nil content.match(/name=\"filter\"/)
    assert_nil content.match(/type=\"checkbox\"/)
    @role = RoleConstants::MENTOR_NAME
    content = status_filter_links_ajax(filter_fields, nil, true, {show_as_radio: false})
    assert_not_nil content.match(/name=\"filter\[\]\"/)
  end

  def test_is_long_term_availability_filter
    assert_false is_long_term_availability_filter?({})
  end

  def test_is_long_term_availability_filter_true
    assert is_long_term_availability_filter?({value: "available"})
  end

  def test_is_long_term_availability_filter_false
    assert_false is_long_term_availability_filter?({value: "calendar_availability"})
  end

  def test_is_calendar_filter
    assert is_calendar_filter?(value: "calendar_availability")
  end

  def test_connections_and_activity_items_contract_management
    @profile_user = users(:f_mentor)
    @current_program = programs(:albers)

    total_coaching_hours = total_coaching_hours(@profile_user)
    assert (not connections_and_activity_items.include? total_coaching_hours)

    @current_program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    total_coaching_hours = total_coaching_hours(@profile_user)
    assert (not connections_and_activity_items.include? total_coaching_hours)

    @current_program.enable_feature(FeatureName::CONTRACT_MANAGEMENT)
    total_coaching_hours = total_coaching_hours(@profile_user)

    @is_owner_mentor = @profile_user.is_mentor?
    assert (connections_and_activity_items.include? total_coaching_hours)

    meeting_checkin_hours = @profile_user.group_checkins_duration

    task = create_mentoring_model_task
    task_checkin1 = create_task_checkin(task, :duration => 60)
    task_checkin2 = create_task_checkin(task, :duration => 45)
    assert_equal task.checkins, [task_checkin1, task_checkin2]
    assert_equal task.group_checkins_duration, 105

    @profile_user.reload
    total_coaching_hours = total_coaching_hours(@profile_user)
    expected_total_coaching_hours = meeting_checkin_hours + 1.75
    assert_equal ["Total mentoring hours", "<span>7.75</span>"], total_coaching_hours
    assert (connections_and_activity_items.include? total_coaching_hours)

    current_user_is :f_admin
    @is_admin_view = @current_user.is_admin?

    total_coaching_hours = total_coaching_hours(@profile_user)
    assert_equal ["<a href=\"/group_checkins?user=3\">Total mentoring hours</a>",
        "<span>7.75</span>"], total_coaching_hours
    assert (connections_and_activity_items.include? total_coaching_hours)
  end

  def test_connections_and_activity_items
    @profile_user = users(:f_mentor)
    @current_program = programs(:albers)

    @is_owner_admin_only = false
    ongoing_connections = ongoing_connections_metatdata(@profile_user)
    past_connections = closed_connections_metatdata(@profile_user)
    activity_items = [ongoing_connections, past_connections]

    assert_equal_unordered activity_items, connections_and_activity_items

    @is_admin_view = true
    activity_items.shift(2) # For admin the connection links are different
    Program.any_instance.expects(:draft_connections_enabled?).at_least(0).returns(true)
    activity_items << profile_completeness_metatdata(@profile_user)
    activity_items << draft_connections_metatdata(@profile_user)
    activity_items << ongoing_connections_metatdata(@profile_user)
    activity_items << closed_connections_metatdata(@profile_user)
    assert_equal_unordered activity_items.compact, connections_and_activity_items

    @is_owner_mentor = true
    Program.any_instance.expects(:matching_by_mentee_alone?).at_least(1).returns(true)
    activity_items << available_slots_metatdata(@profile_user)
    activity_items << average_request_response_time_metatdata(@profile_user)
    activity_items << pending_mentor_requests_metadata(@profile_user)
    assert_equal_unordered activity_items.compact, connections_and_activity_items

    @is_owner_student = true
    Program.any_instance.expects(:matching_by_mentee_alone?).at_least(0).returns(true)
    activity_items << requests_initiated_metatdata(@profile_user)
    assert_equal_unordered activity_items.compact, connections_and_activity_items

    @current_and_next_month_session_slots = 5
    Program.any_instance.expects(:mentoring_connections_v2_enabled?).at_least(0).returns(true)
    activity_items << past_meetings_metatdata(@profile_user)
    assert_equal_unordered activity_items.compact, connections_and_activity_items

    Program.any_instance.expects(:mentoring_connections_v2_enabled?).at_least(0).returns(false)
    Program.any_instance.expects(:calendar_enabled?).at_least(0).returns(true)
    activity_items << past_meetings_metatdata(@profile_user)
    activity_items << meetings_requests_initiated_metatdata(@profile_user)
    activity_items << slots_available_metatdata(@current_and_next_month_session_slots)
    activity_items << average_meeting_response_time_metatdata(@profile_user)
    assert_equal_unordered activity_items.compact, connections_and_activity_items

    Program.any_instance.expects(:mentor_offer_enabled?).at_least(0).returns(true)
    activity_items << mentor_offers_requests_initiated_metatdata(@profile_user)
    activity_items << nil
    assert_equal_unordered activity_items.compact, connections_and_activity_items
  end

  def test_connections_and_activity_items_for_program_with_disabled_ongoing_mentoring
    @profile_user = users(:f_mentor)
    @current_program = programs(:albers)

    # changing engagement type of program to career and ongoing based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)

    @is_owner_admin_only = false
    @is_admin_view = true
    @is_owner_mentor = true
    @is_owner_student = true
    Program.any_instance.expects(:matching_by_mentee_alone?).at_least(0).returns(true)
    Program.any_instance.expects(:draft_connections_enabled?).at_least(0).returns(true)
    Program.any_instance.expects(:mentor_offer_enabled?).at_least(0).returns(true)
    ongoing_connections = ongoing_connections_metatdata(@profile_user)
    past_connections = closed_connections_metatdata(@profile_user)
    draft_connections = draft_connections_metatdata(@profile_user)
    profile_completeness = profile_completeness_metatdata(@profile_user)
    available_slots = available_slots_metatdata(@profile_user)
    pending_mentor_requests = pending_mentor_requests_metadata(@profile_user)
    average_request_response = average_request_response_time_metatdata(@profile_user)
    requests_initiated = requests_initiated_metatdata(@profile_user)
    mentor_offers_requests = mentor_offers_requests_initiated_metatdata(@profile_user)

    activity_items = [ongoing_connections, past_connections, draft_connections, profile_completeness, available_slots, average_request_response, pending_mentor_requests, requests_initiated, mentor_offers_requests]

    assert_equal_unordered activity_items.compact, connections_and_activity_items

    # changing engagement type of program to career based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    connections_and_activity_with_ongoing_mentoring_disabled = connections_and_activity_items

    assert_false connections_and_activity_with_ongoing_mentoring_disabled.include?(ongoing_connections)
    assert_false connections_and_activity_with_ongoing_mentoring_disabled.include?(past_connections)
    assert_false connections_and_activity_with_ongoing_mentoring_disabled.include?(draft_connections)
    assert_false connections_and_activity_with_ongoing_mentoring_disabled.include?(available_slots)
    assert_false connections_and_activity_with_ongoing_mentoring_disabled.include?(average_request_response)
    assert_false connections_and_activity_with_ongoing_mentoring_disabled.include?(requests_initiated)
    assert_false connections_and_activity_with_ongoing_mentoring_disabled.include?(mentor_offers_requests)
  end

  def test_prepare_response_time
    user = users(:f_mentor)
    requests = user.received_mentor_requests.answered
    requests.each { |request| request.update_attributes(updated_at: request.created_at + 30.days) }
    assert_equal 720, prepare_response_time(requests) # 30 days = 720 hours
    requests.each { |request| request.update_attributes(updated_at: request.created_at + 20.minutes) }
    assert_equal 0.33, prepare_response_time(requests)
  end

  def test_calendar_specific_filters_for_program_with_disabled_ongoing_mentoring
    @current_program = programs(:albers)

    # changing engagement type of program to career and ongoing based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)

    user = users(:f_admin)
    filter_options = calendar_specific_filters(user)
    availability_option = {:value=>"available", :label=>"Available for a long term mentoring connection", :class=>"long_term_availability", :section=>"mentor_availability_"}
    assert filter_options.include?(availability_option)

    # changing engagement type of program to career based
    @current_program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    filter_options = calendar_specific_filters(user)
    assert_false filter_options.include?(availability_option)
  end

  def test_time_in_hours_days_weeks
    assert_equal_unordered [24, 'minute'], time_in_hours_days_weeks(0.4)
    assert_equal_unordered [1.5, "day"], time_in_hours_days_weeks(47)
    assert_equal_unordered [1.5, "week"], time_in_hours_days_weeks(312)#24*13
    assert_equal_unordered [36, "minute"], time_in_hours_days_weeks(0.6)
    assert_equal_unordered [2, "hour"], time_in_hours_days_weeks(1.75)
  end

  def test_update_profile_message_success
    user = users(:f_student)
    current_program_is :albers
    @current_program = programs(:albers)
    self.expects(:render).with(:partial => "programs/profile_update_notification", :locals => {:profile_incomplete_roles => user.role_names})
    User.any_instance.expects(:profile_incomplete_roles).returns(user.role_names)
    update_profile_message(user)
  end

  def test_update_profile_message_failure
    user = users(:f_student)
    current_program_is :albers
    @current_program = programs(:albers)
    self.expects(:render).times(0).with(:partial => "programs/profile_update_notification", :locals => {:profile_incomplete_roles => user.role_names})
    User.any_instance.expects(:profile_incomplete_roles).returns([])
    update_profile_message(user)
  end

  def test_display_coach_rating_and_reviews
    program = programs(:albers)
    mentor = users(:mentor_1)

    content1 = display_coach_rating_and_reviews(mentor)
    assert_select_helper_function_block "div[class=\"cui_rating_content cui_zero_rating\"]", content1 do
      assert_select "div[class=\"display-star-rating m-r-xxs pull-left \"][data-score=\"0\"][data-title=\"Not rated yet.\"][data-toggle=\"tooltip\"][id=\"mentor_rating_#{mentor.id}\"]"
    end

    feedback_form = programs(:albers).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    response = Feedback::Response.create_from_answers(
        users(:student_2), mentor, 1, groups(:group_inactive), feedback_form, {feedback_form.questions.first.id => 'He was not ok'})
    content2 = display_coach_rating_and_reviews(mentor.reload)
    assert_select_helper_function_block "div[class=\"cui_rating_content cui_has_rating\"]", content2 do
      assert_select "div[class=\"display-star-rating m-r-xxs pull-left \"][data-score=\"1.0\"][data-title=\"1.0\"][data-toggle=\"tooltip\"][id=\"mentor_rating_26\"]"
      assert_select "span[class=\"small\"]", text: "(1 rating)" do
        assert_select "a[class=\"show_mentor_ratings\"][data-url=\"/users/26/reviews\"][href=\"javascript:void(0)\"][id=\"mentor_reviews_#{mentor.id}\"]", text: "1 rating"
      end
    end
  end

  def test_display_coach_rating
    program = programs(:albers)
    mentor = users(:mentor_1)

    content1 = display_coach_rating(mentor, 0)
    assert_select_helper_function "div[class=\"display-star-rating m-r-xxs pull-left \"][data-score=\"0\"][data-title=\"Not rated yet.\"][data-toggle=\"tooltip\"][id=\"mentor_rating_26\"]", content1

    feedback_form = programs(:albers).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    response = Feedback::Response.create_from_answers(
        users(:student_2), mentor, 1, groups(:group_inactive), feedback_form, {feedback_form.questions.first.id => 'He was not ok'})
    content2 = display_coach_rating(mentor.reload, 1.0)
    assert_select_helper_function "div[class=\"display-star-rating m-r-xxs pull-left \"][data-score=\"1.0\"][data-title=\"1.0\"][data-toggle=\"tooltip\"][id=\"mentor_rating_#{mentor.id}\"]", content2
  end

  def test_coach_reviews_link
    program = programs(:albers)
    mentor = users(:mentor_1)

    content1 = coach_reviews_link(mentor)
    assert_nil content1

    feedback_form = programs(:albers).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    response = Feedback::Response.create_from_answers(
        users(:student_2), mentor, 1, groups(:group_inactive), feedback_form, {feedback_form.questions.first.id => 'He was not ok'})
    content2 = coach_reviews_link(mentor.reload)
    assert_equal "<span class=\"small\">(<a class=\"show_mentor_ratings\" id=\"mentor_reviews_#{mentor.id}\" data-url=\"/users/#{mentor.id}/reviews\" href=\"javascript:void(0)\">1 rating</a>)</span>", content2
  end

  def test_reviews_link_text
    assert_equal "1 rating", reviews_link_text(1)
    assert_equal "2 ratings", reviews_link_text(2)
  end

  def test_display_rating
    assert_equal "<span class=\"display-star-rating\" data-score=\"3\"></span>", display_rating(3)
  end

  def test_can_show_rating_to_the_viewer
    program = programs(:albers)
    viewer = users(:f_admin)
    # feature is disabled
    assert_false can_show_rating_to_the_viewer?(program, viewer)

    #enabling feature
    program.enable_feature(FeatureName::COACH_RATING, true)
    assert can_show_rating_to_the_viewer?(program, viewer)

    #with no permission
    assert_false can_show_rating_to_the_viewer?(program, users(:f_student))

    #viewer object is nil
    assert_false can_show_rating_to_the_viewer?(program, nil)
  end

  def test_can_show_rating_for_the_user
    program = programs(:albers)
    viewer = users(:f_admin)
    user = users(:f_mentor)

    #enabling the feature
    program.enable_feature(FeatureName::COACH_RATING, true)
    assert can_show_rating_for_the_user?(program, user, viewer)

    #user is not a mentor
    assert_false can_show_rating_for_the_user?(program, users(:f_student), viewer)

    #user is nil
    assert_false can_show_rating_for_the_user?(program, nil, viewer)
  end

  def test_available_groups_for_user_profile
    viewing_user = users(:f_mentor)
    profile_user = users(:f_student)
    program = programs(:albers)
    profile_user.stubs(:public_groups_available_for_others_to_join).returns(['apple'])

    self.stubs(:group_in_users_listing).with('apple', viewing_user, program).returns('something')
    html_content = to_html(available_groups_for_user_profile(profile_user, viewing_user, program))
    assert_select html_content, "div", :text => "something"
  end

  def test_group_in_users_listing
    group = groups(:mygroup)
    user = users(:f_admin)
    program = programs(:albers)
    group.stubs(:logo_url).returns('some_url')
    self.stubs(:group_title_and_action_in_user_profile).with(user, group).returns("some title")
    self.stubs(:max_mentoring_connection_members_in_profile_for).with(program).returns("some number")
    self.stubs(:group_members_for_users_listing).with(group, "some number").returns("some users")
    html_content = group_in_users_listing(group, user, program)

    assert_select_helper_function_block "div", html_content do
      assert_select "div.group-logo" do
        assert_select "img"
      end
      assert_select "div.group-title", :text => "some title"
      assert_select "div.group-users", :text => "some users"
    end
  end

  def test_group_members_for_users_listing
    group = groups(:mygroup)
    group.stubs(:members).returns([])
    self.stubs(:user_picture).returns("apple")
    content = group_members_for_users_listing(group, 3)

    assert_blank content

    group.stubs(:members).returns([1,2])
    html_content = group_members_for_users_listing(group, 3)

    assert_select_helper_function_block "span", html_content do
      assert_select "a", text: "apple", count: 4
      assert_select "a.ct_show_more_link", count: 0
    end

    group.stubs(:members).returns([1,2,3])
    html_content = group_members_for_users_listing(group, 3)
    assert_select_helper_function_block "span", html_content do
      assert_select "a", text: "apple", count: 6
      assert_select "a.ct_show_more_link", count: 0
    end

    group.stubs(:members).returns([1,2,3,4,5,6,7,8,9])
    html_content = group_members_for_users_listing(group, 3)
    assert_select_helper_function_block "span", html_content do
      assert_select "a", text: "apple", count: 6
      assert_select "a.ct_show_more_link", text: "+6", count: 1
    end

    group.stubs(:mentors).returns([1,2,3,4,5,6,7,8,9])
    html_content = group_members_for_users_listing(group, 3, {mentors_only: true})
    assert_select_helper_function_block "span", html_content do
      assert_select "a", text: "apple", count: 6
      assert_select "a.ct_show_more_link", text: "+6", count: 1
    end

    group.stubs(:students).returns([1,2,3,4,5,6,7,8,9])
    html_content = group_members_for_users_listing(group, 3, {students_only: true})
    assert_select_helper_function_block "span", html_content do
      assert_select "a", text: "apple", count: 6
      assert_select "a.ct_show_more_link", text: "+6", count: 1
    end

    group.stubs(:custom_users).returns([1,2,3,4,5,6,7,8,9])
    html_content = group_members_for_users_listing(group, 3, {teachers_only: true})
    assert_select_helper_function_block "span", html_content do
      assert_select "a", text: "apple", count: 6
      assert_select "a.ct_show_more_link", text: "+6", count: 1
    end
  end

  def test_group_title_and_action_in_user_profile
    group = groups(:mygroup)
    user = users(:f_admin)
    assert_false user.can_apply_for_join?(group)
    html_content = to_html(group_title_and_action_in_user_profile(user, group))
    assert_select html_content, "a.larger", text: group.name, count: 1
    assert_select html_content, "a", text: "feature.connection.action.Join".translate(Mentoring_Connection: _Mentoring_Connection), count: 0

    user.stubs(:can_apply_for_join?).with(group).returns(true)
    html_content = to_html(group_title_and_action_in_user_profile(user, group))
    assert_select html_content, "a.larger", text: group.name, count: 1
    assert_select html_content, "a", text: "feature.connection.action.Join".translate(Mentoring_Connection: _Mentoring_Connection), count: 1

    html_content = to_html(group_title_and_action_in_user_profile(users(:f_admin), group, {:class => "medium", :show_roles => true, :group_member => users(:f_mentor)}))

    assert_select html_content, "div" do
      assert_select "a.medium", text: group.name, count: 1
      assert_select "div#user_roles", :text => RoleConstants.human_role_string([group.membership_of(users(:f_mentor)).role.name], :program => users(:f_mentor).program)
      assert_select "a", text: "feature.connection.action.Join".translate(Mentoring_Connection: _Mentoring_Connection), count: 1
    end
  end

  def test_available_and_ongoing_groups_list
    user = users(:f_admin)
    user.stubs(:groups).returns([groups(:mygroup), groups(:group_2), groups(:group_3), groups(:group_4)])
    groups(:mygroup).stubs(:global).returns(false)
    groups(:mygroup).stubs(:active?).returns(true)
    groups(:mygroup).stubs(:pending?).returns(true)
    groups(:mygroup).stubs(:name).returns("group1")

    groups(:group_2).stubs(:global).returns(true)
    groups(:group_2).stubs(:active?).returns(true)
    groups(:group_2).stubs(:pending?).returns(false)
    groups(:group_2).stubs(:name).returns("group2")

    groups(:group_3).stubs(:global).returns(true)
    groups(:group_3).stubs(:active?).returns(false)
    groups(:group_3).stubs(:pending?).returns(true)
    groups(:group_3).stubs(:name).returns("group3")

    groups(:group_4).stubs(:global).returns(true)
    groups(:group_4).stubs(:active?).returns(false)
    groups(:group_4).stubs(:pending?).returns(false)
    groups(:group_4).stubs(:name).returns("group4")

    html_content = to_html(available_and_ongoing_groups_list(user))

    assert_select html_content, "a", text: "group1", count: 0
    assert_select html_content, "a", text: "group2", count: 1
    assert_select html_content, "a", text: "group3", count: 1
    assert_select html_content, "a", text: "group4", count: 0
  end

  def test_drafted_survey_responses_list
    user = users(:no_mreq_student)
    answer = common_answers(:q3_from_answer_draft)
    answer1 = answer.dup
    answer.update_attribute(:group_id, nil)
    answer2 = answer.dup
    answer.update_attribute(:group_id, answer.group_id)
    answer.update_attribute(:task_id, 123)
    answer3 = answer.dup
    user.stubs(:drafted_responses_for_widget).returns([answer1, answer2, answer3])
    content = drafted_survey_responses_list(user)
    assert_equal [render(partial: "users/home_page_widgets/drafted_survey", locals: {survey: answer1.survey, dsr: answer1, options: {response_id: answer1.response_id, group_id: answer1.group_id, src: Survey::SurveySource::HOME_PAGE_WIDGET}}),
                  render(partial: "users/home_page_widgets/drafted_survey", locals: {survey: answer2.survey, dsr: answer2, options: {response_id: answer2.response_id, src: Survey::SurveySource::HOME_PAGE_WIDGET}}),
                  render(partial: "users/home_page_widgets/drafted_survey", locals: {survey: answer3.survey, dsr: answer3, options: {response_id: answer3.response_id, task_id: answer3.task_id, src: Survey::SurveySource::HOME_PAGE_WIDGET}})], content
  end

  def test_profile_filter_container
    organization = programs(:org_primary)
    location_question = organization.profile_questions.find_by(question_type: ProfileQuestion::Type::LOCATION)
    education_question = profile_questions(:education_q)
    experience_question = profile_questions(:experience_q)
    choice_question = profile_questions(:single_choice_q)
    text_question = profile_questions(:string_q)
    publication_question = profile_questions(:publication_q)
    date_question = profile_questions(:date_question)

    content = profile_filter_container(location_question, { name: "Chennai" })
    assert_select_helper_function_block  "div.input-group", content do
      assert_select "span > i.fa-map-marker"
      assert_select "input[id=\"search_filters_location_#{location_question.id}_name\"][name=\"sf\[location\]\[#{location_question.id}\]\[name\]\"][placeholder=\"City, State or Location\"][value=\"Chennai\"]"
    end
    assert_match /jQueryAutoCompleter\("#search_filters_location_#{location_question.id}_name/, content
    assert_match /button.*onclick=\"return MentorSearch.applyFilters/, content
    assert_match /reset_filter_profile_question_#{location_question.id}/, content
    content = profile_filter_container(education_question)
    assert_select_helper_function_block  "div.input-group", content do
      assert_select "span > i.fa-graduation-cap"
      assert_select "input[id=\"sf_pq_#{education_question.id}\"][name=\"sf\[pq\]\[#{education_question.id}\]\"][value=\"\"]"
    end
    assert_match /MentorSearch.registerTextFilter\('sf_pq_#{education_question.id}', ''\)/, content
    assert_match /button.*onclick=\"return MentorSearch.applyFilters/, content
    assert_match /reset_filter_profile_question_#{education_question.id}/, content
    assert_no_match(/jQueryAutoCompleter/, content)

    content = profile_filter_container(experience_question)
    assert_select_helper_function_block  "div.input-group", content do
      assert_select "span > i.fa-suitcase"
      assert_select "input[id=\"sf_pq_#{experience_question.id}\"][name=\"sf\[pq\]\[#{experience_question.id}\]\"][value=\"\"]"
    end
    assert_match /MentorSearch.registerTextFilter\('sf_pq_#{experience_question.id}', ''\)/, content
    assert_match /button.*onclick=\"return MentorSearch.applyFilters/, content
    assert_match /reset_filter_profile_question_#{experience_question.id}/, content
    assert_no_match(/jQueryAutoCompleter/, content)

    content = profile_filter_container(publication_question)
    assert_select_helper_function_block  "div.input-group", content do
      assert_select "span > i.fa-book"
      assert_select "input[id=\"sf_pq_#{publication_question.id}\"][name=\"sf\[pq\]\[#{publication_question.id}\]\"][value=\"\"]"
    end
    assert_match /MentorSearch.registerTextFilter\('sf_pq_#{publication_question.id}', ''\)/, content
    assert_match /button.*onclick=\"return MentorSearch.applyFilters/, content
    assert_match /reset_filter_profile_question_#{publication_question.id}/, content
    assert_no_match(/jQueryAutoCompleter/, content)

    content = profile_filter_container(date_question)
    assert_select_helper_function_block "div.cjs_daterange_picker", content do
      assert_select "input.cjs_daterange_picker_start"
      assert_select "input.cjs_daterange_picker_end"
      assert_select "input.cjs_date_picker_for_profile_question.hide"
    end
    assert_no_match(/jQueryAutoCompleter/, content)

    assert_nil profile_filter_container(choice_question)

    content = profile_filter_container(text_question)
    assert_select_helper_function "input[id=\"sf_pq_#{text_question.id}\"][name=\"sf\[pq\]\[#{text_question.id}\]\"][value=\"\"]", content
    assert_match /MentorSearch.registerTextFilter\('sf_pq_#{text_question.id}', ''\)/, content
    assert_match /button.*onclick=\"return MentorSearch.applyFilters/, content
    assert_match /reset_filter_profile_question_#{text_question.id}/, content
    assert_no_match(/jQueryAutoCompleter/, content)
  end

  def test_get_availablility_status_filter_fields
    @current_program = programs(:albers)
    self.expects(:current_program).at_least(0).returns(programs(:albers))
    self.expects(:current_user).at_least(0).returns(users(:f_admin))

    assert_nil get_availablility_status_filter_fields(RoleConstants::TEACHER_NAME)

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_nil get_availablility_status_filter_fields(RoleConstants::STUDENT_NAME)

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(true)
    filter_fields = get_availablility_status_filter_fields(RoleConstants::STUDENT_NAME).collect { |filter_field| filter_field[:value] }
    assert_equal ["connected", "unconnected", "neverconnected"], filter_fields

    # ongoing mentoring still enabled
    User.any_instance.stubs(:can_render_calendar_ui_elements?).with(RoleConstants::MENTOR_NAME).returns(false)
    filter_fields = get_availablility_status_filter_fields(RoleConstants::MENTOR_NAME).collect { |filter_field| filter_field[:value] }
    assert_equal ["available"], filter_fields

    # ongoing mentoring still enabled
    User.any_instance.stubs(:can_render_calendar_ui_elements?).with(RoleConstants::MENTOR_NAME).returns(true)
    filter_fields = get_availablility_status_filter_fields(RoleConstants::MENTOR_NAME).collect { |filter_field| filter_field[:value] }
    assert_equal ["calendar_availability", "available"], filter_fields

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    filter_fields = get_availablility_status_filter_fields(RoleConstants::MENTOR_NAME).collect { |filter_field| filter_field[:value] }
    assert_equal ["calendar_availability"], filter_fields
  end

  def test_get_match_mentor_actions
    self.expects(:current_program).at_least(0).returns(programs(:albers))
    content = get_match_mentor_actions(users(:f_mentor), users(:f_student), btn_class: "dropdown-btn-class")
    assert_match /dropdown-btn-class/, content
    assert_match /Connect <span class=\"caret\">/, content
    assert_select_helper_function "li > a[class=\"assign_match_btns\"][href=\"\/groups\/assign_match_form\?mentor_id=#{users(:f_mentor).id}&student_id=#{users(:f_student).id}\"]", content
    assert_match(/draft/, content)

    content = get_match_mentor_actions(users(:f_mentor), users(:f_student), btn_class: "dropdown-btn-class")
    assert_match /dropdown-btn-class/, content
    assert_match /Connect <span class=\"caret\">/, content
    assert_select_helper_function "li > a[class=\"assign_match_btns\"][href=\"\/groups\/assign_match_form\?mentor_id=#{users(:f_mentor).id}&student_id=#{users(:f_student).id}\"]", content
    assert_select_helper_function "li > a[class=\"assign_match_btns\"][href=\"\/groups\/save_as_draft\?mentor_id=#{users(:f_mentor).id}&student_id=#{users(:f_student).id}\"]", content
  end

  def test_display_favorite
    self.expects(:current_user).at_least(0).returns(users(:f_student))
    UserFavorite.create!(user: users(:f_student), favorite: users(:f_mentor))
    content = display_favorite(users(:f_mentor))
    set_response_text(content)
    assert_select "li.list-group-item" do
      assert_select "a", text: "Good unique name"
      assert_select "a", text: "Remove"
    end
  end

  def test_get_prompt_preferred_request_message
    program = programs(:albers)
    user = users(:f_student)
    self.expects(:current_user).at_least(0).returns(user)
    self.expects(:current_program).at_least(0).returns(program)

    program.update_attribute(:min_preferred_mentors, 1)
    UserFavorite.create!(user: user, favorite: users(:f_mentor))
    assert program.allow_mentoring_requests?
    assert_false user.reload.connection_limit_as_mentee_reached?
    assert_false user.pending_request_limit_reached_for_mentee?
    assert user.ready_to_request?
    content = get_prompt_preferred_request_message
    assert_match /You have 1 preferred mentor/, content
    assert_match /Send a request/, content

    program.update_attribute(:min_preferred_mentors, 3)
    assert_false user.reload.ready_to_request?
    content = get_prompt_preferred_request_message
    assert_equal "You have 1 preferred mentor. You should have at least 2 more mentors to send the request", content

    program.stubs(:allow_mentoring_requests?).returns(false)
    assert_nil get_prompt_preferred_request_message
  end

  def test_users_view_params
    assert_nil users_view_params(RoleConstants::MENTOR_NAME)[:view]
    assert_equal RoleConstants::STUDENTS_NAME, users_view_params(RoleConstants::STUDENT_NAME)[:view]
    assert_equal RoleConstants::EMPLOYEE_NAME, users_view_params(RoleConstants::EMPLOYEE_NAME)[:view]
  end

  def test_get_user_role_for_ga
    user = users(:f_mentor_student)
    user_role = get_user_role_for_ga(user)
    assert_equal "Mentor Mentee", user_role

    user = users(:ram)
    user_role = get_user_role_for_ga(user)
    assert_equal "Mentor", user_role

    user.role_names = ["user"]
    user.save
    user_role = get_user_role_for_ga(user)
    assert_equal "Other Role", user_role

    user.role_names = ["user", "mentor"]
    user.save
    user_role = get_user_role_for_ga(user)
    assert_equal "Mentor", user_role

    user.role_names = ["user", "mentor", "student"]
    user.save
    user_role = get_user_role_for_ga(user)
    assert_equal "Mentor Mentee", user_role
  end

  def test_get_track_level_connection_status
    user = users(:f_mentor)
    connection_status = get_track_level_connection_status(user)
    assert_equal User::ConnectionStatusForGA::CURRENT, connection_status

    user = users(:f_admin)
    connection_status = get_track_level_connection_status(user)
    assert_equal User::ConnectionStatusForGA::NEVER_CONNECTED_NEVER_INITIATED, connection_status

    user = users(:foster_mentor1)
    connection_status = get_track_level_connection_status(user)
    assert_equal User::ConnectionStatusForGA::NA, connection_status

    user = users(:student_4)
    connection_status = get_track_level_connection_status(user)
    assert_equal User::ConnectionStatusForGA::PAST, connection_status
  end

  def test_get_unavailable_icon_content
    self.expects(:image_tag).once.with("https://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/ongoing_unavailable.png", width: 24, height: 24)
    get_unavailable_icon_content(email: true, ongoing: true, title: "title")

    self.expects(:get_icon_content).once.with("fa fa-ban", {container_class: "fa-user-plus", container_stack_class: "fa-stack-1x", icon_stack_class: "fa-stack-2x", invert: "", stack_class: 'm-l-xs fa-small', "data-title" => "title", "data-toggle" => "tooltip"})
    get_unavailable_icon_content(ongoing: true, title: "title")

    self.expects(:image_tag).once.with("https://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/onetime_unavailable.png", width: 24, height: 24)
    get_unavailable_icon_content(email: true, onetime: true, title: "title")

    self.expects(:get_icon_content).once.with("fa fa-ban", {container_class: "fa-calendar", container_stack_class: "fa-stack-1x", icon_stack_class: "fa-stack-2x", invert: "", stack_class: 'm-l-xs fa-small', "data-title" => "title", "data-toggle" => "tooltip"})
    get_unavailable_icon_content(onetime: true, title: "title")
  end

  def test_get_available_icon_content
    self.expects(:image_tag).once.with("https://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/ongoing_available.png", width: 20, height: 18)
    get_available_icon_content(email: true, ongoing: true, title: "title")

    self.expects(:get_icon_content).once.with("fa fa-user-plus m-l-xs", "data-title" => "title", "data-toggle" => "tooltip")
    get_available_icon_content(ongoing: true, title: "title")

    self.expects(:image_tag).once.with("https://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/onetime_available.png", width: 20, height: 18)
    get_available_icon_content(email: true, onetime: true, title: "title")

    self.expects(:get_icon_content).once.with("fa fa-calendar", "data-title" => "title", "data-toggle" => "tooltip")
    get_available_icon_content(onetime: true, title: "title")
  end

  def test_icons_for_availability
    program = programs(:albers)
    mentor = users(:f_mentor)
    mentor.update_attribute(:max_connections_limit, 13)
    assert_nil icons_for_availability(users(:f_admin))
    assert_nil icons_for_availability(users(:f_student))
    assert icons_for_availability(mentor).blank?

    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    Program.any_instance.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    assert icons_for_availability(mentor).blank?
    Program.any_instance.unstub(:only_career_based_ongoing_mentoring_enabled?)

    Program.any_instance.stubs(:matching_by_admin_alone?).returns(true)
    assert icons_for_availability(mentor).blank?
    Program.any_instance.unstub(:matching_by_admin_alone?)

    Program.any_instance.stubs(:allow_mentoring_requests?).returns(false)
    assert icons_for_availability(mentor).blank?
    Program.any_instance.unstub(:allow_mentoring_requests?)

    self.expects(:get_available_icon_content).times(2)
    icons_for_availability(mentor.reload)

    mentor.stubs(:can_receive_mentoring_requests?).returns(false)
    self.expects(:get_available_icon_content).once.with(title: "Available for a meeting", email: nil, onetime: true, no_left_margin: nil)
    self.expects(:get_unavailable_icon_content).once
    icons_for_availability(mentor.reload)
    mentor.unstub(:can_receive_mentoring_requests?)
    program.update_attributes!(allow_mentoring_mode_change: true)
    mentor.update_attributes!(mentoring_mode: User::MentoringMode::ONGOING)

    self.expects(:get_available_icon_content).once.with(title: "Available for a mentoring connection", email: nil, ongoing: true, no_left_margin: nil)
    self.expects(:get_unavailable_icon_content).once
    icons_for_availability(mentor.reload)
    # self.expects(:get_available_icon_content).once.with(title: "Available for a meeting", email: nil, onetime: true)
    program.reload
  end

  def test_get_mentor_availability_text
    mentor = users(:f_mentor)
    view_date = Time.now
    Time.stubs(:now).returns(view_date)
    not_available_text = "feature.user.content.not_available_v1".translate(calendar_month: DateTime.localize(view_date.next_month, format: :month_year))
    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date).returns(true)
    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date.next_month).returns(true)  
    assert_equal "<i class=\"fa fa-times-circle text-danger fa-fw m-r-xs\"></i>#{not_available_text}", get_mentor_availability_text(mentor)

    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date).returns(true)
    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date.next_month).returns(false)  
    assert_equal "<i class=\"fa fa-check-circle text-warning fa-fw m-r-xs\"></i>Available next month", get_mentor_availability_text(mentor)

    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date).returns(false)
    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date.next_month).returns(true)  
    assert_equal "<i class=\"fa fa-check-circle text-navy fa-fw m-r-xs\"></i>Available this month", get_mentor_availability_text(mentor)

    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date).returns(false)
    User.any_instance.expects(:is_max_capacity_user_reached?).with(view_date.next_month).returns(false)  
    assert_equal "<i class=\"fa fa-check-circle text-navy fa-fw m-r-xs\"></i>Available", get_mentor_availability_text(mentor)
  end

  def test_populate_sort_options
    user = users(:f_admin)
    user.stubs(:explicit_preferences_configured?).returns(false)
    sort_fields = populate_sort_options(user, {is_match_view: true})
    assert sort_fields.include?({:field => :match, :order => :asc, :label => "feature.user.label.match_asc".translate})
    assert sort_fields.include?({:field => :match, :order => :desc, :label => "feature.user.label.match_desc".translate})
    assert_false sort_fields.include?({:field => UserSearch::SortParam::PREFERENCE, :order => :desc, :label => "feature.user.label.preference".translate})

    user.stubs(:explicit_preferences_configured?).returns(true)
    sort_fields = populate_sort_options(user, {is_match_view: true})
    assert_false sort_fields.include?({:field => :match, :order => :asc, :label => "feature.user.label.match_asc".translate})
    assert_false sort_fields.include?({:field => :match, :order => :desc, :label => "feature.user.label.match_desc".translate})
    assert sort_fields.include?({:field => UserSearch::SortParam::PREFERENCE, :order => :desc, :label => "feature.user.label.preference".translate})
  end

  def test_populate_sort_options_for_match_view
    sort_fields = []
    user = users(:f_admin)
    user.stubs(:explicit_preferences_configured?).returns(false)
    populate_sort_options_for_match_view(user, sort_fields)
    assert sort_fields.include?({:field => :match, :order => :asc, :label => "feature.user.label.match_asc".translate})
    assert sort_fields.include?({:field => :match, :order => :desc, :label => "feature.user.label.match_desc".translate})
    assert_equal 2, sort_fields.size

    sort_fields = []
    user.stubs(:explicit_preferences_configured?).returns(true)
    populate_sort_options_for_match_view(user, sort_fields)
    assert sort_fields.include?({:field => UserSearch::SortParam::PREFERENCE, :order => :desc, :label => "feature.user.label.preference".translate})
    assert_equal 1, sort_fields.size
  end

  private

  def wob_member
    members(:f_mentor)
  end

  def working_on_behalf?
    false
  end

  # Checks whether the given tab is selected.
  def assert_sub_tabs(tabs, active_tab, tabs_html)
    set_response_text(tabs_html)
    assert_select "div[class=?]", 'inner_tabs' do
      tabs.each do |tab|
        assert_select "li" do
          assert_select 'a', :text => tab
        end
      end

      assert_select "li[class='tab sel']", :count => 1, :text => active_tab
    end
  end

  def assert_no_profile_tabs(tabs)
    assert_nil tabs
  end

  def _Admin
    "Administrator"
  end

  def _Mentor
    "Mentor"
  end

  def _Mentee
    "Student"
  end

  def _mentee
    "student"
  end

  def _a_mentor
    "a mentor"
  end

  def _a_Mentor
    "a Mentor"
  end

  def _a_mentee
    "a mentee"
  end

  def _mentees
    "students"
  end

  def _mentor
    "mentor"
  end

  def _mentors
    "mentors"
  end

  def _Mentors
    "Mentors"
  end

  def _Mentees
    "Students"
  end

  # This is to stub the method render
  def render(*args)
    ""
  end

  def _mentoring_connection
    "mentoring connection"
  end

  def _a_mentoring_connection
    "a mentoring connection"
  end

  def _mentoring_connections
    "mentoring connections"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _Meeting
    "Meeting"
  end

  def _Meetings
    "Meetings"
  end

  def _meeting
    "meeting"
  end

  def _a_meeting
    "a meeting"
  end

  def _meetings
    "meetings"
  end

  def _a_article
  "an article"
  end

  def _article
    "article"
  end

  def _Article
    "Article"
  end

  def _articles
    "articles"
  end

  def _Articles
    "Articles"
  end

  def _Program
    "Program"
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

  def _admin
    "administrator"
  end
end