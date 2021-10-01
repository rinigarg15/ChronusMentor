require_relative './../test_helper.rb'

class ProgramsControllerTest < ActionController::TestCase
  include UserListingExtensions
  include CareerDevTestHelper
  def setup
    super
    @manager_role = create_role(:name => 'manager_role')
    add_role_permission(@manager_role, 'customize_program')
    @prog_manager = create_user(
      :name => 'prog_manager', :role_names => ['manager_role'])
    @request.session[:closed_circles_in_publish_circle_widget_ids] = []
  end

  def test_create_program_should_throw_error
    current_user_is @prog_manager
    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :create, params: { :program => {:name => 'test'}}
    end
  end

  def test_trying_to_access_in_invalid_program_should_redirect_to_default_site
    current_subdomain_is "non_existent_program"

    get :show
    assert_redirected_to program_root_url(:subdomain => REDIRECT_SUBDOMAIN, :host => DEFAULT_HOST_NAME)
  end

  def test_mentoring_community_widget
    current_user_is :rahim
    User.any_instance.stubs(:get_unconnected_user_widget_content_list).returns([{new_content: true, klass: Article.to_s}])

    get :mentoring_community_widget, xhr: true, format: :js
    assert_response :success
    assert_equal [{new_content: true, klass: Article.to_s}], assigns(:unconnected_user_widget_content)
  end

  def test_remove_circle_from_publish_circle_widget_with_no_session_var
    current_user_is :f_mentor_pbe
    @request.session[:closed_circles_in_publish_circle_widget_ids] = nil

    get :remove_circle_from_publish_circle_widget, params: { group_id: 10}, format: :js

    assert_equal [10], @request.session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_remove_circle_from_publish_circle_widget_with_session_var
    current_user_is :f_mentor_pbe
    @request.session[:closed_circles_in_publish_circle_widget_ids] = [10]

    get :remove_circle_from_publish_circle_widget, params: { group_id: 20}, format: :js

    assert_equal [10, 20], @request.session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_publish_circles_widget
    current_user_is :f_mentor_pbe
    groups(:group_pbe).update_attribute(:pending_at, 8.days.ago)

    User.any_instance.stubs(:get_groups_to_display_in_publish_circle_widget).returns([groups(:group_pbe)])
    @request.session[:closed_circles_in_publish_circle_widget_ids] = []

    get :publish_circles_widget, format: :js
    assert_response :success
    assert_equal [groups(:group_pbe)], assigns(:publishable_groups)
  end

  def test_publish_circles_widget_with_dismissed_group
    current_user_is :f_mentor_pbe
    groups(:group_pbe).update_attribute(:pending_at, 8.days.ago)
    User.any_instance.stubs(:get_groups_to_display_in_publish_circle_widget).returns([groups(:group_pbe)])
    @request.session[:closed_circles_in_publish_circle_widget_ids] = [groups(:group_pbe).id]

    get :publish_circles_widget, format: :js
    assert_response :success
    assert_equal [], assigns(:publishable_groups)
  end

  def test_show_with_recommendation
    user = users(:rahim)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    user.stubs(:show_recommendation_box?).returns(true)
    current_user_is :rahim
    expected_mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    expected_recommendation_preferences = expected_mentor_recommendation.valid_recommendation_preferences
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_HOME_PAGE).once

    get :show, params: {from_first_visit: 'true'}
    assert_response :success
    # Availability icons to be displayed in recommendations
    assert_select "i.fa.fa-user-plus"
    assert_select "i.fa.fa-calendar"
    assigns(:recommendation_preferences_hash).each do |recommendation_preference|
      assert expected_recommendation_preferences.include?(recommendation_preference[:recommendation_preference])
    end
    assert_nil assigns(:unanswered_mandatory_prof_qs)
    assert_false assigns(:current_user).can_be_shown_flash_meetings_widget?
    assert_nil assigns(:meetings_to_show)
    assert_nil assigns(:publishable_groups)
    assert_nil assigns(:total_upcoming_meetings)
    assert assigns(:show_favorite_ignore_links)
    assert_equal_hash({users(:ram).id=>abstract_preferences(:favorite_2).id}, assigns(:favorite_preferences_hash))
    assert_equal_hash({users(:robert).id=>abstract_preferences(:ignore_2).id}, assigns(:ignore_preferences_hash))
    assert assigns(:from_first_visit)
  end

  def test_show_for_meetings_to_show
    current_user_is :f_mentor

    meeting_hash = {meeting: meetings(:f_mentor_mkr_student), current_occurrence_time: meetings(:f_mentor_mkr_student).start_time}

    Meeting.stubs(:get_meetings_to_render_in_home_page_widget).with(members(:f_mentor), programs(:albers)).returns([meeting_hash, meeting_hash, meeting_hash, meeting_hash])
    User.any_instance.stubs(:can_be_shown_flash_meetings_widget?).returns(true)
    
    get :show

    assert_response :success
    assert_equal [meeting_hash, meeting_hash, meeting_hash], assigns(:meetings_to_show)
    assert assigns(:show_view_all)
    assert_equal 4, assigns(:total_upcoming_meetings)
    assert_false assigns(:show_favorite_ignore_links)
    assert_false assigns(:from_first_visit)
  end

  def test_show_for_publishable_groups
    current_user_is :f_mentor_pbe
    groups(:group_pbe).update_attribute(:pending_at, 8.days.ago)
    User.any_instance.stubs(:get_groups_to_display_in_publish_circle_widget).returns([groups(:group_pbe)])
    @request.session[:closed_circles_in_publish_circle_widget_ids] = []

    get :show
    assert_response :success
    assert_equal [groups(:group_pbe)], assigns(:publishable_groups)
  end

  def test_user_trying_to_access_invalid_program_should_redirect_to_programs_listing
    current_member_is :f_admin
    @controller.expects(:current_root).at_least(0).returns("abcd")

    get :show
    assert_redirected_to programs_list_path
    assert_equal "Oops! We cannot find that page.", flash[:error]
  end

  def test_trying_to_access_with_www
    current_subdomain_is "www.this.is.a.complex.subdomain"

    get :show
    assert_redirected_to program_root_url(:subdomain => "this.is.a.complex.subdomain")
  end

def test_trying_to_access_with_only_www
    current_subdomain_is "www"

    get :show
    assert_redirected_to program_root_url(:subdomain => false, :domain => assigns(:current_domain))
  end

  def test_trying_to_access_without_www
    current_subdomain_is "ww.#{programs(:org_primary).subdomain}"

    get :show
    assert_redirected_to program_root_url(:subdomain => REDIRECT_SUBDOMAIN, :host => DEFAULT_HOST_NAME)
  end

  def test_user_trying_to_access_invalid_ip_should_logout_and_redirect_to_root_path
    current_user_is :f_student
    configure_allowed_ips_to_restrict
    get :show
    assert_redirected_to program_root_path
    assert_false assigns(:current_member)
    assert_equal "This is a restricted site. You must log in to this site through an authorized network. Please contact your administrator if you need further help.", flash[:error]
  end

  def test_unsubscribe_from_weekly_update_mail
    current_user_is :f_student
    get :unsubscribe_from_weekly_update_mail
    assert_redirected_to edit_member_path(users(:f_student).member, focus_notification_tab: true)
    assert_equal 'The email you are trying to unsubscribe has been deprecated and will no longer be sent. We have reduced the number of digest emails and consolidated them into a single "smart digest" email that acts as the offline homepage. You can set your notification preferences from this page.', flash[:notice]
  end

  def test_user_trying_to_access_valid_ip_should_not_logout_or_redirect
    current_user_is :f_student
    configure_allowed_ips
    get :show
    assert_response :success
    assert_equal members(:f_student), assigns(:current_member)
  end

  def test_normal_user_trying_to_access_should_not_encounter_remote_ip
    current_user_is :f_student
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    @request.expects(:remote_ip).never
    get :show
    assert_response :success
    assert_equal members(:f_student), assigns(:current_member)
  end

  def test_mandatory_profile_qs_not_answered_for_published_user
    current_user_is :f_student
    program = programs(:albers)

    student_q1 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::STUDENT_NAME], :required => true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_HOME_PAGE).never

    get :show
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
    assert_equal members(:f_student), assigns(:current_member)
    assert assigns(:unanswered_mandatory_prof_qs)
  end

  def test_it_should_assigns_unanswered_questions
    current_user_is :f_student
    get :show
    assert_response :success
    assert assigns(:unanswered_questions).present?
  end

  def test_profile_completion_permission_enabled
    current_user_is :f_student
    assert programs(:org_primary).profile_completion_alert_enabled?
    get :show, params: { :id => members(:f_student).id}
    assert_select "div.profile_status_box" do
      assert_select "span.complete_questions_promt", :text => "Complete the following profile fields to improve your score."
    end
    assert_select "div.progress"
  end

  def test_profile_completion_enabled_only_at_program_level
    current_user_is :f_student
    programs(:org_primary).enable_feature(FeatureName::PROFILE_COMPLETION_ALERT, false)
    programs(:albers).enable_feature(FeatureName::PROFILE_COMPLETION_ALERT)
    get :show
    assert_select "div.progress"
  end

  def test_profile_completion_disabled
    current_user_is :f_student
    programs(:org_primary).enable_feature(FeatureName::PROFILE_COMPLETION_ALERT, false)
    programs(:albers).enable_feature(FeatureName::PROFILE_COMPLETION_ALERT, false)
    get :show
    assert_no_select "div.progress"
  end

  def test_should_get_first_time_edit_program_page
    current_subdomain_is programs(:org_primary).subdomain
    @request.session[:member_id] = @prog_manager.member_id
    @request.session[:new_organization_id] = programs(:org_primary).id
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true

    program = programs(:albers)
    ActiveRecord::Base.connection.execute("UPDATE #{Program.table_name} SET mentor_request_style = NULL")
    assert_nil program.reload.mentor_request_style
    ActiveRecord::Base.connection.execute("UPDATE programs SET allow_one_to_many_mentoring = NULL")
    assert_nil program.reload.allow_one_to_many_mentoring

    # Should render edit page with proper first time title and help content at
    # the left
    get :edit, params: { :first_visit => 1}
    assert_response :success
    assert_template 'edit'
    assert_equal programs(:org_primary), assigns(:current_organization)

    assert_equal program, assigns(:current_program)
    assert_select 'html' do
      assert_select 'div.h4', 'Complete Program Registration'
      assert_select 'div.wizard_view'
      assert_select "input[name=?][value='#{program.name}']", 'program[name]'
      assert_select('span#program_subdomain', :text => 'primary.'+ DEFAULT_HOST_NAME + '/p/albers')
      assert_select "input[name='program[subdomain]']", 0
      assert_select "input[name=?][value='1']", 'first_visit'
    end

    # Application layout should only be rendered for this edit page
    assert_template 'layouts/application'
  end

  def test_should_display_proper_webaddress_for_custom_domain_program
    current_user_is :custom_domain_admin
    get :edit
    assert_select "span#program_subdomain", :text => 'mentor.customtest.com'
    assert_false assigns(:redirected_from_update)
  end

  def test_should_display_proper_webaddress_for_no_subdomain_program
    current_user_is :no_subdomain_admin
    get :edit
    assert_equal programs(:org_no_subdomain), assigns(:current_organization)
    assert_equal programs(:no_subdomain), assigns(:current_program)
    assert_select "span#program_subdomain", :text => 'nosubdomtest.com'
  end

  def test_should_display_proper_webaddress_for_default_domain_program
    current_user_is :f_admin
    get :edit
    assert_select "span#program_subdomain", :text => 'primary.'+ DEFAULT_HOST_NAME + '/p/albers'
  end

  def test_should_get_program_edit_for_tab_0
    current_user_is :foster_admin
    current_program_is :foster
    login_as_super_user

    ActiveRecord::Base.connection.execute("UPDATE programs SET allow_one_to_many_mentoring = 0 WHERE id = #{programs(:foster).id}")
    program = programs(:foster)
    assert_false program.reload.allow_one_to_many_mentoring

    get :edit
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select 'div#program_edit' do
        assert_select "div.inner_tabs" do
          assert_select "li.active", :text => "General Settings"
        end

        assert_select "form.edit_program" do
          assert_select "input[name=?][value='#{program.name}']", 'program[name]'
          assert_select "input[name='program[subdomain]']", 0
          assert_select('span#program_subdomain', :text => 'foster.' + DEFAULT_HOST_NAME)
          assert_select("textarea#program_description")
          assert_select("input#program_organization_logo[type=file]")
          assert_select("input#banner[type=file]")
          assert_select("input#program_organization_mobile_logo[type=file]")

          assert_equal(Program::MentorRequestStyle::MENTEE_TO_ADMIN, assigns(:current_program).mentor_request_style)

        end
      end
    end

    assert_template 'layouts/program'
  end

  def test_should_get_program_edit_for_tab_2
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MEMBERSHIP}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select "div.inner_tabs" do
        assert_select "li.active", :text => "Membership"
      end
      assert_select "form.edit_program" do
        assert_select("input#mentor_can_invite_mentor")
        assert_select("input#mentor_can_invite_student")
        assert_select("input#student_can_invite_mentor")
        assert_select("input#student_can_invite_student")
        assert_select("input#program_show_multiple_role_option_true")
      end
    end
  end

  def test_should_get_program_edit_for_tab_3
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_match GroupInactivityNotification.mailer_attributes[:uid], @response.body
    assert_match GroupInactivityNotificationWithAutoTerminate.mailer_attributes[:uid], @response.body
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select "div.inner_tabs" do
        assert_select "li.active", :text => "Mentoring Connection Settings"
      end
      assert_select "form.edit_program" do
        assert_select('input#program_mentoring_period_value')
        assert_select('select#program_mentoring_period_unit')
        assert_no_select('select#program_max_connections_for_mentee')
      end
    end
  end

  def test_should_get_program_edit_features
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::FEATURES}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select "div.inner_tabs" do
        assert_select "li.active", :text => "Features"
      end
    end
    assert_no_select "input#offer_mentoring"
    assert_no_select "input#calendar"
  end

  def test_matchgin_setting_ongoing_disbaled
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select "input.cjs_matching_setting_one_time_mentoring_mode"
      assert_select "input.cjs_matching_setting_ongoing_mentoring_mode[disabled=disabled]"
    end
  end

  def test_disable_one_time_mentoring_error_since_meeting_request_exists
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    assert program.meeting_requests.active.exists?
    post :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: {}}
    assert response.body.match(/Please close all the pending meeting requests to disable one-time mentoring/)
    assert_match /#{MeetingRequestReminderNotification.mailer_attributes[:uid]}/, response.body
    assert_match /#{MeetingRequestExpiredNotificationToSender.mailer_attributes[:uid]}/, response.body
    assert_match /#{MentorRequestReminderNotification.mailer_attributes[:uid]}/, response.body
    assert_match /#{MentorRequestExpiredToSender.mailer_attributes[:uid]}/, response.body
    assert program.reload.calendar_enabled?
    assert assigns(:error_disabling_calendar)
  end

  def test_disable_one_time_mentoring_and_check_cleanup
    create_meeting.update_attributes(group_id: nil)
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.meeting_requests.active.update_all(status: AbstractRequest::Status::CLOSED)
    assert program.meetings.non_group_meetings.exists?
    assert_false program.meeting_requests.active.exists?
    assert program.users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).exists?
    assert_no_difference "ActionMailer::Base.deliveries.count" do
      post :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: {}}
    end
    assert_false program.users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).exists?
    assert_false program.meetings.non_group_meetings.exists?
    assert_false program.reload.calendar_enabled?
    assert_false assigns(:error_disabling_calendar)
  end

  def test_enable_ongoing_when_one_time_mentoring_alone_enabled
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.engagement_type = Program::EngagementType::CAREER_BASED
    program.save
    assert_false program.ongoing_mentoring_enabled?
    assert program.calendar_enabled?
    post :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: {engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING}}
    assert program.reload.ongoing_mentoring_enabled?
    assert program.calendar_enabled?
  end

  def test_dont_disable_one_time_mentoring_even_if_not_feature_in_enabled_list
    create_meeting.update_attributes(group_id: nil)
    current_user_is :f_admin
    program = programs(:albers)
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    program.enable_feature(FeatureName::CALENDAR)
    program.meeting_requests.active.update_all(status: AbstractRequest::Status::CLOSED)
    assert program.meetings.non_group_meetings.exists?
    assert_false program.meeting_requests.active.exists?
    assert program.users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).exists?
    assert_no_difference "ActionMailer::Base.deliveries.count" do
      post :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: {}}
    end
    assert program.users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).exists?
    assert program.meetings.non_group_meetings.exists?
    assert program.reload.calendar_enabled?
    assert_nil assigns(:error_disabling_calendar)
  end

  def test_matching_setting_one_time_disabled
    program = programs(:foster)
    program.enable_feature(FeatureName::CALENDAR)
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select "input.cjs_matching_setting_one_time_mentoring_mode[disabled=disabled]"
      assert_select "input.cjs_matching_setting_ongoing_mentoring_mode"
    end
  end

  def test_matching_setting_admin_to_see_match_scores
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select "input#program_allow_end_users_to_see_match_scores"
    end
  end

  def test_permission_denied_matching_setting_and_engagement_in_portal
    program = programs(:primary_portal)
    current_user_is :portal_admin
    assert_permission_denied do
      get :edit, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    end
    assert_permission_denied do
      get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    end
    assert_permission_denied do
      get :update, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    end
  end

  def test_mentor_offer_auto_acceptance_is_disabled
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    create_mentor_offer
    assert program.mentor_offers.pending.any?

    get :edit, params: { tab: ProgramsController::SettingsTabs::MATCHING}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select "div.cjs_mentor_offer_settings" do
        assert_select "input#program_mentor_offer_needs_acceptance_true[disabled=disabled]"
        assert_select "input#program_mentor_offer_needs_acceptance_false[disabled=disabled]"
      end
    end
  end

  def test_matchgin_setting_none_disbaled
    program = programs(:foster)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select "input.cjs_matching_setting_one_time_mentoring_mode"
      assert_select "input.cjs_matching_setting_ongoing_mentoring_mode"
    end
  end

  def test_should_get_edit_program_permissions
    current_user_is :foster_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::PERMISSIONS}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select "div.inner_tabs" do
        assert_select "li.active", :text => "Permissions"
      end
    end
  end

  def test_permissions_tab
    current_user_is :foster_admin

    p = programs(:foster)
    mentor_role = p.roles.select{|role| role.mentor? }.first
    mentee_role = p.roles.select{|role| role.mentee? }.first
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
    assert p.allow_user_to_send_message_outside_mentoring_area?
    assert mentor_role.has_permission_name?("view_mentors")
    assert mentor_role.has_permission_name?("view_students")
    assert mentee_role.has_permission_name?("view_mentors")
    assert mentee_role.has_permission_name?("view_students")

    assert_difference 'RolePermission.count', -1 do
      post_with_calendar_check :update, params: { :permissions_tab => "true", :program => {:permissions =>["", "mentees_publish_articles"], :allow_user_to_send_message_outside_mentoring_area => false, :role_permissions => {"#{mentor_role.id}".to_sym => {"view_permissions" => nil, "view_#{mentee_role.name.pluralize}".to_sym => true}, "#{mentee_role.id}".to_sym => {"view_permissions" => nil, "view_#{mentor_role.name.pluralize}".to_sym => true}}}, :tab => ProgramsController::SettingsTabs::PERMISSIONS}
    end
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
    assert_false p.reload.allow_user_to_send_message_outside_mentoring_area?
    assert_false mentor_role.reload.has_permission_name?("view_mentors")
    assert mentor_role.reload.has_permission_name?("view_students")
    assert mentee_role.reload.has_permission_name?("view_mentors")
    assert_false mentee_role.reload.has_permission_name?("view_students")
  end

  def test_project_request_join_permission_updates
    current_user_is :f_admin_pbe

    p = programs(:pbe)
    mentor_role = p.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = p.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = p.roles.find_by(name: RoleConstants::TEACHER_NAME)
    admin_role = p.roles.find_by(name: RoleConstants::ADMIN_NAME)
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
    assert p.allow_user_to_send_message_outside_mentoring_area?
    assert mentee_role.has_permission_name?("send_project_request")
    mentor_role.remove_permission("send_project_request")
    assert_false mentor_role.has_permission_name?("send_project_request")
    assert_false teacher_role.has_permission_name?("send_project_request")

    assert mentee_role.can_be_added_by_owners
    assert mentor_role.can_be_added_by_owners
    assert teacher_role.can_be_added_by_owners

    assert mentee_role.needs_approval_to_create_circle?
    assert mentor_role.needs_approval_to_create_circle?
    assert teacher_role.needs_approval_to_create_circle?

    #Update all role to have send_project_request permission and make can_be_added_by_owners to false
    post_with_calendar_check :update, params: { :program => {:send_group_proposals =>[mentee_role.id], :group_proposal_approval => {mentee_role.id => "true", mentor_role.id => "false", teacher_role.id => "true"},:needs_project_request_reminder => 1, :project_request_reminder_duration => 14, :role_permissions => {"#{mentor_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}, "#{mentee_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}, "#{teacher_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}},
      role: {
        mentor_role.id => {role_attributes: "" },
        mentee_role.id => {role_attributes: "" },
        teacher_role.id => {role_attributes: "" }
      }
    }, :tab => ProgramsController::SettingsTabs::MATCHING}

    assert mentee_role.reload.has_permission_name?("send_project_request")
    assert mentor_role.reload.has_permission_name?("send_project_request")
    assert teacher_role.reload.has_permission_name?("send_project_request")
    assert_false mentee_role.can_be_added_by_owners
    assert_false mentor_role.can_be_added_by_owners
    assert_false teacher_role.can_be_added_by_owners

    assert mentee_role.needs_approval_to_create_circle?
    assert_false mentor_role.needs_approval_to_create_circle?
    assert teacher_role.needs_approval_to_create_circle?

    #no send_project_request permission for mentor role and mentee role
    post_with_calendar_check :update, params: { :program => {:send_group_proposals =>[mentee_role.id], :needs_project_request_reminder => 1, :project_request_reminder_duration => 14, :role_permissions => {"#{mentor_role.id}".to_sym => {"join_project_permissions" => ""}, "#{mentee_role.id}".to_sym => {"join_project_permissions" => ""}, "#{teacher_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}},
      role: {
        mentor_role.id => {role_attributes: ""},
        mentee_role.id => {role_attributes: ""},
        teacher_role.id => { can_be_added_by_owners: true, role_attributes: "" }
      }
    }, :tab => ProgramsController::SettingsTabs::MATCHING}
    assert_false mentee_role.reload.has_permission_name?("send_project_request")
    assert_false mentor_role.reload.has_permission_name?("send_project_request")
    assert teacher_role.reload.has_permission_name?("send_project_request")
    assert_false mentee_role.can_be_added_by_owners
    assert_false mentor_role.can_be_added_by_owners
    assert teacher_role.can_be_added_by_owners


    #no send_project_request permission for all roles
    post_with_calendar_check :update, params: { :program => {:send_group_proposals =>[mentee_role.id], :needs_project_request_reminder => 1, :project_request_reminder_duration => 14, :role_permissions => {"#{mentor_role.id}".to_sym => {"join_project_permissions" => ""}, "#{mentee_role.id}".to_sym => {"join_project_permissions" => ""}, "#{teacher_role.id}".to_sym => {"join_project_permissions" => ""}},
      role: {
        mentor_role.id => { can_be_added_by_owners: true, role_attributes: "" },
        mentee_role.id => { can_be_added_by_owners: true, role_attributes: "" },
        teacher_role.id => { can_be_added_by_owners: true, role_attributes: "" }
      }
    }, :tab => ProgramsController::SettingsTabs::MATCHING}

    assert_false mentee_role.reload.has_permission_name?("send_project_request")
    assert_false mentor_role.reload.has_permission_name?("send_project_request")
    assert_false teacher_role.reload.has_permission_name?("send_project_request")
    assert mentee_role.can_be_added_by_owners
    assert mentor_role.can_be_added_by_owners
    assert teacher_role.can_be_added_by_owners
  end

  def test_project_slot_config_not_updated_for_non_super_user
    current_user_is :f_admin_pbe

    program = programs(:pbe)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = program.roles.find_by(name: RoleConstants::TEACHER_NAME)
    admin_role = program.roles.find_by(name: RoleConstants::ADMIN_NAME)

    assert mentor_role.slot_config_optional?
    assert teacher_role.slot_config_optional?
    assert_false admin_role.slot_config_enabled?

    post_with_calendar_check :update, params: { :program => {:send_group_proposals =>[mentee_role.id], :needs_project_request_reminder => 1, :project_request_reminder_duration => 14, :role_permissions => {"#{mentor_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}, "#{mentee_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}, "#{teacher_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}},
      role: {
        mentor_role.id => {role_attributes: "", slot_config: "#{RoleConstants::SlotConfig::REQUIRED}"},
        mentee_role.id => {role_attributes: "", slot_config: "#{RoleConstants::SlotConfig::REQUIRED}" },
        teacher_role.id => {role_attributes: "", slot_config: "" },
        admin_role.id => {role_attributes: "", slot_config: "#{RoleConstants::SlotConfig::OPTIONAL}" } # To test slot configuration is updated only for mentoring roles
      }
    }, :tab => ProgramsController::SettingsTabs::MATCHING}

    assert mentee_role.reload.slot_config_optional?
    assert mentor_role.reload.slot_config_optional?
    assert teacher_role.reload.slot_config_optional?
    assert_false admin_role.reload.slot_config_enabled?
  end

  def test_project_slot_config_updated_for_super_user
    current_user_is :f_admin_pbe
    login_as_super_user

    p = programs(:pbe)
    mentor_role = p.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = p.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = p.roles.find_by(name: RoleConstants::TEACHER_NAME)
    admin_role = p.roles.find_by(name: RoleConstants::ADMIN_NAME)

    assert mentor_role.slot_config_optional?
    assert teacher_role.slot_config_optional?
    assert_false admin_role.slot_config_enabled?
    non_admin_roles = [mentor_role, mentee_role, teacher_role, admin_role]
    (non_admin_roles + [admin_role]).each do |role|
      assert_nil role.max_connections_limit
    end

    max_connections_limit_hash = { mentor_role.id => 7, mentee_role.id => 2, teacher_role.id => 4 }

    post_with_calendar_check :update, params: { :program => {:send_group_proposals =>[mentee_role.id], :needs_project_request_reminder => 1, :project_request_reminder_duration => 14, :role_permissions => {"#{mentor_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}, "#{mentee_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}, "#{teacher_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}},
      role: {
        mentor_role.id => {role_attributes: "", slot_config: "#{RoleConstants::SlotConfig::REQUIRED}", max_connections_limit: max_connections_limit_hash[mentor_role.id] },
        mentee_role.id => {role_attributes: "", slot_config: "#{RoleConstants::SlotConfig::OPTIONAL}", max_connections_limit: max_connections_limit_hash[mentee_role.id] },
        teacher_role.id => {role_attributes: "", slot_config: "", max_connections_limit: max_connections_limit_hash[teacher_role.id] },
        admin_role.id => {role_attributes: "", slot_config: "#{RoleConstants::SlotConfig::OPTIONAL}", max_connections_limit: 9 } # To test slot configuration is updated only for mentoring roles
      }
    }, :tab => ProgramsController::SettingsTabs::MATCHING}

    non_admin_roles.each do |role|
      assert_equal max_connections_limit_hash[role.id], role.reload.max_connections_limit
    end
    assert_nil admin_role.reload.max_connections_limit
    assert mentor_role.slot_config_required?
    assert mentee_role.slot_config_optional?
    assert_false teacher_role.slot_config_enabled?
    assert_false admin_role.slot_config_enabled?
  end

  def test_project_request_join_permission_updates_join_project_permission_not_present
    current_user_is :f_admin_pbe

    p = programs(:pbe)
    mentor_role = p.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = p.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = p.roles.find_by(name: 'teacher')
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
    assert p.allow_user_to_send_message_outside_mentoring_area?
    assert mentee_role.has_permission_name?("send_project_request")
    mentor_role.remove_permission("send_project_request")
    assert_false mentor_role.has_permission_name?("send_project_request")
    assert_false teacher_role.has_permission_name?("send_project_request")

    #no send_project_request permission for all roles
    post_with_calendar_check :update, params: { :program => {:send_group_proposals =>[mentee_role.id], :needs_project_request_reminder => 1, :project_request_reminder_duration => 14, :role_permissions => {"#{mentor_role.id}".to_sym => {"send_project_request" => true}, "#{mentee_role.id}".to_sym => {"send_project_request" => true}, "#{teacher_role.id}".to_sym => {"send_project_request" => true}},
      role: {
        mentor_role.id => { can_be_added_by_owners: true, role_attributes: "" },
        mentee_role.id => { can_be_added_by_owners: true, role_attributes: "" },
        teacher_role.id => { can_be_added_by_owners: true, role_attributes: "" }
      }
    }, :tab => ProgramsController::SettingsTabs::MATCHING}

    assert mentee_role.reload.has_permission_name?("send_project_request")
    assert_false mentor_role.reload.has_permission_name?("send_project_request")
    assert_false teacher_role.reload.has_permission_name?("send_project_request")

    #no send_project_request permission for all roles
    post_with_calendar_check :update, params: { :program => {:send_group_proposals =>[mentee_role.id], :needs_project_request_reminder => 1, :project_request_reminder_duration => 14, :role_permissions => {"#{mentor_role.id}".to_sym => {"send_project_request" => true}, "#{mentee_role.id}".to_sym => {"send_project_request" => true}, "#{teacher_role.id}".to_sym => {"join_project_permissions" => "", "send_project_request" => true}},
      role: {
        mentor_role.id => { can_be_added_by_owners: true, role_attributes: "" },
        mentee_role.id => { can_be_added_by_owners: true, role_attributes: "" },
        teacher_role.id => { can_be_added_by_owners: true, role_attributes: "" }
      }
    }, :tab => ProgramsController::SettingsTabs::MATCHING}

    assert mentee_role.reload.has_permission_name?("send_project_request")
    assert_false mentor_role.reload.has_permission_name?("send_project_request")
    assert teacher_role.reload.has_permission_name?("send_project_request")

  end

  def test_add_permission_to_allow_students_invite_mentors_and_students
    current_user_is :foster_admin
    join_settings = {RoleConstants::MENTOR_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE],
                     RoleConstants::STUDENT_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE]}
    p = programs(:foster)
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_mentors")
    assert p.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")
    assert_false p.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_students")

    assert_no_difference 'RolePermission.count' do
      post_with_calendar_check :update, params: { :program => {:join_settings => join_settings}, :tab => ProgramsController::SettingsTabs::MEMBERSHIP}
    end
    assert p.reload.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_mentors")
    assert_false p.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")
    assert_false p.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_students")

    assert_redirected_to edit_program_path(:tab => ProgramsController::SettingsTabs::MEMBERSHIP)
  end

  def test_add_permission_add_roles_without_approval
    current_user_is :foster_admin
    p = programs(:foster)
    mentor_role = roles("#{p.id}_mentor")
    mentee_role = roles("#{p.id}_student")
    assert_false p.has_role_permission?(RoleConstants::MENTOR_NAME, "become_student")
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "become_mentor")

    assert_difference 'RolePermission.count', 2 do
      post :update, params: {program: { role_permissions: {"#{mentor_role.id}".to_sym => {"add_role_permissions" => nil, "become_#{mentee_role.name}".to_sym => true}, "#{mentee_role.id}".to_sym => {"add_role_permissions" => nil, "become_#{mentor_role.name}".to_sym => true}}}, tab: ProgramsController::SettingsTabs::MEMBERSHIP }
    end

    assert p.has_role_permission?(RoleConstants::MENTOR_NAME, "become_student")
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "become_mentor")
  end

  def test_remove_permission_add_roles_without_approval
    current_user_is :foster_admin
    p = programs(:foster)
    mentor_role = roles("#{p.id}_mentor")
    mentee_role = roles("#{p.id}_student")
    mentee_role.add_permission("become_mentor")
    mentor_role.add_permission("become_student")
    assert p.has_role_permission?(RoleConstants::MENTOR_NAME, "become_student")
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "become_mentor")

    assert_difference 'RolePermission.count', -2 do
      post :update, params: {program: {role_permissions: {"#{mentor_role.id}".to_sym => {"add_role_permissions" => nil}, "#{mentee_role.id}".to_sym => {"add_role_permissions" => nil}}}, tab: ProgramsController::SettingsTabs::MEMBERSHIP }
    end

    assert_false p.has_role_permission?(RoleConstants::MENTOR_NAME, "become_student")
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "become_mentor")
  end


  def test_add_permission_reactive_groups
    current_user_is :f_admin_pbe
    p = programs(:pbe)

    mentor_role = roles("#{p.id}_mentor")
    mentee_role = roles("#{p.id}_student")
    teacher_role = roles("#{p.id}_teacher")
    assert_false p.has_role_permission?(RoleConstants::MENTOR_NAME, "reactivate_groups")
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "reactivate_groups")
    assert_false p.has_role_permission?(RoleConstants::TEACHER_NAME, "reactivate_groups")

    assert_difference 'RolePermission.count', 3 do
      post :update, params: {program: { role_permissions: {"#{mentor_role.id}".to_sym => {"reactivate_group_permissions" => nil, "reactivate_groups".to_sym => true}, "#{mentee_role.id}".to_sym => {"reactivate_group_permissions" => nil, "reactivate_groups".to_sym => true}, "#{teacher_role.id}".to_sym => {"reactivate_group_permissions" => nil, "reactivate_groups".to_sym => true}}}, tab: ProgramsController::SettingsTabs::CONNECTION }
    end

    assert p.has_role_permission?(RoleConstants::MENTOR_NAME, "reactivate_groups")
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "reactivate_groups")
    assert p.has_role_permission?(RoleConstants::TEACHER_NAME, "reactivate_groups")
  end

  def test_remove_permission_add_roles_without_approval
    current_user_is :f_admin_pbe
    p = programs(:pbe)
    mentor_role = roles("#{p.id}_mentor")
    mentee_role = roles("#{p.id}_student")
    teacher_role = roles("#{p.id}_teacher")

    mentee_role.add_permission("reactivate_groups")
    mentor_role.add_permission("reactivate_groups")
    teacher_role.add_permission("reactivate_groups")
    assert p.has_role_permission?(RoleConstants::MENTOR_NAME, "reactivate_groups")
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "reactivate_groups")
    assert p.has_role_permission?(RoleConstants::TEACHER_NAME, "reactivate_groups")
    assert_difference 'RolePermission.count', -3 do
      post :update, params: {program: {role_permissions: {"#{mentor_role.id}".to_sym => {"reactivate_group_permissions" => nil}, "#{mentee_role.id}".to_sym => {"reactivate_group_permissions" => nil}, "#{teacher_role.id}".to_sym => {"reactivate_group_permissions" => nil}}}, tab: ProgramsController::SettingsTabs::CONNECTION }
    end

    assert_false p.has_role_permission?(RoleConstants::MENTOR_NAME, "reactivate_groups")
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "reactivate_groups")
    assert_false p.has_role_permission?(RoleConstants::TEACHER_NAME, "reactivate_groups")
  end

  def test_should_show_auto_terminate_and_inactivity_tracking_period_in_edit_for_tab_3_for_foster_admin
    current_user_is :foster_admin
    programs(:foster).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select "div.inner_tabs" do
        assert_select "li.active", :text => "Mentoring Connection Settings"
      end
      assert_select "form.edit_program" do
        assert_select('select#program_inactivity_tracking_period_in_days')
        assert_select('select#program_feedback_survey_id')
        assert_select("input.cjs_auto_terminate_checkbox")
      end
    end
  end

  def test_should_get_program_edit_for_tab_0_for_multi_program_organization
    current_user_is @prog_manager

    program = programs(:albers)
    program.allow_one_to_many_mentoring = false
    program.save!

    get :edit
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select 'div#program_edit' do
        assert_select "div.inner_tabs" do
          assert_select "li.active", :text => "General Settings"
        end

        assert_select "form.edit_program" do
          assert_select "input[name=?][value='#{program.name}']", 'program[name]'
          assert_select "input[name='organization[subdomain]']", 0
          assert_select('span#program_subdomain', :text => 'primary.'+ DEFAULT_HOST_NAME + '/p/albers')
          assert_select("textarea#program_description")
          assert_select("input#program_organization_logo[type=file]", :count => 0)
          assert_select("input#program_logo[type=file]")

          assert_equal(Program::MentorRequestStyle::MENTEE_TO_MENTOR, assigns(:current_program).mentor_request_style)
          assert_equal(false, assigns(:current_program).allow_one_to_many_mentoring)

        end
      end
    end

    assert_template 'layouts/program'
  end

  def test_should_get_program_edit_for_tab_2_for_multi_program_organization
    current_user_is @prog_manager

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MEMBERSHIP}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select "div.inner_tabs" do
        assert_select "li.active", :text => "Membership"
      end
      assert_select "form.edit_program" do
        assert_select("input#mentor_can_invite_mentor")
        assert_select("input#mentor_can_invite_student")
        assert_select("input#student_can_invite_mentor")
        assert_select("input#student_can_invite_student")
      end
    end
  end

  def test_should_show_auto_terminate_and_inactivity_tracking_period_in_edit_for_tab_3_for_program_manager
    current_user_is @prog_manager

    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_template 'edit'
    assert_select 'html' do
      assert_select 'div#page_heading', /Program Settings/
      assert_select "div.inner_tabs" do
        assert_select "li.active", :text => "Mentoring Connection Settings"
      end
      assert_select "form.edit_program" do
        assert_select('select#program_inactivity_tracking_period_in_days')
        assert_select("input.cjs_auto_terminate_checkbox")
      end
    end
  end

  def test_should_not_get_program_edit_for_tab_6_for_multi_program_organization
    current_user_is @prog_manager
    Organization.any_instance.stubs(:standalone?).returns(false)
    assert_raise Authorization::PermissionDenied do
      get :edit, params: { :tab => ProgramsController::SettingsTabs::SECURITY}
    end
  end

  def test_show_connection_reminder_setting_for_matching_by_mentee_alone_track
    current_user_is users(:f_admin)
    current_program_is programs(:albers)

    assert programs(:albers).matching_by_mentee_alone?

    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_select "div#program_form" do
      assert_no_select "input#program_needs_mentoring_request_reminder"
      assert_no_select "input#program_mentoring_request_reminder_duration"
      assert_no_select "input#program_mentor_request_expiration_days"
    end
  end

  def test_hide_connection_reminder_setting_for_matching_by_admin_alone_track
    current_user_is users(:no_mreq_admin)
    current_program_is programs(:no_mentor_request_program)

    assert programs(:no_mentor_request_program).matching_by_admin_alone?

    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_select "div#program_form" do
      assert_no_select "input#program_needs_mentoring_request_reminder"
      assert_no_select "input#program_mentoring_request_reminder_duration"
      assert_no_select "input#program_mentor_request_expiration_days"
    end
  end

  def test_show_connection_reminder_setting_for_matching_by_mentee_and_admin_track
    current_user_is users(:moderated_admin)
    current_program_is programs(:moderated_program)

    assert programs(:moderated_program).matching_by_mentee_and_admin?

    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_select "div#program_form" do
      assert_no_select "input#program_needs_mentoring_request_reminder"
      assert_no_select "input#program_mentoring_request_reminder_duration"
      assert_no_select "input#program_mentor_request_expiration_days"
    end
  end

  def test_super_user_can_edit_super_user_general_settings
    current_user_is users(:f_admin)
    login_as_super_user

    get :edit, params: { :tab => ProgramsController::SettingsTabs::GENERAL}
    assert_response :success
    assert_select "div#program_form" do
      assert_select "input#program_sort_users_by_0"
      assert_select "input#program_notification_setting_messages_notification_0"
      assert_select "input#program_number_of_licenses"
    end
  end

  def test_non_super_user_cannot_edit_super_user_general_settings
    current_user_is users(:f_admin)

    get :edit, params: { :tab => ProgramsController::SettingsTabs::GENERAL}
    assert_response :success
    assert_select "div#program_form" do
      assert_no_select "input#program_sort_users_by_0"
      assert_no_select "input#program_allows_logged_in_pages_true"
      assert_no_select "input#program_notification_setting_messages_notification_0"
      assert_no_select "input#program_number_of_licenses"
    end
  end

  def test_super_user_can_edit_super_user_connection_settings
    current_user_is users(:f_admin)
    login_as_super_user

    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_select "div#program_form" do
      assert_no_select "input#program_allow_non_match_connection_true"
      assert_no_select "textarea#program_zero_match_score_message"
      assert_select "input#program_allow_connection_feedback_true"
      assert_no_select "input#program_prevent_manager_matching_false"
      assert_no_select "input#program_manager_matching_level"
      assert_select "input#program_hybrid_templates_enabled_true"
      assert_no_select "input.cjs_hidden_slot_config"
    end
  end

  def test_non_super_user_cannot_edit_super_user_connection_settings
    current_user_is users(:f_admin)

    get :edit, params: { :tab => ProgramsController::SettingsTabs::CONNECTION}
    assert_response :success
    assert_select "div#program_form" do
      assert_no_select "input#program_allow_non_match_connection_true"
      assert_no_select "textarea#program_zero_match_score_message"
      assert_no_select "input#program_allow_connection_feedback_true"
      assert_no_select "input#program_prevent_manager_matching_false"
      assert_no_select "input#program_manager_matching_level"
    end
  end

  def test_super_user_can_edit_super_user_matching_settings
    current_user_is :f_admin_pbe
    login_as_super_user

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    assert_response :success
    assert_select "div#program_form" do
      assert_select "input#program_allow_non_match_connection_true"
      assert_select "textarea#program_non_match_text"
      assert_select "input#program_prevent_past_mentor_matching"
      assert_select "input.cjs_hidden_slot_config"
    end
  end

  def test_non_super_user_cannot_edit_super_user_matching_settings
    current_user_is :f_admin_pbe

    get :edit, params: { :tab => ProgramsController::SettingsTabs::MATCHING}
    assert_response :success
    assert_select "div#program_form" do
      assert_no_select "input#program_allow_non_match_connection_true"
      assert_no_select "textarea#program_non_match_text"
      assert_no_select "input#program_prevent_past_mentor_matching"
      assert_no_select "input.cjs_hidden_slot_config"
    end
  end

  def test_non_super_user_cannot_edit_super_user_security_settings
    current_user_is users(:f_admin)
	Organization.any_instance.stubs(:standalone?).returns(false)
    assert_raise Authorization::PermissionDenied do
      get :edit, params: { :tab => ProgramsController::SettingsTabs::SECURITY}
    end
  end

  def test_super_user_can_edit_super_user_security_settings
    current_user_is users(:f_admin)
    login_as_super_user
    Organization.any_instance.stubs(:standalone?).returns(true)
    get :edit, params: { :tab => ProgramsController::SettingsTabs::SECURITY}
    assert_response :success
    assert_select "div#program_form" do
      assert_select "input#login_exp_per_enable"
      assert_select "input#account_lockout"
      assert_select "input#auto_password_expiry"
      assert_select "input#password_history_limit"
      assert_select "input#program_organization_security_setting_attributes_can_show_remember_me_true"
      assert_select "input#program_organization_security_setting_attributes_email_domain"
      assert_select "input#security_setting_attributes_allowed_ips_from"
    end
  end

  ############
  def test_should_get_program_edit_for_invalid_tab_number
    current_user_is @prog_manager
    current_program_is :albers

    assert_permission_denied do
      get :edit, params: { :tab => 100}
    end
  end

  # Admin program creation behaviour. The page after admin signup is program
  # update where the admin can add/change program details, including name and
  # domain.
  #
  def test_should_first_update_program
    user = users(:f_admin)
    organization = programs(:org_primary)
    @request.session[:member_id] = user.member_id
    @request.session[:new_organization_id] = organization.id
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true

    program = Program.create!(:name => "Temp name", :root => "temper", :organization => programs(:org_primary), engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    current_user_is make_member_of(program, user)
    assert_equal Program::MentorRequestStyle::NONE, program.mentor_request_style
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::BOTH)
    assert program.allow_mentor_update_maxlimit?

    post_with_calendar_check :update, params: {
      :first_visit => 1,
      :program => {
      :name => 'srini',
      :description => 'This is a group',
      :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_ADMIN,
      :can_increase_connection_limit => 0,
      :can_decrease_connection_limit => 0
    }, :tab => ProgramsController::SettingsTabs::GENERAL}

    program.reload
    assert_redirected_to program_root_url(subdomain: organization.subdomain, host: organization.domain, protocol: organization.get_protocol, root: program.root)
    assert_equal program, assigns(:program)
    assert_equal 'srini', program.name
    assert_equal 'This is a group', program.description
    assert_equal(180.days, program.mentoring_period)
    assert program.matching_by_mentee_and_admin?
    assert_false program.allow_mentor_update_maxlimit?
    assert_nil @request.session[:member_id]
    assert_nil @request.session[:new_organization_id]
  end

  def test_update_program_calendar_setting
    current_user_is :f_admin
    current_program_is :albers
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    cal_setting = program.calendar_setting

    assert program.calendar_setting.present?
    post_with_calendar_check :update, params: {
      :program => {},
      tab: ProgramsController::SettingsTabs::CONNECTION,
      :calendar_settings => {
        :slot_time_in_minutes => 60,
        :max_pending_meeting_requests_for_mentee => 12,
        :allow_create_meeting_for_mentor => true,
        feedback_survey_delay_not_time_bound: 25
    }}

    program.reload
    assert_equal program, assigns(:program)
    assert_equal cal_setting.slot_time_in_minutes, program.calendar_setting.slot_time_in_minutes
    assert_not_equal 60, program.calendar_setting.slot_time_in_minutes
    assert_not_equal 12, program.calendar_setting.max_pending_meeting_requests_for_mentee
    assert_false program.calendar_setting.allow_create_meeting_for_mentor?
    assert_equal 25, program.calendar_setting.feedback_survey_delay_not_time_bound
  end

  def test_update_program_should_not_toggle_off_mentoring_offers
    current_user_is :f_admin
    current_program_is :albers
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)

    post_with_calendar_check :update, params: { :program => {
      :name => 'albers new',
      :description => 'All about albers',
      :mentoring_period_value => '6',
      :mentoring_period_unit => Program::MentoringPeriodUnit::WEEKS,
      :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_ADMIN,
      :allow_one_to_many_mentoring => true,
      :max_connections_for_mentee => 2,
      :mentor_name => "Newmentor",
      :student_name => 'Newmentee'
    }}

    assert program.reload.enabled_features.include?(FeatureName::OFFER_MENTORING)
  end

  def test_disable_mentor_offer_in_matching_tab_update
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.enable_feature(FeatureName::CALENDAR)

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, :program=>{enabled_features: [FeatureName::CALENDAR], calendar_setting: {allow_mentor_to_configure_availability_slots: "1", allow_mentor_to_describe_meeting_preference: "1", slot_time_in_minutes: "30", allow_create_meeting_for_mentor: "true", :advance_booking_time => "1", max_pending_meeting_requests_for_mentee: "1", max_capacity_student_frequency: 10}, needs_meeting_request_reminder: "1", meeting_request_reminder_duration: "1", :meeting_request_auto_expiration_days =>"1", mentor_offer_needs_acceptance: "false"}}

    assert program.reload.disabled_features.include?(FeatureName::OFFER_MENTORING)
  end

  def test_enable_mentor_offer_in_matching_tab_update
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING, false)
    program.enable_feature(FeatureName::CALENDAR)

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, :program=>{enabled_features: [FeatureName::OFFER_MENTORING, FeatureName::CALENDAR], calendar_setting: {allow_mentor_to_configure_availability_slots: "1", allow_mentor_to_describe_meeting_preference: "1", slot_time_in_minutes: "30", allow_create_meeting_for_mentor: "true", :advance_booking_time => "1", max_pending_meeting_requests_for_mentee: "1", max_capacity_student_frequency: 10}, needs_meeting_request_reminder: "1", meeting_request_reminder_duration: "1", :meeting_request_auto_expiration_days =>"1", mentor_offer_needs_acceptance: "false"}}

    assert program.reload.enabled_features.include?(FeatureName::OFFER_MENTORING)
  end

  def test_update_disable_allow_end_users_to_see_match_scores
    current_user_is :f_admin
    program = programs(:albers)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    admin_role = program.find_role(RoleConstants::ADMIN_NAME)

    assert program.reload.allow_end_users_to_see_match_scores
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, program.mentor_request_style
    assert student_role.has_permission_name?("send_mentor_request")
    assert admin_role.has_permission_name?("manage_mentor_requests")

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: { "allow_end_users_to_see_match_scores" => "0" }}

    assert_false program.reload.allow_end_users_to_see_match_scores
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, program.mentor_request_style
    assert student_role.reload.has_permission_name?("send_mentor_request")
    assert admin_role.reload.has_permission_name?("manage_mentor_requests")
  end

  def test_update_allow_end_users_to_see_match_scores
    current_user_is :f_admin
    program = programs(:albers)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    admin_role = program.find_role(RoleConstants::ADMIN_NAME)

    assert program.reload.allow_end_users_to_see_match_scores
    program.allow_end_users_to_see_match_scores = false
    program.save!
    assert_false program.reload.allow_end_users_to_see_match_scores
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, program.mentor_request_style
    assert student_role.has_permission_name?("send_mentor_request")
    assert admin_role.has_permission_name?("manage_mentor_requests")
    program.mentor_requests.active.update_all(status: AbstractRequest::Status::CLOSED)

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: { "allow_end_users_to_see_match_scores" => "1" }}

    assert program.reload.allow_end_users_to_see_match_scores
    assert_equal Program::MentorRequestStyle::NONE, program.mentor_request_style
    assert_false student_role.reload.has_permission_name?("send_mentor_request")
    assert_false admin_role.reload.has_permission_name?("manage_mentor_requests")
  end

  def test_should_update_all_mentors_connection_limit
    current_user_is :f_admin
    current_program_is :albers
    program = programs(:albers)
    user1 = programs(:albers).mentor_users.first
    user2 = programs(:albers).mentor_users.last
    program.update_attributes(:default_max_connections_limit => 10)
    user1.update_attribute(:max_connections_limit, 5)
    user2.update_attribute(:max_connections_limit, 8)
    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::MATCHING, :program => {
      :can_increase_connection_limit => 1, :can_decrease_connection_limit => 0, :apply_to_all_mentors => 1, :default_max_connections_limit => 20
    }}
    assert_equal 20, user1.reload.max_connections_limit
    assert_equal 20, user2.reload.max_connections_limit
    assert_equal 20, program.reload.default_max_connections_limit
    assert_equal Program::ConnectionLimit::ONLY_INCREASE, program.connection_limit_permission
    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::MATCHING, :program => {
      :apply_to_all_mentors => 0, :default_max_connections_limit => 30
    }}
    assert_equal 20, user1.reload.max_connections_limit
    assert_equal 20, user2.reload.max_connections_limit
    assert_equal 30, program.reload.default_max_connections_limit
    assert_equal Program::ConnectionLimit::ONLY_INCREASE, program.connection_limit_permission
  end

  def test_cannot_update_email_theme_override_without_super_user
    current_user_is :f_admin
    current_program_is :albers
    program = programs(:albers)

    assert_permission_denied do
      post_with_calendar_check :update, params: {
        :program => {
        :email_theme_override => '#111112'
      }}
    end

    program.reload
    assert_false program.email_theme_override, "#111112"
  end

  def test_can_update_email_theme_override_with_super_user
    current_user_is :f_admin
    current_program_is :albers
    login_as_super_user
    program = programs(:albers)

    post_with_calendar_check :update, params: {
      :program => {
      :email_theme_override => '#111112'
    }}

    program.reload
    assert_equal program.email_theme_override, "#111112"
  end

  def test_first_time_actions_for_student
    current_user_is users(:f_student)
    # Not connected, so that we can see first time actions.
    users(:f_student).groups.destroy_all
    User.any_instance.expects(:can_send_mentor_request?).at_least(0).returns(false)

    users(:f_student).update_attribute(:created_at, 1.week.ago)
    assert users(:f_student).recently_joined?

    get :show
    assert_response :success

    assert_false assigns(:render_quick_connect_box)
  end

  def test_first_time_actions_for_mentor
    RecentActivity.destroy_all
    current_user_is users(:f_mentor)

    # Not connected, so that we can see first time actions.
    users(:f_mentor).groups.destroy_all

    users(:f_mentor).update_attribute(:created_at, 1.week.ago)
    assert users(:f_mentor).recently_joined?

    get :show
    assert_response :success

    assert_false assigns(:render_quick_connect_box)
  end

  def test_first_time_actions_for_mentor_calendar_feature_enabled
    MeetingRequest.destroy_all
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    RecentActivity.destroy_all
    current_user_is users(:f_mentor)

    # Not connected, so that we can see first time actions.
    users(:f_mentor).groups.destroy_all

    users(:f_mentor).update_attribute(:created_at, 1.week.ago)
    assert users(:f_mentor).recently_joined?

    get :show
    assert_response :success

    # The @render_quick_connect_box is false as the recently_joined? is true and the user is a mentor
    assert_equal 0, assigns(:new_meeting_requests_count)
  end

  def test_first_time_actions_for_student_calendar_feature_enabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:f_student)

    users(:f_student).update_attribute(:created_at, 1.week.ago)
    assert users(:f_student).recently_joined?

    get :show
    assert_response :success
    assert assigns(:render_quick_connect_box)
    assert_nil assigns(:mentors_score)
  end

  def test_should_not_show_invite_user_quick_link_to_student_when_friendly_invite_disabled
    current_user_is users(:f_student)
    join_settings = {RoleConstants::MENTOR_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTOR_CAN_INVITE],
                     RoleConstants::STUDENT_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTOR_CAN_INVITE]}
    programs(:albers).update_join_settings(join_settings)

    # Make the user not a recently joined one, so as to show the invite quick links
    users(:f_student).update_attribute(:created_at, 3.weeks.ago)
    assert !users(:f_student).recently_joined?

    get :show
    assert_response :success

    assert_no_select "a.invite_icon"
  end

  def test_should_not_show_invite_user_quick_link_to_mentor_when_friendly_invite_disabled
    current_user_is users(:f_mentor)
    join_settings = {RoleConstants::MENTOR_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE],
                     RoleConstants::STUDENT_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE]}
    programs(:albers).update_join_settings(join_settings)

    # Make the user not a recently joined one, so as to show the invite quick links
    users(:f_mentor).update_attribute(:created_at, 3.weeks.ago)
    assert !users(:f_mentor).recently_joined?

    get :show
    assert_response :success

    assert_no_select "a.invite_icon"
  end

  def test_should_show_public_and_my_mentoring_connections
    u = users(:mentor_1)
    program = u.program
    org = programs(:org_primary)
    prog = programs(:albers)
    prog.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    u.program.update_attributes!(:allow_users_to_mark_connection_public => true)

    u.update_attribute(:max_connections_limit, 10)
    create_group(name: "Group 2", students: [users(:student_4)], mentors: [u], program: program)
    create_group(name: "Group 3", students: [users(:student_5)], mentors: [u], program: program)
    create_group(name: "Group 4", students: [users(:student_6)], mentors: [u], program: program)

    assert prog.connection_profiles_enabled?
    assert u.program.allow_users_to_mark_connection_public?

    current_user_is u

    get :show
    assert_response :success

    assert_select 'ul#side-menu' do
      assert_select 'li' do
        assert_select 'a', :href => groups_path(:show => 'my'),  :text => /View All.*/
      end
    end
  end


  def test_should_show_my_connections_quick_link_to_mentor_with_connections
    u = users(:f_mentor)
    current_user_is u

    assert u.groups.any?
    assert_equal 1, u.groups.size

    get :show
    assert_response :success

    assert_equal 1, assigns(:my_mentoring_connections).count
    assert_select 'a', :href => groups_path(:show => 'my')
  end

  def test_should_show_my_connections_quick_link_to_mentor_even_with_closed_connections
    u = users(:requestable_mentor)
    current_user_is u

    assert u.groups.closed.any?
    assert u.groups.active.blank?

    get :show, params: { src: "recent-activities"}
    assert_response :success

    assert_equal 0, assigns(:my_mentoring_connections).count
    assert_select 'a', :href => groups_path(:show => 'my')
    assert_equal "recent-activities", assigns(:src)
  end

  def test_should_show_my_connections_quick_link_to_student_with_connections
    student = users(:student_1)

    current_user_is student

    assert student.groups.any?
    assert_equal 2, student.groups.size

    get :show
    assert_response :success

    assert_equal 1, assigns(:my_mentoring_connections).count
    assert_select 'a', :href => groups_path(:show => 'my')
  end

  def test_should_show_my_connections_quick_link_to_student_even_with_closed_connections
    student = users(:student_4)

    current_user_is student

    assert student.groups.closed.any?
    assert student.groups.active.blank?

    get :show
    assert_response :success

    assert_equal 0, assigns(:my_mentoring_connections).count
    assert_select 'a', :href => groups_path(:show => 'my')
  end


  def test_should_show_my_connections_quick_link_to_mentor_without_connections
    u = users(:mentor_2)
    current_user_is u

    assert u.groups.blank?

    get :show
    assert_response :success

    assert_select 'a', :href => groups_path(:show => 'my')
  end

  def test_should_show_my_connections_quick_link_to_student_without_connections
    u = users(:f_student)
    current_user_is u

    assert u.groups.blank?

    get :show
    assert_response :success

    assert_select 'a', :href => groups_path(:show => 'my')
  end

  def test_show_quick_links_with_hide_side_bar
    current_user_is :f_student

    get :show, params: { hide_side_bar: "true"}
    assert_response :success
    assert_select 'html' do
      assert_no_select 'div#sidebarRight'
    end
    assert assigns(:hide_side_bar)
    assert_no_select "a.add_icon"
  end

  def test_show_connect_calendar_prompt
    current_user_is :f_student
    program = programs(:albers)

    assert_false program.calendar_sync_v2_for_member_applicable?
    get :show
    assert_response :success
    assert_false assigns(:connect_calendar_prompt)
  end

  def test_show_connect_calendar_prompt_after_calendar_sync_v2_enable
    current_user_is :f_student
    program = programs(:albers)

    program.enable_feature(FeatureName::CALENDAR_SYNC_V2)
    program.enable_feature(FeatureName::CALENDAR)
    assert program.calendar_sync_v2_enabled?
    assert program.calendar_sync_v2_for_member_applicable?
    get :show
    assert_response :success
    assert assigns(:connect_calendar_prompt)

    Member.any_instance.stubs(:synced_external_calendar?).returns(true)
    get :show
    assert_response :success
    assert_false assigns(:connect_calendar_prompt)
  end

  def test_show_connect_calendar_prompt_after_org_wide_calendar_enable
    current_user_is :f_student
    program = programs(:albers)

    program.enable_feature(FeatureName::ORG_WIDE_CALENDAR_ACCESS)
    assert_false program.calendar_sync_v2_for_member_applicable?
    get :show
    assert_response :success
    assert_false assigns(:connect_calendar_prompt)
  end

  def test_should_not_show_requests_box_when_pending_requests_not_moderated_group
    current_user_is @prog_manager
    current_program_is :albers
    create_mentor_request

    get :show
    assert_response :success
    assert_select 'html' do
      assert_select "a[href=?]", mentor_requests_path, :count => 0
    end
  end

  def test_should_not_show_mentor_offers_link_when_feature_disabled
    current_user_is :f_mentor
    assert_false programs(:albers).mentor_offer_enabled?
    get :show
    assert_response :success
    assert_nil assigns(:new_mentor_offers_count)
    assert_select 'html' do
      assert_select "a[href=?]", mentor_offers_path, count: 0
    end
  end

  def test_should_not_show_mentor_offers_link_when_acceptance_not_needed
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert program.mentor_offer_enabled?
    assert_false program.mentor_offer_needs_acceptance?
    get :show
    assert_response :success
    assert_nil assigns(:new_mentor_offers_count)
    assert_select 'html' do
      assert_select "a[href=?]", mentor_offers_path, count: 0
    end
  end

  def test_should_show_mentor_offers_link_for_mentors
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    assert program.mentor_offer_enabled?
    assert program.mentor_offer_needs_acceptance?
    create_mentor_offer
    get :show
    assert_response :success
    assert_equal 0, assigns(:new_mentor_offers_count)
  end

  def test_should_show_mentor_offers_link_for_student
    current_user_is :f_student
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    assert program.mentor_offer_enabled?
    assert program.mentor_offer_needs_acceptance?
    create_mentor_offer
    get :show
    assert_response :success
    assert_equal 1, assigns(:new_mentor_offers_count)
    assert_select 'html' do
      assert_select "a[href=?]", mentor_offers_path(src: "#{EngagementIndex::Src::BrowseMentors::HEADER_NAVIGATION}"), :text => /Mentoring Offers/
      assert_select "div.badge-danger", :text => "1"
    end
  end

  def test_should_not_show_mentor_offers_link_for_other_roles
    current_user_is :f_user
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    assert program.mentor_offer_enabled?
    assert program.mentor_offer_needs_acceptance?
    get :show
    assert_response :success
    assert_nil assigns(:new_mentor_offers_count)
    assert_select 'html' do
      assert_select "a[href=?]", mentor_offers_path, count: 0
    end
  end

  def test_should_show_quick_link_to_three_sixty_survey_for_assessee
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :f_student

    get :show
    assert_response :success

    assert_select 'a', :href => three_sixty_my_surveys_path

    three_sixty_surveys(:survey_1).publish!
    get :show
    assert_response :success

    assert_select 'a', :href => three_sixty_my_surveys_path
  end

  def test_does_not_show_recent_activities_if_user_cannot_view_ra
    current_user_is :f_student

    fetch_role(:albers, :student).remove_permission('view_ra')
    get :show
    assert_response :success
    assert_false assigns(:is_recent_activities_present)
    assert_no_select "#recent_activities"
  end

  def test_show_recent_activities_if_either_student_and_mentor_view_permissions_are_there
    current_user_is :f_student

    get :show
    assert_response :success
    assert_not_nil assigns(:is_recent_activities_present)
    assert_select "#recent_activities"
  end

  def test_program_home_should_be_accessible_to_members
    current_program_is :albers
    current_user_is :f_mentor

    get :show
    assert_response :success
    assert_match /ga\('create'/, @response.body
    assert_match /ga\('set'/, @response.body
    assert_match /ga\('set', 'anonymizeIp', true\)/, @response.body
    assert_match /ga\('send', 'pageview', Analytics.getPageUrlForGA\(window.location.href\)\)/, @response.body
  end

  def test_program_home_should_be_accessible_to_mentess_who_are_members
    current_user_is users(:f_student)

    get :show
    assert_response :success
  end

  def test_other_program_homepage_accessed_by_external_user
    current_program_is :ceg

    get :show, params: { :external_user => true}
    assert_not_equal users(:ram).program, assigns(:current_program)
    assert_redirected_to about_path()
  end

  def test_program_home_should_not_be_accessible_to_unlogged_in_non_members
    current_member_is :ram
    current_program_is :ceg

    get :show
    assert_not_equal users(:ram).program, assigns(:current_program)
    assert_redirected_to about_path()
  end

  def test_show_suspended_user
    member = members(:inactive_user)
    program = programs(:psg)
    setup_admin_custom_term(organization: programs(:org_anna_univ))
    programs(:org_anna_univ).term_for(CustomizedTerm::TermType::PROGRAM_TERM).update_term(term: "Track")

    member.update_attribute(:state, Member::Status::ACTIVE)
    assert member.user_in_program(program).suspended?

    current_program_is program
    current_member_is member
    get :show
    assert_redirected_to about_path

    assert_match /Your access to the track may have been temporarily revoked. Please re-join the track .*again.* or contact the super admin .*here.*/, flash[:error]
  end

  def test_show_suspended_user_with_src_membership_request_created_present
    member = members(:inactive_user)
    program = programs(:psg)
    member.update_attribute(:state, Member::Status::ACTIVE)
    assert member.user_in_program(program).suspended?

    current_program_is program
    current_member_is member
    get :show, params: { src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE}
    assert_redirected_to about_path(src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
    assert_nil flash[:error]
  end

  def test_should_show_no_content_for_a_program_without_description
    p = programs(:albers)
    p.description = ""
    p.save

    make_member_of(p, @prog_manager)
    current_program_is :albers
    current_user_is @prog_manager

    get :show
    assert_response :success
  end

  def test_should_get_program_manage_for_admin
    current_user_is @prog_manager
    current_program_is :albers

    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    get :manage
    assert_response :success
    assert assigns(:show_pendo_launcher_in_all_devices)
    assert programs(:albers).allow_track_admins_to_access_all_users
    assert_false programs(:albers).user_csv_import_enabled?

    assert assigns(:show_add_user_options_popup)
  end

  def test_show_add_user_options_standalone_org
    current_user_is :foster_admin

    programs(:org_foster).update_attribute(:allow_track_admins_to_access_all_users, true)

    get :manage
    assert_response :success
    assert assigns(:show_pendo_launcher_in_all_devices)
    assert programs(:org_foster).standalone?
    assert programs(:org_foster).allow_track_admins_to_access_all_users
    assert_false programs(:org_foster).user_csv_import_enabled?

    assert_false assigns(:show_add_user_options_popup)
  end

  def test_manage_should_not_be_accessible_to_non_admins
    current_program_is :albers
    current_user_is :f_mentor

    assert_raise(Authorization::PermissionDenied) { get :manage }
  end

  def test_do_not_show_new_program_link_when_feature_disabled
    o = programs(:org_foster)
    current_user_is :foster_admin

    assert o.standalone?
    assert_false o.subprogram_creation_enabled?
    get :manage
    assert_response :success
    assert_tab 'Manage'
    assert_select "a", :text => "New Program", :count => 0
  end

  def test_manage_for_show_add_user_options_popup
    current_program_is :albers
    current_user_is :f_admin

    get :manage

    assert_response :success

    assert_false programs(:albers).allow_track_admins_to_access_all_users
    assert_false programs(:albers).user_csv_import_enabled?

    assert_false assigns(:show_add_user_options_popup)
  end

  def test_do_show_new_program_link_when_feature_enabled
    o = programs(:org_foster)
    o.enable_feature(FeatureName::SUBPROGRAM_CREATION, true)
    current_user_is :foster_admin

    assert o.standalone?
    assert o.subprogram_creation_enabled?
    get :manage
    assert_response :success
    assert_tab 'Manage'
    assert_select "a", :text => "New Program"
  end

  def test_program_show_without_login_should_redirect_to_program_about_path
    current_program_is :albers

    get :show
    assert_redirected_to about_path
  end

  def test_show_all_activities
    current_user_is :f_admin

    User.any_instance.expects(:activities_to_show).with(:actor => members(:f_admin)).never
    User.any_instance.expects(:activities_to_show).with(:offset_id=>nil, :per_page=>5).returns([[] ,false])

    get :show_activities, xhr: true
    assert_response :success
    assert_false assigns(:from_activity_button)
  end

  def test_show_all_activities_from_activity_button
    current_user_is :f_admin

    User.any_instance.expects(:activities_to_show).with(:actor => members(:f_admin)).never
    User.any_instance.expects(:activities_to_show).with(:offset_id=>nil, :per_page=>20).returns([[] ,false])

    get :show_activities, xhr: true, params: { src: "activity-button", per_page: RecentActivityConstants::PER_PAGE }
    assert_response :success
    assert assigns(:from_activity_button)
    assert_equal "activity-button", assigns(:src)
  end

  def test_show_activities_with_right_locale
    current_locale = I18n.locale
    member_locale = :"fr-CA"
    assert member_locale != current_locale

    Language.last.update_column(:language_name, member_locale)
    member = members(:f_admin)
    Language.set_for_member(member, member_locale)
    current_user_is :f_admin

    get :show_activities, xhr: true
    assert_response :success
    assert_equal I18n.locale, member_locale
  end

  def test_show_my_activities
    current_user_is :f_admin

    User.any_instance.expects(:activities_to_show).returns([[] ,false])

    get :show_activities, xhr: true, params: { :my => 1}
    assert_response :success
  end

  def test_connection_activities_should_not_be_rendered_for_admin_only
    current_user_is :f_admin

    get :show_activities, xhr: true, params: { :connection => 1}
    assert_response :success

    assert assigns(:recent_activities).blank?
  end

  def test_should_not_fetch_conn_activities_if_no_groups
    current_user_is :f_mentor

    get :show_activities, xhr: true, params: { :connection => 1}
    assert_response :success

    assert assigns(:recent_activities).blank?
  end

  def test_should_update_primary_home_tab
    current_user_is :f_mentor

    assert_no_difference("Delayed::Job.count") do
      get :update_prog_home_tab_order, xhr: true, params: { :tab_order => 1}
    end
    assert_response :success

    assert_equal 1,users(:f_mentor).reload.primary_home_tab
  end

  def test_no_recent_activities_if_not_primitive_role
    current_program_is :albers
    current_user_is @prog_manager
    assert !@prog_manager.is_admin_or_mentor_or_student?

    get :show
    assert_response :success
    assert_nil assigns(:is_recent_activities_present)
    assert_no_select 'div#recent_activities'
  end

  def test_programs_show_should_fetch_the_recent_activities_for_mentor_for_a_mentor
    current_user_is :f_mentor

    mock_recent_activities = mock('recent_activities')
    Program.any_instance.expects(:recent_activities).returns(mock_recent_activities)

    mock_recent_activities_with_joins = mock('mock_recent_activities_with_joins')
    mock_recent_activities.expects(:joins).with(:programs).returns(mock_recent_activities_with_joins)

    mock_recent_activities_with_includes = mock('mock_recent_activities_with_includes')
    mock_recent_activities_with_joins.expects(:includes).with([:ref_obj, :member => [:users, :profile_picture, :active_programs]]).returns(mock_recent_activities_with_includes)
    new_mock_ras = mock('new_mock_ras')
    mock_recent_activities_with_includes.expects(:for_mentor).with(users(:f_mentor)).returns(new_mock_ras)
    new_mock_ras_1 = mock('new_mock_ras_1')
    new_mock_ras.expects(:for_display).returns(new_mock_ras_1)
    new_mock_ras_1.expects(:with_upper_offset).never
    new_mock_ras_1.expects(:with_length).with(RecentActivityConstants::PER_PAGE_SIDEBAR).returns([])
    User.any_instance.expects(:ra_exclude_types).returns([])
    get :show_activities, xhr: true
    assert_response :success
  end

  def test_progams_show_should_fetch_the_recent_activities_for_all_for_a_non_primitive_ro_with_permission
    p = programs(:albers)
    user_role = p.find_role('user')
    user_role.add_permission('view_ra')
    user = users(:f_mentor)
    user.role_names = 'user'
    user.save

    qa_question = QaQuestion.last
    event = RecentActivityConstants::Type::QA_QUESTION_CREATION
    target = RecentActivityConstants::Target::ALL
    member = qa_question.user.member

    current_user_is :f_mentor
    get :show
    assert_response :success
    assert_not_nil assigns(:is_recent_activities_present)
    assert_select "#recent_activities"
  end

  # ------------- Mentors Programs
  def test_should_show_home_page_for_mentor
    current_user_is :f_mentor

    get :show
    assert_response :success

    assert_select "div#recent_activities"
  end

  def test_should_update_program_security_setting_success
    current_user_is :foster_admin
    login_as_super_user
    organization = programs(:org_foster)
    setting = organization.security_setting
    assert_nil setting.allowed_ips

    allowed_ips = [
      { from: '127.0.0.1', to: '' },
      { from: '192.168.0.1', to: '192.168.0.225' }
    ]

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::SECURITY, program: {
      organization: {
        security_setting_attributes: { allowed_ips: allowed_ips, id: setting.id}
      }
    }, :secure_invite_link_enable => "1"}
    assert_redirected_to edit_program_path(tab: ProgramsController::SettingsTabs::SECURITY)
    assert_equal "Your changes have been saved", flash[:notice]
    assert_equal "127.0.0.1,192.168.0.1:192.168.0.225", setting.reload.allowed_ips
  end

  def test_should_update_program_security_setting_fails
    current_user_is :foster_admin
    organization = programs(:org_foster)
    setting = organization.security_setting
    assert_nil setting.allowed_ips

    setting.allowed_ips = "0.0.0.0"
    setting.save!
    assert_equal "0.0.0.0", organization.security_setting.allowed_ips

    allowed_ips = [
      { from: '127.0.0.1', to: '' },
      { from: '127.0.0.258', to: '192.168.0.225' },
      { from: 'example.com', to: '' }
    ]

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::SECURITY, program: {
      organization: {
        security_setting_attributes: { allowed_ips: allowed_ips, id: setting.id}
      }
    }}
    assert_response :success
    assert_nil flash[:notice]
    assert_equal "0.0.0.0", organization.security_setting.reload.allowed_ips
  end

  def test_update_terms_and_conditions_failure_if_display_custom_terms_only_flag_present
    admin_member = members(:foster_admin)
    organization = admin_member.organization
    assert_nil organization.privacy_policy
    assert_nil organization.agreement
    organization.update_attribute(:display_custom_terms_only, true)

    current_member_is admin_member
    post_with_calendar_check :update, params: { id: organization.id, tab: 0, program: {
      organization: {
        name: "Updated Name",
        agreement: "My agreement",
        privacy_policy: "My Policy"
      }
    }}
    organization.reload
    assert_nil organization.agreement
    assert_nil organization.privacy_policy
  end

  def test_update_terms_and_conditions_success_if_display_custom_terms_only_flag_not_set
    current_member_is members(:foster_admin)
    prev_policy = programs(:org_foster).privacy_policy
    prev_agreement = programs(:org_foster).agreement
    assert_nil prev_policy
    assert_nil prev_agreement
    post_with_calendar_check :update, params: { :id => programs(:org_foster).id, :tab => 0, :program => {
      :organization => {
        :name => "Updated Name",
        :agreement => "My agreement",
        :privacy_policy => "My Policy"
      }
    }}
    assert_equal programs(:org_foster).reload.agreement, "My agreement"
    assert_equal programs(:org_foster).privacy_policy, "My Policy"
  end

  def test_edit_when_disallow_edit_for_custom_terms_alone_true
    current_member_is members(:foster_admin)
    org = programs(:org_foster)
    org.agreement = "test"
    org.privacy_policy = "test"
    assert_false programs(:org_foster).display_custom_terms_only
    org.display_custom_terms_only = true
    org.save!
    get :edit, params: { :id => programs(:org_foster).id}
    assert_response :success
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:tab)
    assert_select "div#agreement_actions", count: 0
    assert_select "div#privacy_actions", count: 0
    assert_select "div#cur_agreement[class=\"well square-well scroll-1 no-margin input-class-disabled\"]"
  end

  def test_disallow_edit_for_custom_terms_false
    current_member_is members(:foster_admin)
    get :edit, params: { :id => programs(:org_foster).id}
    assert_response :success
    assert_select "div#agreement_actions"
    assert_select "div#privacy_actions"
    assert_select "div#cur_agreement[class=\"well square-well scroll-1 no-margin \"]"
  end

  def test_should_update_program_success
    user = @prog_manager
    program = programs(:albers)

    program.allow_one_to_many_mentoring = false
    program.mentoring_period = 6.months
    program.save

    current_user_is user
    assert_equal "Mentor", programs(:org_primary).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
    assert_equal 'Mentee', programs(:org_primary).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term

    assert_equal "Mentor", program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
    assert_equal 'Student', program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term

    assert_equal(6.months, program.mentoring_period)
    assert_nil program.max_connections_for_mentee
    assert(!program.allow_one_to_many_mentoring?)

    post_with_calendar_check :update, params: { :program => {
      :name => 'albers new',
      :description => 'All about albers',
      :allow_one_to_many_mentoring => true,
      :mentor_name => "Newmentor",
      :student_name => 'Newmentee'
    }}

    program.reload
    programs(:org_primary).reload

    assert_redirected_to edit_program_path(:tab => ProgramsController::SettingsTabs::GENERAL) # Rails3L
    assert_equal "Your changes have been saved", flash[:notice]
    assert_equal program, assigns(:program)
    assert_equal 'albers new', program.name
    assert_equal 'All about albers', program.description
    assert_equal "Mentor", program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
    assert_equal 'Student', program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term
    # Organization level changes cannot be changed
    assert_equal "Mentor", programs(:org_primary).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
    assert_equal 'Mentee', programs(:org_primary).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term
    assert program.allow_one_to_many_mentoring?

    # This should not be updated
    assert_equal(Program::MentorRequestStyle::MENTEE_TO_MENTOR, program.mentor_request_style)
  end

  def test_should_change_mentoring_period_in_months
    user = @prog_manager
    program = programs(:albers)
    program.mentoring_period = 4.months
    program.save

    current_user_is user
    current_program_is :albers
    assert_equal 4.months, program.mentoring_period

    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::CONNECTION, :program => {
      :mentoring_period_value => "5",
      :mentoring_period_unit => Program::MentoringPeriodUnit::WEEKS
    }}
    assert_equal 5.weeks, program.reload.mentoring_period
  end

  def test_should_change_mentoring_period_in_days
    user = @prog_manager
    program = programs(:albers)
    program.mentoring_period = 23.days
    program.save

    current_user_is user
    current_program_is :albers
    assert_equal 23.days, program.mentoring_period

    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::CONNECTION, :program => {
      :mentoring_period_value => "19",
      :mentoring_period_unit => Program::MentoringPeriodUnit::DAYS
    }}
    assert_equal 19.days, program.reload.mentoring_period
  end

  def test_should_show_special_flash_on_mentoring_period_change
    program = programs(:albers)
    program.mentoring_period = 6.months
    program.save!

    current_user_is @prog_manager
    current_program_is :albers
    assert_equal 6.months, program.mentoring_period
    assert_equal Program::DEFAULT_CONNECTION_TRACKING_PERIOD * 1.day, program.inactivity_tracking_period
    assert_not_nil program.feedback_survey

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::CONNECTION, program: {
      mentoring_period_value: "12",
      mentoring_period_unit: Program::MentoringPeriodUnit::WEEKS,
      inactivity_tracking_period_in_days: '7',
      feedback_survey_id: nil
    }}

    assert_redirected_to edit_program_path(tab: ProgramsController::SettingsTabs::CONNECTION)
    assert_equal "Your changes have been saved. The duration of mentoring connection will be applied only to newly formed mentoring connections.", flash[:notice]
    assert_equal 12.weeks, program.reload.mentoring_period
    assert_equal 7.days, program.inactivity_tracking_period
    assert_nil program.feedback_survey
  end

  def test_update_feedback_survey
    program = programs(:albers)
    current_user_is @prog_manager
    current_program_is :albers
    existing_feedback_survey = program.feedback_survey
    assert existing_feedback_survey.present?

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::CONNECTION, program: { feedback_survey_id: surveys(:two).id.to_s }}
    assert_redirected_to edit_program_path(tab: ProgramsController::SettingsTabs::CONNECTION)
    assert_equal surveys(:two), program.feedback_survey
    assert_false existing_feedback_survey.reload.is_feedback_survey?
  end

  def test_update_auto_terminate_and_inactivity_tracking_period
    user = @prog_manager
    program = programs(:albers)
    current_user_is user
    current_program_is :albers
    assert_false program.auto_terminate_reason_id.present?
    assert_equal Program::DEFAULT_CONNECTION_TRACKING_PERIOD * 1.day, program.inactivity_tracking_period
    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::CONNECTION,  :program => {
      :inactivity_tracking_period_in_days => '7',
      :auto_terminate_checkbox => true, :auto_terminate_reason_id => program.permitted_closure_reasons.first.id
    }}
    program.reload
    assert_equal(7.days, program.inactivity_tracking_period)
    assert_equal(true, program.auto_terminate_reason_id.present?)
  end

  def test_should_update_program_failure
    program = programs(:albers)
    current_user_is @prog_manager

    assert_nothing_raised do
      post_with_calendar_check :update, params: {
        :program => {
        :name => '',
        :description => 'All about albers'
      }}
    end
    program.reload
    assert_response :success
    assert_template 'edit'
    assert_equal program, assigns(:current_program)
    assert assigns(:program).name.blank?
  end

  def test_remove_manager_feature_when_manager_question_is_present_standalone_org
    prog = programs(:custom_domain)
    current_user_is :custom_domain_admin
    current_program_is prog
    org = prog.organization
    login_as_super_user
    ProfileQuestion.create!(
      :organization => org,
      :question_type => ProfileQuestion::Type::MANAGER,
      :section => org.sections.first,
      :question_text => "Manager"
    )

    assert org.enabled_features.include?(FeatureName::MANAGER)
    assert org.profile_questions.manager_questions.any?
    assert org.standalone?

    post_with_calendar_check :update, params: { :id => prog.id, :tab => ProgramsController::SettingsTabs::FEATURES, :program => { :organization => {
      :enabled_features => org.enabled_features - [FeatureName::MANAGER]
    }}}

    assert_equal "Manager feature cannot be disabled when Manager type profile question is present", flash[:error]
    assert org.reload.enabled_features.include?(FeatureName::MANAGER)
  end

  def test_enable_subprogram_creation_for_non_standalone_orgs
    o = programs(:org_primary)
    assert_false o.has_feature?(FeatureName::MEMBER_TAGGING)

    current_user_is users(:f_admin)
    login_as_super_user

    assert_nothing_raised do
      post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::FEATURES, "program"=>{"organization"=>{"enabled_features"=>["", "articles", "answers", "member_tagging", "manager"]}}, :features_tab=>"true"}
    end
    assert_false o.reload.has_feature?(FeatureName::MEMBER_TAGGING)
    assert programs(:albers).has_feature?(FeatureName::MEMBER_TAGGING)
  end

  def test_enable_subprogram_creation_for_standalone_orgs
    o = programs(:org_foster)
    assert_false o.has_feature?(FeatureName::SUBPROGRAM_CREATION)

    current_user_is users(:foster_admin)
    login_as_super_user

    assert_nothing_raised do
      post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::FEATURES, "program"=>{"organization"=>{"enabled_features"=>["", "articles", "answers", "subprogram_creation"]}}, :features_tab=>"true"}
    end
    #For standlone orgs, it should always update the above feature info only at the organization
    #level and not at the program level
    assert o.reload.has_feature?(FeatureName::SUBPROGRAM_CREATION)
    assert programs(:foster).has_feature?(FeatureName::SUBPROGRAM_CREATION)
  end

  def test_super_user_should_be_able_to_edit_su_features
    o = programs(:org_foster)
    assert o.has_feature?(FeatureName::SKYPE_INTERACTION)
    assert_false o.has_feature?(FeatureName::MEMBER_TAGGING)

    current_user_is users(:foster_admin)
    login_as_super_user

    assert_nothing_raised do
      post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::FEATURES, "program"=>{"organization"=>{"enabled_features"=>["", "articles", "answers", "member_tagging"]}}, :features_tab=>"true"}
    end
    assert o.has_feature?(FeatureName::SKYPE_INTERACTION)
    assert_false o.has_feature?(FeatureName::MEMBER_TAGGING)
    assert_false programs(:foster).has_feature?(FeatureName::SKYPE_INTERACTION)
    assert programs(:foster).has_feature?(FeatureName::MEMBER_TAGGING)
  end

  def test_non_super_user_should_not_be_able_enable_a_su_features
    o = programs(:org_foster)
    assert o.has_feature?(FeatureName::SKYPE_INTERACTION)
    assert_false o.has_feature?(FeatureName::MEMBER_TAGGING)
    current_user_is users(:foster_admin)

    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::FEATURES, "program"=>{"organization"=>{"enabled_features"=>["", "articles", "answers", "member_tagging"]}}, :features_tab=>"true"}
    end
    assert_false o.reload.has_feature?(FeatureName::MEMBER_TAGGING)
    assert o.has_feature?(FeatureName::SKYPE_INTERACTION)
  end

  def test_non_super_user_should_not_be_able_disable_a_su_features
    o = programs(:org_foster)
    assert o.has_feature?(FeatureName::SKYPE_INTERACTION)
    assert_false o.has_feature?(FeatureName::MEMBER_TAGGING)
    current_user_is users(:foster_admin)

    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::FEATURES, "program"=>{"organization"=>{"enabled_features"=>["", "articles", "answers", "member_tagging"]}}, :features_tab=>"true"}
    end
    assert_false o.reload.has_feature?(FeatureName::MEMBER_TAGGING)
    assert o.reload.has_feature?(FeatureName::SKYPE_INTERACTION)
  end

  def test_update__should_ignore_organization_level_features__in_non_standalone_organization
    program = programs(:albers)
    organization = program.organization
    Organization.any_instance.stubs(:standalone?).returns(false)
	ProgramsControllerTest.any_instance.stubs(:super_console?).returns(false)

    current_user_is :f_admin
    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::FEATURES, "program" => { "organization" => { "enabled_features" => [""] } }}
    end
  end

  def test_programs_show_for_mentor_should_fetch_groups_and_other_mentors
    current_user_is :f_mentor
    Announcement.destroy_all
    mentor = users(:f_mentor)
    mentor.update_attribute :max_connections_limit, 5
    assert_equal 5, mentor.max_connections_limit
    ongoing_groups = []
    closed_groups = []

    # Create 10 students and assign some of them to the mentor.
    1.upto(10) do |i|
      student = create_user(:name => "student", :role_names => [RoleConstants::STUDENT_NAME], :email => "student_#{i}_sample@chronus.com")

      if i % 2 == 0
        # Create a group with the given mentor and student.
        group = create_group(:mentor => mentor, :students => [student], :program => programs(:albers))

        # Terminate one of the groups.
        if i == 6
          group.terminate!(users(:f_admin), "Hello", group.program.permitted_closure_reasons.first.id)
          closed_groups << group
        else
          ongoing_groups << group
        end
      end
    end

    ongoing_groups.each do |g|
      g.update_attribute(:last_activity_at, g.id.seconds.ago)
    end

    get :show
    assert_response :success
    assert_equal ongoing_groups, assigns(:my_mentoring_connections).last(4)
    assert_equal 6, assigns(:my_all_connections_count)
  end

  def test_program_show_should_not_fetch_unpublished_mentors_for_program
    current_user_is :f_student

    get :show
    assert_response :success
  end

  def test_mentor_student_goes_to_his_home
    current_user_is :f_mentor_student
    mentor_student = users(:f_mentor_student)

    my_mentors = []
    studying_connections = []
    2.times do |i|
      my_mentors << create_user(:name => "mentor", :role_names => [RoleConstants::MENTOR_NAME], :email => "mentor#{i}_sample@chronus.com")
      studying_connections << create_group(:mentor => my_mentors.last, :student => mentor_student)
    end

    my_students = []
    mentoring_connections = []
    2.times do |i|
      my_students << create_user(:name => "student", :role_names => [RoleConstants::STUDENT_NAME], :email => "student#{i}_sample@chronus.com")
      mentoring_connections << create_group(:student => my_students.last, :mentor => mentor_student)
    end

    create_mentor_request(:student => users(:f_student), :mentor => mentor_student)
    mentor_student.reload

    mentoring_connections.each do |g|
      g.update_attribute(:last_activity_at, g.id.seconds.ago)
    end

    studying_connections.each do |g|
      g.update_attribute(:last_activity_at, g.id.seconds.ago)
    end

    get :show
    assert_response :success
    assert_equal_unordered mentoring_connections + studying_connections, assigns(:my_mentoring_connections)
    assert_equal 4, assigns(:my_all_connections_count)
    assert_equal 1, assigns(:new_mentor_requests_count)
    assert_equal 1, assigns(:past_requests_count)
    assert_equal 2, assigns(:cumulative_requests_notification_count)
  end

  def test_programs_show_for_student_should_fetch_groups_and_other_mentors
    current_user_is :f_student

    student = users(:f_student)
    groups = []

    # Create 10 mentors and assign some of them to the student.
    1.upto(5) do |i|
      mentor = create_user(:name => "mentor", :role_names => [RoleConstants::MENTOR_NAME], :email => "mentor_#{i}@chronus.com")
      groups << create_group(:mentor => mentor, :students => [student], :program => programs(:albers))
    end

    groups.each do |g|
      g.update_attribute(:last_activity_at, g.id.seconds.ago)
    end

    get :show
    assert_response :success
    assert_equal groups, assigns(:my_mentoring_connections)
    assert_equal 5, assigns(:my_all_connections_count)
  end

  def test_invite_students_and_add_mentors_empty_actions_for_recently_if_privileged
    role = create_role(:name => 'invitor', :program => programs(:no_mentor_request_program))
    programs(:no_mentor_request_program).reload
    invitor = create_user(:name => 'invitor', :role_names => ['invitor'], :program => programs(:no_mentor_request_program))
    current_user_is invitor

    add_role_permission(role, 'invite_students')
    add_role_permission(role, 'invite_mentors')
    add_role_permission(role, 'view_mentors')
    add_role_permission(role, 'view_students')
    assert invitor.can_invite_students?
    assert invitor.can_invite_mentors?
    assert invitor.can_view_mentors?
    assert invitor.can_view_students?

    get :show
    assert_response :success

    # Pane actions should not be rendered since they will be redundant.
    assert_select 'div.pane_action > a[href=?]', invite_users_path, :count => 0
    assert_select 'div.pane_action > a[href=?]', new_user_path(:role => RoleConstants::MENTOR_NAME), :count => 0
  end

  def test_should_not_render_profile_update_prompt_for_students_profile_questions_update_if_there_are_no_answers
    current_user_is :f_student
    2.times { create_question }

    get :show
    assert_response :success
    assert_update_prompt_is_not_shown
  end

  def test_should_render_profile_update_prompt_for_students_profile_questions_update
    current_user_is :f_student
    2.times { create_question }
    ProfileAnswer.skip_timestamping do
      ProfileAnswer.create!(
        :ref_obj => members(:f_student), :answer_text => "Abc",
        :profile_question => ProfileQuestion.last, :created_at => 2.days.ago, :updated_at => 2.days.ago)
    end

    create_question

    get :show
    assert_response :success
    assert_update_prompt_is_not_shown
  end

  def test_should_not_render_profile_update_prompt_for_mentors_on_mentee_profile_questions_update
    # 3 student questions
    3.times { create_question }
    current_user_is :f_mentor

    get :show
    assert_response :success
    assert_update_prompt_is_not_shown
  end

  def test_should_not_show_profile_update_prompt_if_the_update_is_greater_2_weeks_old
    ProfileQuestion.skip_timestamping do
      3.times { create_question(:updated_at => 3.weeks.ago) }
    end

    current_user_is :f_student

    get :show
    assert_response :success
    assert_update_prompt_is_not_shown
  end

  def test_should_not_show_profile_update_prompt_if_the_cookie_is_set
    ProfileQuestion.skip_timestamping do
      3.times { create_question(:updated_at => 1.week.ago) }
    end
    current_user_is :f_student
    @request.cookies[DISABLE_PROFILE_PROMPT] = programs(:albers).profile_questions_last_update_timestamp(users(:f_student))

    get :show
    assert_response :success
    assert_update_prompt_is_not_shown
  end

  def test_should_show_profile_update_prompt_for_a_recent_update_if_the_cookie_is_set_for_an_old_update
    ProfileQuestion.skip_timestamping do
      3.times { create_question(:updated_at => 2.days.ago) }
    end
    current_user_is :f_student
    ProfileAnswer.skip_timestamping do
      ProfileAnswer.create(
        :ref_obj => members(:f_student), :answer_text => "asb",
        :profile_question => ProfileQuestion.last, :created_at => 1.day.ago, :updated_at => 1.day.ago)
    end

    @request.cookies[DISABLE_PROFILE_PROMPT] = 3.days.ago.to_i
    # Create a new question again
    create_student_question


    get :show
    assert_response :success
    assert_update_prompt_is_not_shown
  end

  def test_should_set_cookie_on_disable_profile_update_prompt
    current_user_is :f_mentor
    get :disable_profile_update_prompt, params: { :t => 123}

    assert_response :success
    assert_equal "123", cookies[DISABLE_PROFILE_PROMPT]
    assert_time_is_equal_with_delta(2.weeks.from_now, assigns(:cookie_expiration_time))
  end

  def test_should_not_render_banner_help_if_page_help_banner_is_not_set
    current_user_is :f_mentor

    get :show
    assert_no_select 'h3.page_help_banner'
  end

  # There will be no flash message when the user is not prompted
  def test_no_flash_for_student_in_tightly_when_no_prompt
    MentorRequest.destroy_all
    current_user_is :moderated_student

    get :show
    assert_response :success
    assert_no_flash_in_page
  end

  # There will a flash message when the user is prompted
  def test_will_be_flash_for_student_in_tightly_when_prompt_for_mentors_listing_only
    MentorRequest.destroy_all
    setup_admin_custom_term
    current_user_is :moderated_student
    users(:moderated_student).program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attributes(:term_downcase => "alien", :pluralized_term_downcase => "aliens")
    create_favorite(:user => users(:moderated_student), :favorite => users(:moderated_mentor))

    get :show
    assert_response :success
    assert_equal "You have 1 preferred alien. <a href=\"#{new_mentor_request_path}\">Send a request</a> to super admin for alien assignment or continue adding aliens.", flash[:notice]
  end

  def test_should_render_analytics_script
    current_user_is @prog_manager
    programs(:albers).update_attribute(:analytics_script, "test_analytics_script")

    get :show
    assert_match("test_analytics_script", @response.body)
  end

  def test_should_update_analytics_script
    current_user_is :f_admin
    login_as_super_user
    programs(:albers).update_attribute(:analytics_script, "abc")

    post_with_calendar_check :update_analytics, params: { :program => {:analytics_script => 'def'}}
    assert_equal('def', programs(:albers).reload.analytics_script)
  end

  def test_index
    current_member_is :f_admin
    get :index
    assert_response :success
    assert !assigns(:current_program)
    assert_select 'a[href=?]', program_root_path(:subdomain => programs(:org_primary).subdomain, :root => programs(:albers).root),
      :text => programs(:albers).name

    assert_select("noscript") do
      assert_select "div#noscript_warning", :text => /Javascript is not currently enabled in your browser. Please enable Javascript in order for this site to work properly/ do
        assert_select "a", :href => "http://www.google.com/support/bin/answer.py?answer=23852", :target => "_blank", :text => "Please enable Javascript"
      end
    end
  end

  def test_index_redirect
    current_user_is @prog_manager
    get :index
    assert_redirected_to program_root_path(:root => 'albers')
    assert assigns(:current_program)
  end

  def test_unmoderated_program_admin_view_of_program_home_page_should_see_mentor_requests
    current_user_is @prog_manager

    get :show
    assert_template 'show'

    assert_select "a", :text => /Mentor Requests/, :count => 0
  end

  def test_unmoderated_program_mentor_view_of_program_home_page_should_not_see_mentor_requests
    current_user_is :f_mentor

    get :show
    assert_template 'show'

    assert_select "a", :text => /Mentoring Requests/
  end

  def test_moderated_program_mentor_view_of_program_home_page_should_see_mentor_requests
    current_user_is create_user(:name => "mentor", :role_names => [RoleConstants::MENTOR_NAME], :program => programs(:moderated_program))

    get :show
    assert_template 'show'

    assert_select "a", :text => /Mentor Requests/, :count => 0
  end

  def test_admin_search_for_unpublished_mentor
    current_user_is :foster_admin

    # Search for an unpublished mentor
    get :search, params: { :query => users(:foster_mentor7).name}
    assert_response :success
    assert_false assigns(:results).blank?
    assert assigns(:results).collect{|res| res[:active_record]}.include?(users(:foster_mentor7))

    # Search for a published mentor
    get :search, params: { :query => users(:foster_mentor5).name}
    assert_response :success
    assert_false assigns(:results).blank?
    assert assigns(:results).collect{|res| res[:active_record]}.include?(users(:foster_mentor5))

    assert_false assigns(:mentee_groups_map).present?
    assert_false assigns(:existing_connections_of_mentor).present?
    assert_false assigns(:profile_last_updated_at).present?

    assert_false assigns(:viewer_can_find_mentor).present?
    assert_false assigns(:viewer_can_offer).present?
    assert_false assigns(:offer_pending).present?
    assert_nil assigns(:mentors_count)

    assert_false assigns(:mentor_draft_count).present?
    assert_false assigns(:mentors_list).present?
    assert_false assigns(:students_with_no_limit).present?
    assert_false assigns(:mentor_required_questions).present?
  end

  def test_admin_search_for_student
    student_user = users(:f_student)

    ActiveRecord::Base.stubs(:per_page).returns(10000)
    current_user_is :f_admin
    get :search, params: { query: student_user.name }
    assert_response :success
    assert assigns(:results).collect { |res| res[:active_record] }.include?(student_user)
    assert_blank assigns(:mentee_groups_map)
    assert_blank assigns(:existing_connections_of_mentor)
    assert_blank assigns(:profile_last_updated_at)
    assert_blank assigns(:offer_pending)
    assert_blank assigns(:students_with_no_limit)

    assert_false assigns(:viewer_can_find_mentor)
    assert_false assigns(:viewer_can_offer)
    assert assigns(:student_draft_count).present?
    assert assigns(:mentors_list).present?
    assert_nil assigns(:mentors_count)

    assert_equal_unordered student_user.mentors.map(&:id), assigns(:mentors_list)[student_user.id].map(&:id)
    assert_equal student_user.program.required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
  end

  def test_user_search_with_accented_names
    members(:f_student).update_attributes(first_name: "Chloé")
    members(:f_mentor).update_attributes(first_name: "Chloe")
    reindex_documents(updated: members(:f_student).users + members(:f_mentor).users)

    current_user_is :f_admin
    get :search, params: { query: "Chloe"}
    results = assigns(:results)
    assert_response :success
    assert_equal_unordered [members(:f_student).id, members(:f_mentor).id], results.collect { |r| r[:active_record].id if r[:active_record].class == User }.compact

    get :search, params: { query: "Chloé"}
    results = assigns(:results)
    assert_response :success
    assert_equal_unordered [members(:f_student).id, members(:f_mentor).id], results.collect { |r| r[:active_record].id if r[:active_record].class == User }.compact
  end

  def test_other_mentor_search_for_unpublished_mentor_with_no_results
    current_user_is :foster_mentor5
    # Search for an unpublished mentor
    assert users(:foster_mentor6).profile_pending?
    get :search, params: { :query => users(:foster_mentor6).name}
    assert_response :success
    assert assigns(:results).blank?
    assert_equal 0, assigns(:total_results)
  end

  def test_other_mentor_search_for_unpublished_mentor_with_results
    users(:foster_mentor7).update_attribute(:state, User::Status::ACTIVE)
    current_user_is :foster_mentor7
    # Search for a published mentor
    assert_false users(:foster_mentor5).profile_pending?
    get :search, params: { :query => users(:foster_mentor5).name}
    assert_response :success
    assert_false assigns(:results).blank?
    assert assigns(:results).collect{|res| res[:active_record]}.include?(users(:foster_mentor5))
    mentor_user = users(:foster_mentor5)
    assert_false assigns(:can_render_calendar_ui)
    assert_equal [mentor_user.id], assigns(:mentors_with_slots).keys
    assert_equal [], assigns(:active_or_drafted_students_count).keys
    assert_false assigns(:sent_mentor_offers_pending).present?
    assert_nil assigns(:mentor_draft_count)
    assert_nil assigns(:students_count)
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::MENTOR_NAME), assigns(:mentor_required_questions)
  end

  def test_search_mentee_as_a_mentor_with_mentor_offer_enabled
    current_user_is :f_mentor
    programs(:albers).organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    get :search, params: { :query => users(:f_student).name}
    assert_response :success
    assert_false assigns(:results).blank?

    mentor = users(:f_mentor)
    student = users(:f_student)
    assert assigns(:results).collect{|res| res[:active_record]}.include?(student)
    assert_equal mentor.students, assigns(:mentee_groups_map).keys
    assert_equal mentor.groups, assigns(:mentee_groups_map).values.flatten
    assert_equal mentor.groups, assigns(:existing_connections_of_mentor)
    assert_false assigns(:profile_last_updated_at).present?

    assert assigns(:viewer_can_offer)
    assert_false assigns(:viewer_can_find_mentor)
    assert_false assigns(:offer_pending).present?
    assert_false assigns(:student_draft_count).present?
    assert_false assigns(:mentors_list).present?

    assert_not_nil assigns(:mentors_count)
    assert_false assigns(:students_with_no_limit).present?
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
  end

  def test_mentee_search_for_student
    current_user_is :f_mentor_student

    # Search for a published student
    get :search, params: { :query => users(:f_student).name}
    assert_response :success
    assert_false assigns(:results).blank?
    student_user = users(:f_student)
    assert assigns(:results).collect{|res| res[:active_record]}.include?(student_user)
    assert_false assigns(:mentee_groups_map).present?
    assert_false assigns(:existing_connections_of_mentor).present?
    assert_false assigns(:profile_last_updated_at).present?

    assert_false assigns(:viewer_can_find_mentor)
    assert_false assigns(:viewer_can_offer)
    assert_false assigns(:offer_pending).present?
    assert_nil assigns(:mentors_count)

    assert_false assigns(:student_draft_count).present?
    assert_false assigns(:mentors_list).present?
    assert_false assigns(:students_with_no_limit).present?

    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
  end

  def test_track_user_search_activity_for_student
    user = users(:f_student)
    current_user_is user
    UserSearchActivity.expects(:add_user_activity).once
    get :search, params: { :query => users(:f_mentor).name}

    @controller.stubs(:working_on_behalf?).returns(true)
    UserSearchActivity.expects(:add_user_activity).never
    get :search, params: { :query => users(:f_mentor).name}
  end

  def test_track_user_search_activity_for_mentor
    current_user_is :f_mentor
    UserSearchActivity.expects(:add_user_activity).never
    get :search, params: { :query => users(:f_student).name}
  end

  def test_track_user_search_activity_for_admin
    current_user_is :f_admin
    UserSearchActivity.expects(:add_user_activity).never
    get :search, params: { :query => users(:f_student).name}
  end


  def test_search_for_student_and_mentor_assigns_required_questions
    current_user_is :f_admin
    programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).last.update_attributes(required: true)
    programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).last.update_attributes(required: true)

    get :search, params: { :query => users(:f_user).first_name} #there are many mentors and mentees with "user" in their name
    assert_response :success
    assert_false assigns(:results).blank?

    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::MENTOR_NAME), assigns(:mentor_required_questions)
  end

  def test_search_for_groups_student
    current_program_is :pbe
    current_user_is :f_student_pbe

    get :search, params: { query: "project_b"}
    assert_response :success

    assert_page_title "Search results for project_b"
    assert assigns(:find_new)
    assert assigns(:connection_questions)
    assert assigns(:results).collect{|res| res[:active_record]}.include?(groups(:group_pbe_1))
  end

  def test_manage_page_should_render_invite_link_if_invite_friends_is_disabled
    current_user_is :f_admin
    join_settings = {RoleConstants::MENTOR_NAME => [],
                     RoleConstants::STUDENT_NAME => []}
    programs(:albers).update_join_settings(join_settings)
    get :manage
    assert_response :success
    assert_select "a[href=?]",
      h(program_invitations_path),
      :count => 1
  end

  def test_manage_page_should_render_forums
    current_user_is :f_admin
    programs(:albers).enable_feature(FeatureName::USER_CSV_IMPORT, true)

    get :manage

    assert_select "a[href=\"#{forums_path}\"]"

    assert_false programs(:albers).allow_track_admins_to_access_all_users
    assert programs(:albers).user_csv_import_enabled?

    assert assigns(:show_add_user_options_popup)
  end

  def test_admin_should_not_be_see_use_two_name_fields_setting
    current_user_is :f_admin

    get :edit, params: { :tab => ProgramsController::SettingsTabs::GENERAL}
    assert_select "input[type=radio][name=?]", "program[sort_users_by]", :count => 0
  end

  def test_super_user_should_see_change_use_two_name_fields_setting
    current_user_is @prog_manager
    login_as_super_user

    get :edit, params: { :tab => ProgramsController::SettingsTabs::GENERAL}
    assert_select "input[type=radio][name=?][value='#{programs(:albers).sort_users_by}']", "program[sort_users_by]"
  end

  def test_super_user_should_be_able_update_use_two_name_fields_setting
    current_user_is @prog_manager
    login_as_super_user
    assert_equal(Program::SortUsersBy::FULL_NAME, programs(:albers).sort_users_by)

    post_with_calendar_check :update, params: { :program => { :sort_users_by => Program::SortUsersBy::LAST_NAME }}
    assert_response :redirect

    assert_equal(Program::SortUsersBy::LAST_NAME, programs(:albers).reload.sort_users_by)
  end

  def test_super_user_should_be_able_to_edit_analytics_script
    current_user_is :f_admin
    login_as_super_user

    get :edit_analytics
    assert_response :success
  end

  def test_non_super_user_should_not_be_able_to_edit_analytics_script
    current_user_is :f_admin

    get :edit_analytics
    assert_redirected_to super_login_path
  end

  def test_new_from_another_program
    current_user_is :f_admin

    get :new
    assert_response :success
    assert_template 'new'
    assert assigns(:program)
    assert_tab 'Manage'
  end

  def test_new_auth
    current_user_is :f_mentor

    assert_permission_denied do
      get :new
    end
  end

  def test_create_with_invalid_params_program_should_fail
    current_user_is :foster_admin
    organization = programs(:org_foster)
    organization.update_attribute(:can_update_root, true)
    program = programs(:foster)

    assert organization.standalone?

    assert_no_difference "organization.reload.programs.count" do
      params = {
        program: {
          root: "main"
        },
        creation_way: Program::CreationWay::MANUAL,
        current: {
          name: "New Department",
          root: "new-dept"
        },
        organization: {
          name: "Updated Foster Organization"
        }
      }

      post_with_calendar_check :create, params: params
    end

    assert_response :success
    assert_template 'new'
  end

  def test_create_with_calendar_enabled
    current_user_is :foster_admin
    organization = programs(:org_foster)
    program = programs(:foster)
    organization.update_attribute(:can_update_root, true)

    assert organization.standalone?

    params = {
      program: {
        engagement_type: "1",
        enabled_features: ["calendar"],
        name: "New Department",
        root: "new-dept"
      },
      creation_way: Program::CreationWay::MANUAL,
      :current => {
        :name => "New Department",
        :root => "new-dept"
      },
      organization: {
        name: "Updated Foster Organization"
      }
    }
    assert_nothing_raised do
      assert_difference "organization.reload.programs.count" do
        post_with_calendar_check :create, params: params
      end
    end

    assert Program.last.calendar_enabled?
  end

  def test_create_success_from_another_program_first_sub_program
    current_user_is :foster_admin

    assert programs(:org_foster).standalone?

    assert_difference 'User.count' do
      assert_difference 'programs(:org_foster).reload.programs_count' do
        assert_difference 'programs(:org_foster).programs.reload.size' do
          post_with_calendar_check :create, params: { :program => {
            :name => 'Department Of ComputerScience',
            :description => 'Some description',
            :engagement_type => Program::EngagementType::CAREER_BASED,
            :program_type => Program::ProgramType::CHRONUS_MENTOR,
            :number_of_licenses => 5243,
            :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_ADMIN,
            :allow_one_to_many_mentoring => true
          },
          :creation_way => Program::CreationWay::MANUAL,
          :current => {
            :name => "New Department",
            :root => "new-dept"
          },
          :organization => {
            :name => "Updated Foster Organization"
          }}
        end
      end
    end

    assert_redirected_to program_root_path(:root => 'p1')
    assert_equal "The Program has been successfully setup!", flash[:notice]
    assert_equal 'p1', assigns(:program).root
    assert_equal 'Department Of ComputerScience', assigns(:program).name
    assert_equal 'Some description', assigns(:program).description
    assert assigns(:program).career_based?
    assert_equal Program::MentorRequestStyle::MENTEE_TO_ADMIN, assigns(:program).mentor_request_style
    assert assigns(:program).allow_one_to_many_mentoring?
    assert_equal Program::ProgramType::CHRONUS_MENTOR, assigns(:program).program_type
    assert_equal 5243, assigns(:program).number_of_licenses

    program = Program.find_by(root: 'p1')
    assert_false program.nil?
    user = program.users.last
    assert_equal program, user.program
    assert user.is_admin_only?
    assert_equal user, assigns(:current_user)
    assert_equal user, program.owner

    programs(:foster).reload
    programs(:org_foster).reload

    assert_equal "New Department", programs(:foster).name
    assert_equal "main", programs(:foster).root

    assert_equal "Updated Foster Organization", programs(:org_foster).name
    assert_equal "foster", programs(:org_foster).subdomain
  end

  def test_create_failure_from_another_program_first_sub_program
    current_user_is :foster_admin

    assert programs(:org_foster).standalone?
    assert_no_difference 'User.count' do
      assert_no_difference 'programs(:org_foster).reload.programs_count' do
        assert_no_difference 'programs(:org_foster).reload.programs.size' do
          post_with_calendar_check :create, params: { :program => {
            :root => 'dcse',
            :name => '',
            :description => 'Some description',
            :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_ADMIN,
            :allow_one_to_many_mentoring => true
          },
            :creation_way => Program::CreationWay::MANUAL,
            :current => {
            :name => "New Department",
            :root => "new-dept"
          },
            :organization => {
            :name => "Updated Foster Organization"
          }}
        end
      end
    end

    assert_response :success
    assert_template 'new'

    # No changes to the program or organization.
    programs(:foster).reload
    programs(:org_foster).reload

    assert_equal "foster", programs(:foster).name
    assert_equal "main", programs(:foster).root

    assert_equal "Foster School of Business", programs(:org_foster).name
    assert_equal "foster", programs(:org_foster).subdomain
  end

  def test_create_success_from_another_program_not_first_sub_program
    current_user_is :ceg_admin
    members(:psg_only_admin).update_attribute(:admin,true)

    assert_difference 'User.count', 2 do
      assert_difference 'programs(:org_anna_univ).reload.programs_count' do
        assert_difference 'programs(:org_anna_univ).reload.programs.size' do
          post_with_calendar_check :create, params: {
            :creation_way => Program::CreationWay::MANUAL,
            :program => {
              :name => 'Department Of ComputerScience',
              :description => 'Some description',
              :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_ADMIN,
              :allow_one_to_many_mentoring => true,
              engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING
            }
          }
        end
      end
    end
    program = Program.find_by(root: 'p1')
    assert_false program.nil?
    other_users = program.users.all.last(2)
    assert_equal other_users.first.member, members(:anna_univ_admin)
    assert_equal other_users.last.member, members(:psg_only_admin)
    assert_equal_unordered program.admin_users.collect(&:id), other_users.collect(&:id)

    assert_redirected_to program_root_path(:root => 'p1')
    assert_equal "The Program has been successfully setup!", flash[:notice]
    assert_equal 'p1', assigns(:program).root
    assert_equal 'Department Of ComputerScience', assigns(:program).name
    assert_equal 'Some description', assigns(:program).description
    assert_equal Program::MentorRequestStyle::MENTEE_TO_ADMIN, assigns(:program).mentor_request_style
    assert assigns(:program).allow_one_to_many_mentoring?

    program = Program.find_by(root: 'p1')
    assert_false program.nil?
    user = User.all.last(2).first
    assert_equal program, user.program
    assert user.is_admin_only?
    assert_equal user, assigns(:current_user)
    assert_equal user, program.owner
  end

  def test_create_success_through_solution_pack_import
    current_user_is :foster_admin
    organization = programs(:org_foster)
    program = programs(:foster)
    organization.update_attribute(:can_update_root, false)
    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/solution_pack.zip'), mimeType)
    assert organization.standalone?

    assert_nothing_raised do
     assert_difference "organization.reload.programs.count" do
       params = {
         program: {
           name: "Test Program",
           engagement_type: Program::EngagementType::CAREER_BASED,
           enabled_features: ["calendar"],
           description: 'Some description',
           solution_pack_file: attached_file
         },
         creation_way: Program::CreationWay::SOLUTION_PACK,
       }
       post_with_calendar_check :create, params: params
     end
    end

    assert_redirected_to program_root_path(:root => 'p1')
    assert flash[:notice], "The solution pack was imported and the Program has been successfully setup!"
  end

  def test_create_success_with_missing_profile_question_id_in_admin_view_column_through_solution_pack_import
    current_user_is :foster_admin
    organization = programs(:org_foster)
    program = programs(:foster)
    organization.update_attribute(:can_update_root, false)
    assert organization.standalone?

    assert_nothing_raised do
     assert_difference "organization.reload.programs.count" do
       params = {
         program: {
           name: "Test Program",
           engagement_type: Program::EngagementType::CAREER_BASED,
           enabled_features: ["calendar"],
           description: 'Some description',
           solution_pack_file: fixture_file_upload('files/solution_pack_missing_profile_question.zip', "application/zip")
         },
         creation_way: Program::CreationWay::SOLUTION_PACK,
       }
       post_with_calendar_check :create, params: params
     end
    end

    assert_redirected_to program_root_path(:root => 'p1')
    assert flash[:notice], "The solution pack was imported and the Program has been successfully setup!"
  end

  def test_create_error_through_solution_pack_import
    current_member_is :foster_admin
    organization = programs(:org_foster)
    organization.update_attribute(:can_update_root, false)
    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/solution_pack.zip'), mimeType)
    assert organization.standalone?

    ProgramsController.any_instance.expects(:import_solution_pack).raises(->{StandardError.new("Some error")})

    assert_no_difference "organization.reload.programs.count" do
      params = {
        program: {
          name: "Test Program",
          engagement_type: Program::EngagementType::CAREER_BASED,
          enabled_features: ["calendar"],
          description: 'Some description',
          solution_pack_file: attached_file
        },
        creation_way: Program::CreationWay::SOLUTION_PACK,
      }
      post_with_calendar_check :create, params: params
    end
    assert_redirected_to new_program_path(root: nil)
    assert_equal "Failed to create the program using solution pack", flash[:error]
  end

  def test_create_success_with_invalid_surveys_present_in_mentoring_model_through_solution_pack_import
    current_user_is :foster_admin
    organization = programs(:org_foster)
    program = programs(:foster)
    organization.update_attribute(:can_update_root, false)
    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/solution_pack_invalid_engagement_survey.zip'), mimeType)
    assert organization.standalone?

    assert_nothing_raised do
     assert_difference "organization.reload.programs.count" do
       params = {
         program: {
           name: "Test Program",
           engagement_type: Program::EngagementType::CAREER_BASED,
           enabled_features: ["calendar"],
           description: 'Some description',
           solution_pack_file: attached_file
         },
         creation_way: Program::CreationWay::SOLUTION_PACK,
       }
       post_with_calendar_check :create, params: params
     end
    end

    assert_redirected_to program_root_path(root: 'p1')
    assert_nil flash[:notice]
    assert_equal "The solution pack was imported and the Program has been successfully setup! Please note that some invalid data in mentoring connection model was deleted", flash[:warning]
  end

  def test_new_from_organization
    current_member_is :f_admin

    get :new
    assert_response :success
    assert_template 'new'
    assert assigns(:program)
  end

  def test_manage_should_not_show_confidentiality_audit_icon_if_disabled
    current_user_is users(:f_admin)
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::OPEN
    programs(:albers).save!
    programs(:albers).reload
    get :manage
    assert_select 'div#manage' do
      assert_select 'div.ibox' do
        assert_no_select "a[href=\"/confidentiality_audit_logs\"]"
      end
    end
  end

  def test_show_set_availability
    members(:f_mentor).update_attributes!(will_set_availability_slots: true)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    users(:f_mentor).program.calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)
    current_user_is users(:f_mentor)
    get :show
    assert_response :success
    assert_select 'a', :text => "Upcoming"
  end

  def test_should_show_zendesk_support_for_admin_in_manage_page
    current_user_is users(:f_admin)
    get :manage
    assert_select 'div#manage' do
      assert_select 'div.ibox' do
        assert_select 'a[href=?]', zendesk_session_path(src: "manage")
      end
    end
  end

  def test_should_not_show_set_availability_if_feature_disabled
    current_user_is users(:f_mentor)
    get :show
    assert_response :success
    assert_select 'a[href=?]', member_url(members(:f_mentor), :tab => MembersController::ShowTabs::AVAILABILITY), :count => 0
  end

  def test_show_two_column_layout
    current_user_is :f_student

    get :show
    assert_response :success
    assert_select 'html' do
      assert_select 'div#wrapper' do
        assert_select 'nav#sidebarLeft'
        assert_select 'div#page-wrapper' do
          assert_select 'div#inner_content' do
            assert_select 'div#page_canvas' do
              assert_select 'div#program_home'
            end
          end
        end
      end
    end
  end

  def test_profile_incomplete_redirection
    user = users(:f_mentor)
    user.update_attribute :state, User::Status::PENDING
    assert user.reload.profile_pending?

    current_user_is user

    get :show

    assert_redirected_to edit_member_path(user.member,
      :first_visit => true,
      :landing_directly => true, ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING)
  end

  def test_management_report_redirection
    user = users(:f_admin)

    current_user_is user

    get :show

    assert_redirected_to management_report_path({:lst => ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS})
  end

   def test_management_report_redirection_with_params
    user = users(:f_admin)

    current_user_is user

    get :show, params: { error_raised: "1"}

    assert_redirected_to management_report_path({error_raised: "1", lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS})
  end

  def test_profile_incomplete_redirection_wob_scenario
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)
    user = users(:f_mentor)
    user.update_attribute :state, User::Status::PENDING
    assert user.reload.profile_pending?

    admin = users(:f_admin)
    @request.session[:work_on_behalf_user] = user.id
    @request.session[:work_on_behalf_member] = user.member_id

    current_member_is admin.member
    current_program_is :albers

    get :show

    assert_redirected_to edit_member_path(user.member,
      :first_visit => true,
      :landing_directly => true, ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING)
  end

  def test_update_mentor_offer_acceptance_when_offers_are_pending
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    create_mentor_offer
    assert program.mentor_offers.pending.any?
    assert program.mentor_offer_needs_acceptance?

    assert_false program.calendar_enabled?
    assert program.calendar_setting.destroy
    assert_false program.reload.calendar_setting.present?

    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, :program=>{enabled_features: [FeatureName::CALENDAR, FeatureName::OFFER_MENTORING], calendar_setting: {allow_mentor_to_configure_availability_slots: "1", allow_mentor_to_describe_meeting_preference: "1", slot_time_in_minutes: "30", allow_create_meeting_for_mentor: "true", :advance_booking_time => "1", max_pending_meeting_requests_for_mentee: "1", max_capacity_student_frequency: 10}, needs_meeting_request_reminder: "1", meeting_request_reminder_duration: "1", :meeting_request_auto_expiration_days =>"1", mentor_offer_needs_acceptance: "false"}}

    assert program.mentor_offer_needs_acceptance?
    assert_equal "A setting change related to mentor initiated offers acceptance failed as there are offers pending currently.", flash[:error]
  end

  def test_matching_setting
    admin = users(:f_admin)
    program = programs(:albers)
    current_member_is admin.member
    current_program_is :albers
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert_false program.calendar_enabled?
    assert program.calendar_setting.destroy
    assert_false program.reload.calendar_setting.present?
    program.users[0].update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    program.users[1].update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    assert program.users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).count > 0

    assert_difference 'CalendarSetting.count' do
      post :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, :program=>{enabled_features: [FeatureName::CALENDAR], calendar_setting: {allow_mentor_to_configure_availability_slots: "1", allow_mentor_to_describe_meeting_preference: "1", slot_time_in_minutes: "30", allow_create_meeting_for_mentor: "true", :advance_booking_time => "1", max_pending_meeting_requests_for_mentee: "1", max_capacity_student_frequency: 10}, needs_meeting_request_reminder: "1", meeting_request_reminder_duration: "1", :meeting_request_auto_expiration_days =>"1"}}
    end
    cal_setting = assigns(:calendar_setting)
    assert cal_setting.allow_mentor_to_configure_availability_slots
    assert cal_setting.allow_mentor_to_describe_meeting_preference
    assert_equal 30, cal_setting.slot_time_in_minutes
    assert_equal 0, program.users.where(mentoring_mode: [User::MentoringMode::ONGOING, User::MentoringMode::ONE_TIME]).count
    assert_equal program.users.count, program.users.where(mentoring_mode: [User::MentoringMode::ONE_TIME_AND_ONGOING]).count
    assert cal_setting.allow_create_meeting_for_mentor
    assert_equal 1, cal_setting.advance_booking_time
    assert_equal 1, cal_setting.max_pending_meeting_requests_for_mentee
    assert program.calendar_enabled?
    assert_false program.mentor_offer_enabled?
  end

  def test_matching_setting_calendar_details_invalid
    admin = users(:f_admin)
    program = programs(:albers)
    current_member_is admin.member
    current_program_is :albers
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert_false program.calendar_enabled?
    assert program.calendar_setting.destroy
    assert_false program.reload.calendar_setting.present?

    assert_no_difference 'CalendarSetting.count' do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, :program=>{enabled_features: [FeatureName::CALENDAR], calendar_setting: {allow_mentor_to_configure_availability_slots: "1", allow_mentor_to_describe_meeting_preference: "1", slot_time_in_minutes: "", allow_create_meeting_for_mentor: "true", :advance_booking_time => "1", max_pending_meeting_requests_for_mentee: "1", max_capacity_student_frequency: 10}, needs_meeting_request_reminder: "1", meeting_request_reminder_duration: "1", :meeting_request_auto_expiration_days =>"1"}}
    end
    assert assigns(:redirected_from_update)
    assert_false program.calendar_enabled?
    assert program.mentor_offer_enabled?
  end

  def test_matching_setting_calendar_details_invalid_with_mentor_offer
    admin = users(:f_admin)
    program = programs(:albers)
    current_member_is admin.member
    current_program_is :albers

    assert_false program.calendar_enabled?
    assert program.calendar_setting.destroy
    assert_false program.reload.calendar_setting.present?

    assert_no_difference 'CalendarSetting.count' do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, :program=>{enabled_features: [FeatureName::CALENDAR, FeatureName::OFFER_MENTORING], calendar_setting: {allow_mentor_to_configure_availability_slots: "1", allow_mentor_to_describe_meeting_preference: "1", slot_time_in_minutes: "", allow_create_meeting_for_mentor: "true", :advance_booking_time => "1", max_pending_meeting_requests_for_mentee: "1", max_capacity_student_frequency: 10}, needs_meeting_request_reminder: "1", meeting_request_reminder_duration: "1", :meeting_request_auto_expiration_days =>"100", mentor_request_style: Program::MentorRequestStyle::NONE}}
    end
    assert_false program.calendar_enabled?
    assert_false program.mentor_offer_enabled?
    assert_equal "Configure calendar slot duration can't be blank and Configure calendar slot duration is not included in the list", assigns(:calendar_setting).errors.full_messages.to_sentence
    assert_not_equal 100, program.meeting_request_auto_expiration_days
    assert_equal program.mentor_request_style.to_i, Program::MentorRequestStyle::MENTEE_TO_MENTOR
  end

  def test_matching_setting_with_mentor_offer
    admin = users(:f_admin)
    program = programs(:albers)
    current_member_is admin.member
    current_program_is :albers

    assert_false program.calendar_enabled?
    assert program.calendar_setting.destroy
    assert_false program.reload.calendar_setting.present?
    assert_false program.mentor_offer_enabled?

    assert_no_difference 'CalendarSetting.count' do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: { enabled_features: [FeatureName::OFFER_MENTORING], needs_meeting_request_reminder: "1", meeting_request_reminder_duration: "1", :meeting_request_auto_expiration_days =>"1" }}
    end
    assert_false program.reload.calendar_enabled?
    assert program.mentor_offer_enabled?
  end

  def test_mentoring_offer_needs_acceptance_as_non_super_user
    current_user_is users(:f_student)
    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :update, params: {
        :program => {
        :mentor_offer_needs_acceptance => false
      }}
    end
  end

  def test_hybrid_templates_enabled_as_non_super_user
    current_user_is users(:f_student)
    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :update, params: {
        :program => {
        :hybrid_templates_enabled => true
      }}
    end
  end

  def test_number_of_licenses_as_non_super_user
    current_user_is users(:f_student)
    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :update, params: {
        :program => {
        :number_of_licenses => false
      }}
    end
  end

  def test_super_user_can_update_number_of_licenses
    program = programs(:albers)
    assert_nil program.number_of_licenses

    current_user_is users(:f_admin)
    login_as_super_user

    assert_nothing_raised do
      post_with_calendar_check :update, params: { "program"=>{"number_of_licenses" => "222"}}
    end
    assert_equal 222, program.reload.number_of_licenses
  end

  def test_activity_log_should_log_for_student
    current_program_is :albers

    current_user_is users(:f_student)

    assert_difference 'ActivityLog.count' do
      get :show
      assert_response :success
    end
  end

  def test_activity_log_should_log_for_mentor
    current_program_is :albers

    current_user_is users(:f_mentor)

    assert_difference 'ActivityLog.count' do
      get :show
      assert_response :success
    end
  end

  def test_activity_log_should_log_for_mentor_and_student
    current_program_is :albers

    current_user_is users(:f_mentor_student)

    assert_difference 'ActivityLog.count' do
      get :show
      assert_response :success
    end
  end

  def test_activity_log_should_not_log_for_wob_as_admin
    user = users(:f_mentor)
    current_user_is user
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)

    admin = users(:f_admin)
    @request.session[:work_on_behalf_user] = user.id
    @request.session[:work_on_behalf_member] = user.member_id

    current_member_is admin.member
    current_program_is :albers

    assert_no_difference 'ActivityLog.count' do
      get :show
      assert_response :success
    end

  end


  def test_activity_log_should_not_log_for_not_loggedin_user
    current_program_is :albers

    assert_no_difference 'ActivityLog.count' do
      get :show
      assert_redirected_to about_path()
    end
  end

  def test_activity_log_should_not_log_for_permission_denied
    current_user_is :f_mentor
    current_program_is :albers

    assert_no_difference 'ActivityLog.count' do
      assert_permission_denied do
        get :edit
      end
    end
  end

  def test_super_user_should_see_logo_banner_in_edit_program_page
    current_user_is :f_admin
    login_as_super_user

    get :edit
    assert_response :success
    assert_select("input#program_logo[type=file]")
    assert_select("input#banner[type=file]")
  end

  def test_non_super_user_should_not_see_banner_in_edit_program_page
    current_user_is :f_admin

    get :edit
    assert_response :success
    assert_select("input#program_logo[type=file]")
    assert_no_select("input#program_banner[type=file]")
  end

  def test_mobile_logo_in_edit_program_page_for_non_standalone_program
    # Non-Standalone Program
    current_user_is :f_admin
    get :edit
    assert_response :success
    assert_no_select("input#program_mobile_logo[type=file]")

    # Non-Standalone Program With Superuser Permission
    login_as_super_user
    get :edit
    assert_response :success
    assert_no_select("input#program_mobile_logo[type=file]")
  end

  def test_mobile_logo_in_edit_program_page_for_standalone_program
    # Non-Standalone Program Without Superuser Permission
    current_user_is :foster_admin
    get :edit
    assert_response :success
    assert_no_select("input#program_mobile_logo[type=file]")
    assert_no_select("input#program_organization_mobile_logo[type=file]")

    login_as_super_user
    get :edit
    assert_response :success
    assert_no_select("input#program_mobile_logo[type=file]")
    assert_select("input#program_organization_mobile_logo[type=file]")
  end

  def test_update_banner_logo_standalone
    program = programs(:foster)
    current_user_is :foster_admin
    login_as_super_user
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::LOGO, program.organization.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "logo").returns(fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::BANNER, program.organization.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "banner").returns(fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png'))
    organization = programs(:org_foster)

    post :update, params: { "program" => { "organization"=> {"logo"=> { file_name: "logo", code: "xyz" }, "banner"=> { file_name: "banner", code: "xyz" } } }}
    program_asset = organization.program_asset

    assert_match /test_pic\.png/, program_asset.logo.url
    assert_match /pic_2\.png/, program_asset.banner.url

    post :update, params: { "program" => { "organization"=> {"logo"=> { file_name: "test_pic.png" }, "banner"=> { file_name: "pic_2.png" } }}}

    assert_match /test_pic\.png/, program_asset.reload.logo.url
    assert_match /pic_2\.png/, program_asset.banner.url

    post :update, params: { "program" => { "organization"=> {"logo"=> { file_name: "" }, "banner"=> { file_name: "" } }}}

    assert_false program_asset.reload.logo.present?
    assert_false program_asset.banner.present?
  end

  def test_update_banner_logo
    program = programs(:albers)
    current_user_is :f_admin
    login_as_super_user
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::LOGO, program.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "logo").returns(fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::BANNER, program.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "banner").returns(fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png'))

    post :update, params: { "program" => {"logo"=> { file_name: "logo", code: "xyz" }, "banner"=> { file_name: "banner", code: "xyz" } } }

    assert_match /test_pic\.png/, program.reload.logo.url
    assert_match /pic_2\.png/, program.banner.url

    post :update, params: { "program" => {"logo"=> { file_name: "test_pic.png" }, "banner"=> { file_name: "pic_2.png" } }}

    assert_match /test_pic\.png/, program.reload.logo.url
    assert_match /pic_2\.png/, program.banner.url

    post :update, params: { "program" => {"logo"=> { file_name: "" }, "banner"=> { file_name: "" } }}

    assert_nil program.reload.logo_url
    assert_nil program.banner_url
  end



  def test_update_mobile_logo_for_program
    organization = programs(:org_foster)
    program = programs(:foster)
    current_user_is :foster_admin
    login_as_super_user
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::MOBILE_LOGO, organization.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "mobile_logo").returns(fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))

    post :update, params: { "program"=>{"organization"=>{"mobile_logo"=> { file_name: "mobile_logo", code: "xyz" }}}}
    assert_nil program.reload.program_asset
    assert_match /test_pic\.png/, organization.reload.program_asset.mobile_logo.url
  end

  def test_update_mobile_logo_removal
    program = programs(:foster)
    organization = programs(:org_foster)
    current_user_is :foster_admin
    login_as_super_user
    ProgramAsset.create!(program_id: programs(:org_foster).id, mobile_logo: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert_match /test_pic\.png/, program.mobile_logo_url
    assert_match /test_pic\.png/, organization.mobile_logo_url

    post :update, params: { "program"=>{"organization"=>{"mobile_logo"=> { file_name: "", code: "" }}}}

    assert_nil program.reload.mobile_logo_url
    assert_nil organization.reload.mobile_logo_url
  end

  def test_quick_connect_box_does_not_show_for_connected_mentee
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:mkr_student)
    programs(:albers).update_attribute(:max_connections_for_mentee, 1)
    users(:mkr_student).update_attribute(:created_at, 1.week.ago)

    assert users(:mkr_student).recently_joined?
    assert users(:mkr_student).groups.any?

    get :show
    assert_response :success
    assert_false assigns(:render_quick_connect_box)
  end

  def test_quick_connect_box_student_with_calendar_feature_turned_on
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:f_student)

    get :show
    assert_response :success

    assert assigns(:render_quick_connect_box)
    assert_select "html" do
      assert_select "div.cjs_quick_connect_box"
    end
  end

  def test_quick_connect_box_does_not_show_if_cannot_view_mentors
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:f_student)
    fetch_role(:albers, :student).remove_permission("view_mentors")

    get :show
    assert_response :success
    assert_false assigns(:render_quick_connect_box)
  end

  def test_quick_connect_box_student_with_calendar_feature_turned_off_and_can_send_mentor_request
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, false)
    current_user_is users(:f_student)
    assert users(:f_student).program.matching_by_mentee_alone?
    assert users(:f_student).can_send_mentor_request?

    get :show
    assert_response :success

    assert assigns(:render_quick_connect_box)
    assert_select "html" do
      assert_select "div.cjs_quick_connect_box"
    end
  end

  def test_quick_connect_box_student_with_calendar_feature_turned_off_and_can_send_mentor_request_and_ongoing_mentoring_disabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, false)
    # disabling ongoing mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    current_user_is users(:f_student)
    assert users(:f_student).program.matching_by_mentee_alone?
    assert users(:f_student).can_send_mentor_request?

    get :show
    assert_response :success

    assert_false assigns(:render_quick_connect_box)
  end

  def test_quick_connect_box_with_recently_connected_meetings
    current_time = Time.now.utc.beginning_of_day
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    programs(:albers).update_attribute(:max_connections_for_mentee, 1)
    current_user_is users(:mkr_student)
    member = members(:mkr_student)
    meeting = member.meetings.first
    update_recurring_meeting_start_end_date(meeting, (current_time - 1.day), ((current_time - 1.day) + 1.hour), {duration: 1.hour})

    get :show
    assert_response :success

    assert_false assigns(:render_quick_connect_box)
  end

  def test_quick_connect_box_calendar_disabled
    current_user_is :mkr_student
    current_time = Time.now.utc.beginning_of_day
    User.any_instance.stubs(:connection_limit_as_mentee_reached?).returns(true)

    assert_permission_denied do
      get :quick_connect_box, xhr: true
    end
  end

  def test_quick_connect_box_not_connected_past_10_days
    current_user_is :mkr_student

    current_time = Time.now.utc.beginning_of_day
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    member = members(:mkr_student)
    member.expects(:not_connected_for?).at_least(0).returns(false)
    User.any_instance.expects(:can_send_mentor_request?).at_least(0).returns(false)

    assert_permission_denied do
      get :quick_connect_box, xhr: true, params: { format: :js}
    end
  end

  def test_quick_connect_box_already_connected_in_long_term_mentoring
    current_user_is :mkr_student

    current_time = Time.now.utc.beginning_of_day
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, true)
    member = members(:mkr_student)
    meeting = member.meetings.first
    update_recurring_meeting_start_end_date(meeting, (current_time - 1.day), ((current_time - 1.day) + 1.hour), {duration: 1.hour})
    groups(:mygroup).terminate!(users(:f_admin), "Sample Reasoin", groups(:mygroup).program.permitted_closure_reasons.first.id)
    User.any_instance.expects(:can_send_mentor_request?).at_least(0).returns(false)

    assert_permission_denied do
      get :quick_connect_box, xhr: true, params: { format: :js}
    end
  end

  def test_quick_connect_box_upcoming_meetings
    current_user_is :mkr_student

    current_time = Time.now.utc.beginning_of_day
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, true)
    member = members(:mkr_student)
    meeting = member.meetings.first
    update_recurring_meeting_start_end_date(meeting, (current_time + 2.days), (current_time + 2.days + 1.hour), {duration: 1.hour})
    User.any_instance.expects(:can_send_mentor_request?).at_least(0).returns(false)

    assert_permission_denied do
      get :quick_connect_box, xhr: true, params: { format: :js}
    end
  end

  def test_quick_connect_box_when_no_mentors_available_for_meeting
    expected_mentors = [users(:mentor_0), users(:mentor_2), users(:mentor_3)]
    User.where(id: expected_mentors.map(&:id)).update_all(max_connections_limit: 1000)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    User.any_instance.stubs(:generate_mentor_suggest_hash).returns([])
    current_user_is :mkr_student
    get :quick_connect_box, xhr: true, params: { format: :js }
    assert_response :success
    expected_mentors.each { |mentor| assert_equal 90, assigns(:mentors_score)[mentor.id] }
    assert_equal_unordered expected_mentors.collect(&:member_id), assigns(:mentors_list).map { |m| m[:member].id }
    assert assigns(:show_favorite_ignore_links)
    assert_equal_hash({}, assigns(:favorite_preferences_hash))
    assert_equal_hash({}, assigns(:ignore_preferences_hash))
  end

  def test_quick_connect_box_when_general_availability
    user = users(:mkr_student)
    program = user.program
    program.enable_feature(FeatureName::CALENDAR, true)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.calendar_setting.update_attributes!(allow_mentor_to_describe_meeting_preference: true, allow_mentor_to_configure_availability_slots: false)

    expected_mentors = [users(:mentor_0), users(:mentor_2), users(:mentor_3)]
    expected_mentors.each { |mentor| mentor.profile_views.create!(viewed_by: user) }

    current_user_is user
    get :quick_connect_box, xhr: true, params: { format: :js }
    assert_response :success
    assert_equal_unordered expected_mentors.map(&:member_id), assigns(:mentors_list).map { |m| m[:member].id }
    assert assigns(:show_favorite_ignore_links)
    assert_false assigns(:get_system_recommendations)
    assert_equal_hash({}, assigns(:favorite_preferences_hash))
    assert_equal_hash({}, assigns(:ignore_preferences_hash))
  end

  def test_quick_connect_box_permission_denied_for_explicit_preference_recommendations
    user = users(:mkr_student)
    program = user.program
    program.enable_feature(FeatureName::CALENDAR, true)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.calendar_setting.update_attributes!(allow_mentor_to_describe_meeting_preference: true, allow_mentor_to_configure_availability_slots: false)
    current_user_is user
    assert_permission_denied do
      get :quick_connect_box, xhr: true, params: {format: :js,only_explicit_preference_recommendations: true}
    end
  end

  def test_quick_connect_box_for_explicit_preference_recommendations
    user = users(:mkr_student)
    program = user.program
    program.enable_feature(FeatureName::CALENDAR, true)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.calendar_setting.update_attributes!(allow_mentor_to_describe_meeting_preference: true, allow_mentor_to_configure_availability_slots: false)
    expected_mentors = [users(:mentor_0), users(:mentor_2), users(:mentor_3)]
    expected_mentors.each { |mentor| mentor.profile_views.create!(viewed_by: user) }

    current_user_is user
    User.any_instance.stubs(:explicit_preferences_configured?).returns(true)
    MentorRecommendationsService.any_instance.stubs(:get_explicit_preferences_recommended_user_ids).returns([users(:mentor_0).id, users(:mentor_2).id])
    get :quick_connect_box, xhr: true, params: {format: :js, only_explicit_preference_recommendations: true}
    assert_response :success
    assert_equal_unordered [users(:mentor_0), users(:mentor_2)].map(&:member_id), assigns(:mentors_list).map { |m| m[:member].id }
  end

  def test_quick_connect_box_when_mentoring_slots
    user = users(:mkr_student)
    program = user.program
    organization = program.organization
    current_time = Time.current.beginning_of_day

    program.enable_feature(FeatureName::CALENDAR)
    organization.members.update_all(will_set_availability_slots: true)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.calendar_setting.update_attributes!(allow_mentor_to_describe_meeting_preference: false, allow_mentor_to_configure_availability_slots: true)

    expected_mentors = [users(:mentor_2), users(:mentor_0), users(:mentor_3)]
    expected_mentors.each_with_index do |mentor, i|
      mentor.member.mentoring_slots.create!(start_time: current_time + 2.days + i.hours, end_time: current_time + 2.days + (i + 1).hours, repeats: MentoringSlot::Repeats::NONE)
    end

    current_user_is user
    get :quick_connect_box, xhr: true, params: { format: :js }
    assert_response :success
    assert_equal_unordered expected_mentors.map(&:member_id), assigns(:mentors_list).map { |m| m[:member].id }
  end

  def test_quick_connect_box_when_no_mentors_available_for_connection_and_distant_mentoring_slots
    user = users(:mkr_student)
    program = user.program
    organization = program.organization
    current_time = Time.current.beginning_of_day

    program.enable_feature(FeatureName::CALENDAR)
    organization.members.update_all(will_set_availability_slots: true)
    program.update_attributes(allow_mentoring_mode_change: Program::MENTORING_MODE_CONFIG::EDITABLE, allow_mentoring_requests: false)
    program.calendar_setting.update_attributes!(allow_mentor_to_describe_meeting_preference: false, allow_mentor_to_configure_availability_slots: true)

    [users(:mentor_2), users(:mentor_0), users(:mentor_3)].each_with_index do |mentor, i|
      mentor.member.mentoring_slots.create!(start_time: current_time + 4.months + i.hours, end_time: current_time + 4.months + (i + 1).hours, repeats: MentoringSlot::Repeats::NONE)
    end

    current_user_is user
    get :quick_connect_box, xhr: true, params: { format: :js }
    assert_response :success
    assert_equal 90, assigns(:mentors_score)[users(:f_mentor).id]
    assert_empty assigns(:mentors_list)
  end

  def test_quick_connect_box_calendar_disabled_and_user_can_send_mentor_request
    user = users(:f_student)
    assert user.program.matching_by_mentee_alone?
    assert user.can_send_mentor_request?

    current_user_is user
    get :quick_connect_box, xhr: true, params: { format: :js }
    assert_response :success
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, assigns(:favorite_preferences_hash))
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:ignore_1).id, users(:ram).id=>abstract_preferences(:ignore_3).id}, assigns(:ignore_preferences_hash))
  end

  def test_quick_connect_box_calendar_disabled_and_user_cannot_send_mentor_request
    user = users(:mkr_student)
    user.program.organization.enable_feature(FeatureName::CALENDAR, false)

    User.any_instance.expects(:can_send_mentor_request?).at_least(0).returns(false)
    current_user_is user
    assert_permission_denied do
      get :quick_connect_box, xhr: true, params: { format: :js}
    end
  end

  def test_quick_connect_box_success_without_available_mentors_and_with_mentors_for_connection
    user = users(:f_student)
    user.program.organization.enable_feature(FeatureName::CALENDAR, false)
    set_mentor_cache(user.id, users(:mentor_0).id, 0.9)
    set_mentor_cache(user.id, users(:mentor_2).id, 0.8)
    set_mentor_cache(user.id, users(:mentor_3).id, 0.7)

    current_user_is user
    get :quick_connect_box, xhr: true, params: { format: :js}
    assert_response :success
    assert_equal [members(:mentor_0), members(:mentor_2), members(:mentor_3)].map(&:id), assigns(:mentors_list).map { |m| m[:member].id }
  end

  def test_quick_connect_box_success_with_available_mentors_and_without_mentors_for_connection
    mentors_hash = {}
    mentors_hash[:member] = members(:f_admin)
    mentors_hash[:user] = users(:f_admin)
    mentors_hash[:max_score] = 90.0
    mentors_hash[:recommendation_score] = 7.0
    mentors_hash[:recommended_for] = MentorRecommendationsService::RecommendationsFor::ONGOING

    MentorRecommendationsService.any_instance.stubs(:get_recommendations).once.returns([mentors_hash])
    current_user_is :mkr_student
    get :quick_connect_box, xhr: true, params: { format: :js }
    assert_response :success
    assert_equal [mentors_hash], assigns(:mentors_list)
  end

  def test_quick_connect_box_items_count
    MentorRecommendationsService.any_instance.expects(:get_recommendations).once
    current_user_is :f_student
    get :quick_connect_box, xhr: true, params: { format: :js}
  end

  def test_quick_connect_box_meeting_availability
    user = users(:f_student)
    user.program.enable_feature(FeatureName::CALENDAR, false)

    current_user_is user
    get :quick_connect_box, xhr: true, params: { format: :js }
    assert_response :success
    assert_false assigns(:show_meeting_availability)
  end

  def test_quick_connect_box_meeting_availability_for_flash_only_program
    user = users(:f_student)
    user.program.enable_feature(FeatureName::CALENDAR)

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    current_user_is user
    get :quick_connect_box, xhr: true, params: { format: :js}
    assert_response :success
    assert assigns(:show_meeting_availability)
  end

  def test_notify_availability_based_on_mentoring_mode
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    CalendarSetting.any_instance.stubs(:allow_mentor_to_configure_availability_slots?).returns(true)
    Member.any_instance.stubs(:will_set_availability_slots?).returns(true)
    User.any_instance.stubs(:can_set_availability?).returns(true)
    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(false)

    user = users(:f_mentor)
    member = user.member
    current_user_is user
    assert_equal 1, member.mentoring_slots.size
    slot_start_time = Time.now - 2.days
    slot = member.mentoring_slots.first
    slot.update_attributes!(start_time: slot_start_time, end_time: slot_start_time + 1.hour)

    get :show
    assert_response :success
    assert_false assigns(:notify_availability)
    assert_no_select "div#program_home", text: /Set your availability/
  end

  def test_notify_availability_for_mentor_success
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    CalendarSetting.any_instance.stubs(:allow_mentor_to_configure_availability_slots?).returns(true)
    Member.any_instance.stubs(:will_set_availability_slots?).returns(true)
    User.any_instance.stubs(:can_set_availability?).returns(true)
    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(true)

    user = users(:f_mentor)
    member = user.member
    current_user_is user
    assert_equal 1, member.mentoring_slots.size
    slot_start_time = Time.now - 2.days
    slot = member.mentoring_slots.first
    slot.update_attributes!(start_time: slot_start_time, end_time: slot_start_time + 1.hour)

    get :show
    assert_response :success
    assert assigns(:notify_availability)
    assert_select "div#program_home", text: /Set your availability/
  end

  def test_notify_availability_for_mentor_with_slots_in_the_next_week
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    invalidate_albers_calendar_meetings
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    CalendarSetting.any_instance.stubs(:allow_mentor_to_configure_availability_slots?).returns(true)
    Member.any_instance.stubs(:will_set_availability_slots?).returns(true)
    User.any_instance.stubs(:can_set_availability?).returns(true)
    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(true)

    users(:f_mentor).user_setting.update_attributes(:max_meeting_slots => 2)
    users(:f_mentor).reload

    user = users(:f_mentor)
    member = user.member
    current_user_is user
    assert_equal 1, member.mentoring_slots.size
    slot_start_time = Time.now + 2.days
    slot = member.mentoring_slots.first
    slot.update_attributes!(start_time: slot_start_time, end_time: slot_start_time + 1.hour)

    get :show
    assert_response :success
    assert_false assigns(:notify_availability)
    assert_no_select "div#program_home", text: /Set your availability/
  end

  def test_features_dependencies_with_mentoring_connections_v2
    current_user_is users(:f_admin)
    login_as_super_user

    program = programs(:albers)
    Program.any_instance.stubs(:can_have_match_report?).returns(false)
    assert_false program.has_feature?(FeatureName::MENTORING_CONNECTIONS_V2)

    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::FEATURES, "program"=>{"organization"=>{"enabled_features"=>["", "mentoring_connections_v2", "manager"]}}, :features_tab=>"true"}

    program.reload
    assert program.has_feature?(FeatureName::MENTORING_CONNECTIONS_V2)
    assert program.has_feature?(FeatureName::MENTORING_CONNECTION_MEETING)
  end

  def test_non_super_user_cannot_update_default_notif_settings
    p = programs(:albers)
    assert_equal p.notification_setting.messages_notification, UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    current_user_is users(:f_admin)

    assert_raise Authorization::PermissionDenied do
      post_with_calendar_check :update, params: { "program"=>{"notification_setting"=>{"messages_notification"=>"1"}}}
    end
  end

  def test_super_user_can_update_default_notif_settings
    p = programs(:albers)
    assert_equal p.notification_setting.messages_notification, UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    assert_equal 1, p.manager_matching_level
    assert_false p.prevent_manager_matching

    current_user_is users(:f_admin)
    login_as_super_user

    assert_nothing_raised do
      post_with_calendar_check :update, params: { "program"=>{"notification_setting"=>{"messages_notification"=>"1"}, "prevent_manager_matching" => "true", "manager_matching_level" => "4"}, :tab => ProgramsController::SettingsTabs::MATCHING}
    end
    assert_equal p.reload.notification_setting.messages_notification, UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    assert_equal 4, p.manager_matching_level
    assert p.prevent_manager_matching
  end

  def test_remove_propose_groups_permsssion
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = program.roles.find_by(name: 'teacher')
    for_mentoring_roles = program.roles.for_mentoring.index_by(&:name)
    for_mentoring_roles.values.select{|role| RoleConstants::DEFAULT_ROLE_NAMES.include?(role.name) }.each do |role|
      role.add_permission(RolePermission::PROPOSE_GROUPS)
    end
    assert for_mentoring_roles[RoleConstants::MENTOR_NAME].has_permission_name? "propose_groups"
    assert for_mentoring_roles[RoleConstants::STUDENT_NAME].has_permission_name? "propose_groups"
    assert_false for_mentoring_roles["teacher"].has_permission_name? "propose_groups"

    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::MATCHING, :program => {
      role: {
        mentor_role.id => { role_attributes: "" },
        student_role.id => { role_attributes: "" },
        teacher_role.id => { role_attributes: "" }
      }
    }}

    assert_false for_mentoring_roles[RoleConstants::MENTOR_NAME].reload.has_permission_name? "propose_groups"
    assert_false for_mentoring_roles[RoleConstants::STUDENT_NAME].reload.has_permission_name? "propose_groups"
    assert_false for_mentoring_roles["teacher"].reload.has_permission_name? "propose_groups"

    # calendar setting instance variable won't be initialzed for project based program
    calendar_setting = program.calendar_setting
    assert_not_equal calendar_setting, assigns(:calendar_setting)
    assert_nil assigns(:calendar_setting)
  end

  def test_add_remove_propose_groups_permsssion
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = program.roles.find_by(name: 'teacher')
    for_mentoring_roles = program.roles.for_mentoring.index_by(&:name)
    for_mentoring_roles.values.select{|role| RoleConstants::DEFAULT_ROLE_NAMES.include?(role.name) }.each do |role|
      role.add_permission(RolePermission::PROPOSE_GROUPS)
    end
    assert for_mentoring_roles[RoleConstants::MENTOR_NAME].has_permission_name? "propose_groups"
    assert for_mentoring_roles[RoleConstants::STUDENT_NAME].has_permission_name? "propose_groups"
    assert_false for_mentoring_roles["teacher"].has_permission_name? "propose_groups"

    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::MATCHING, :program => {
      send_group_proposals: [for_mentoring_roles[RoleConstants::MENTOR_NAME], for_mentoring_roles["teacher"]].collect(&:id).collect(&:to_s),
      role: {
        mentor_role.id => { role_attributes: "" },
        student_role.id => { role_attributes: "" },
        teacher_role.id => { role_attributes: "" }
      }
    }}

    assert for_mentoring_roles[RoleConstants::MENTOR_NAME].reload.has_permission_name? "propose_groups"
    assert_false for_mentoring_roles[RoleConstants::STUDENT_NAME].reload.has_permission_name? "propose_groups"
    assert for_mentoring_roles["teacher"].reload.has_permission_name? "propose_groups"
  end

  def test_add_all_propose_groups_permsssion
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = program.roles.find_by(name: 'teacher')
    for_mentoring_roles = program.roles.for_mentoring.index_by(&:name)
    assert_false for_mentoring_roles[RoleConstants::MENTOR_NAME].has_permission_name? "propose_groups"
    assert_false for_mentoring_roles[RoleConstants::STUDENT_NAME].has_permission_name? "propose_groups"
    assert_false for_mentoring_roles["teacher"].has_permission_name? "propose_groups"

    post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::MATCHING, :program => {
      send_group_proposals: for_mentoring_roles.values.collect(&:id).collect(&:to_s),
      role: {
        mentor_role.id => { role_attributes: "" },
        student_role.id => { role_attributes: "" },
        teacher_role.id => { role_attributes: "" }
      }
    }}

    assert for_mentoring_roles[RoleConstants::MENTOR_NAME].reload.has_permission_name? "propose_groups"
    assert for_mentoring_roles[RoleConstants::STUDENT_NAME].reload.has_permission_name? "propose_groups"
    assert for_mentoring_roles["teacher"].reload.has_permission_name? "propose_groups"
  end

  def test_should_not_update_permissions_for_other_tabs
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    join_settings = {RoleConstants::MENTOR_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE],
                     RoleConstants::STUDENT_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE]}

    for_mentoring_roles = program.roles.for_mentoring.index_by(&:name)
    for_mentoring_roles.values.select{|role| RoleConstants::DEFAULT_ROLE_NAMES.include?(role.name) }.each do |role|
      role.add_permission(RolePermission::PROPOSE_GROUPS)
    end

    assert for_mentoring_roles[RoleConstants::MENTOR_NAME].has_permission_name? "propose_groups"
    assert for_mentoring_roles[RoleConstants::STUDENT_NAME].has_permission_name? "propose_groups"
    assert_false for_mentoring_roles["teacher"].has_permission_name? "propose_groups"

    post_with_calendar_check :update, params: { :program => {
      :join_settings => join_settings, send_group_proposals: for_mentoring_roles.values.collect(&:id).collect(&:to_s)
    }, :tab => ProgramsController::SettingsTabs::MEMBERSHIP}

    assert for_mentoring_roles[RoleConstants::MENTOR_NAME].reload.has_permission_name? "propose_groups"
    assert for_mentoring_roles[RoleConstants::STUDENT_NAME].reload.has_permission_name? "propose_groups"
    assert_false for_mentoring_roles["teacher"].reload.has_permission_name? "propose_groups"
  end

  def test_update_role_descrption
    current_user_is :f_admin
    program = programs(:albers)
    role_description = {RoleConstants::MENTOR_NAME => "Mentor Role Description"}
    post_with_calendar_check :update, params: { :program => {
      :role_description => role_description
    }, :tab => ProgramsController::SettingsTabs::MEMBERSHIP}

    mentor = program.roles.where(:name => RoleConstants::MENTOR_NAME).first
    assert_equal "Mentor Role Description", mentor.description
  end

  def test_system_recommendation_should_show_on_no_user_recommendation
    admin = users(:f_admin)
    student = users(:f_student)
    program = programs(:albers)
    current_user_is student
    get :show
    assert_select ".system_recommendations", 1
  end

  def test_system_recommendation_should_not_show_on_user_recommendation
    admin = users(:f_admin)
    student = users(:f_student)
    program = programs(:albers)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    abstract_preferences(:ignore_3).destroy

    recommendation = create_mentor_recommendation(admin, student, program)
    p1 = recommendation.recommendation_preferences.new
    p1.position = 1
    p1.preferred_user = users(:ram)
    p1.save!

    current_user_is student

    get :show
    assert_select ".system_recommendations", 0
  end

  def test_working_on_behalf_of_user_not_part_of_program
    program = programs(:nwen)
    member = members(:student_0)
    assert_false member.user_in_program(program).present?

    current_member_is :f_admin
    current_program_is program
    @request.session[:work_on_behalf_member] = member.id
    @request.session[:work_on_behalf_user] = nil
    get :show
    assert_redirected_to about_path
    assert_nil assigns(:current_user)
    assert_equal members(:f_admin), assigns(:current_member)
  end

  def test_enable_admin_can_access_mentoring_area
    current_user_is users(:f_admin)
    ## Not allowed unless the user in super user
    assert_permission_denied do
      post_with_calendar_check :update, params: { :permissions_tab => "true", :id => programs(:albers).id, :tab => ProgramsController::SettingsTabs::PERMISSIONS, :program => {
        :admin_access_to_mentoring_area => Program::AdminAccessToMentoringArea::AUDITED_ACCESS}}
    end
    ## Post is successfully executed only if the super user is logged in.
    login_as_super_user
    post_with_calendar_check :update, params: { :permissions_tab => "true", :id => programs(:albers).id, :tab => ProgramsController::SettingsTabs::PERMISSIONS, :program => {
      :admin_access_to_mentoring_area => Program::AdminAccessToMentoringArea::AUDITED_ACCESS}}
    programs(:albers).reload
    assert_not_equal programs(:albers).admin_access_to_mentoring_area, Program::AdminAccessToMentoringArea::OPEN
    assert_equal programs(:albers).admin_access_to_mentoring_area, Program::AdminAccessToMentoringArea::AUDITED_ACCESS
  end

  def test_recommendation_box_for_matching_by_mentee_and_admin
    setup_for_recommendations
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    get :show
    assert_response :success
    assert_select "div.admin_recommendations", count: 1
  end

  def test_recommendation_box_for_matching_by_mentee_and_admin_with_preference
    setup_for_recommendations
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(true)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    get :show
    assert_response :success
    assert_select "div.admin_recommendations", count: 1
  end

  def test_recommendation_box_invisible_for_matching_by_admin
    setup_for_recommendations
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_admin_alone?).returns(true)
    get :show
    assert_response :success
    assert_select "div.admin_recommendations", count: 0
  end

  def test_recommendation_box_invisible_for_no_recommendation
    current_user_is :f_student
    current_program_is :albers
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    get :show
    assert_response :success
    assert_select "div.admin_recommendations", count: 0
  end

  def test_recommendation_box_invisible_for_no_recommendation_preference
    program = programs(:albers)
    current_user_is users(:f_student)
    current_program_is program
    admin = users(:f_admin)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)

    #creating recommendation
    m = MentorRecommendation.new
    m.program = program
    m.sender = admin
    m.receiver = users(:f_student)
    m.status = MentorRecommendation::Status::PUBLISHED
    m.save!

    get :show
    assert_response :success
    assert_select "div.admin_recommendations", count: 0
  end

  def test_no_change_for_calendar_setting
    program = programs(:albers)
    current_program_is :albers
    current_user_is users(:f_admin)
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)

    assert program.has_feature?(FeatureName::CALENDAR)
    login_as_super_user

    assert_nothing_raised do
      post_with_calendar_check :update, params: { :tab => ProgramsController::SettingsTabs::FEATURES, "program"=>{"organization"=>{"enabled_features"=>["", "articles", "answers", "subprogram_creation"]}}, :features_tab=>"true"}
    end
    assert program.has_feature?(FeatureName::CALENDAR)
  end

  def test_export_to_solution_pack
    program = programs(:albers)
    current_program_is :albers
    current_user_is users(:f_admin)

    login_as_super_user

    get :export_solution_pack, params: { :solution_pack => {:created_by => "xyz", description: "abc"}}

    exported_role_ids = []
    assert assigns(:solution_pack).attachment
  end

  def test_export_to_solution_pack_for_portal
    program = programs(:primary_portal)
    current_program_is :primary_portal
    current_user_is users(:portal_admin)

    login_as_super_user

    assert_difference 'SolutionPack.count' do
      get :export_solution_pack, params: { :solution_pack => {:created_by => "xyz", description: "abc"}}
    end

    assert assigns(:solution_pack).attachment
  end

  def test_manage_portal
    #if organization is standalone
    org = programs(:org_foster)
    program = programs(:foster)


    current_member_is members(:foster_admin)
    current_user_is users(:foster_admin)
    current_organization_is org

    get :manage
    assert_response :success
    assert_false assigns(:can_create_portal)
    login_as_super_user
    get :manage
    assert_response :success
    assert_false assigns(:can_create_portal)
    logout_as_super_user
    enable_career_development_feature(org)

    get :manage
    assert_response :success
    assert_false assigns(:can_create_portal)
    login_as_super_user
    get :manage
    assert_response :success
    assert assigns(:can_create_portal)

    portal = create_career_dev_portal(:organization => org)
    get :manage
    assert_response :success
    assert_false assigns(:can_create_portal)

    logout_as_super_user
    get :manage
    assert_response :success
    assert_false assigns(:can_create_portal)
  end

  def test_home_page_widget_failure_login
    current_program_is :pbe

    get :home_page_widget, xhr: true
    assert_response :unauthorized
  end

  def test_home_page_widget_failure_non_pbe
    current_user_is :f_mentor

    assert_raise Authorization::PermissionDenied do
      get :home_page_widget, xhr: true
    end
  end

  def test_home_page_widget_failure_no_available_projects_for_user
    users(:f_mentor_pbe).program.roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    assert_false users(:f_mentor_pbe).can_render_home_page_widget?
    current_user_is :f_mentor_pbe

    assert_raise Authorization::PermissionDenied do
      get :home_page_widget, xhr: true
    end
  end

  def test_home_page_widget_success
    q = Connection::Question.create(:program => programs(:pbe), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    summary_q = Summary.create!(connection_question: q)
    assert users(:f_student_pbe).can_render_home_page_widget?
    current_user_is :f_student_pbe

    get :home_page_widget, xhr: true
    assert_response :success

    assert_equal users(:f_student_pbe).available_projects_for_user(true).first.first(ProgramsController::MAX_PROJECTS_TO_SHOW_IN_HOME_PAGE_WIDGET), assigns(:projects)
    assert_equal (assigns(:projects).size > ProgramsController::MAX_PROJECTS_TO_SHOW_IN_HOME_PAGE_WIDGET), assigns(:show_all_projects_option)
    assert_equal q, assigns(:connection_question)
    assert_equal_hash({}, assigns(:connection_question_answer_in_summary_hash))
  end

  def test_home_page_widget_success_with_any_connection_summary_q_answered
    q = Connection::Question.create(:program => programs(:pbe), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    summary_q = Summary.create!(connection_question: q)
    ans = Connection::Answer.create!(
          :question => q,
          :group => groups(:group_pbe_1),
          :answer_text => 'hello')
    users(:f_student_pbe).stubs(:available_projects_for_user).returns([[groups(:group_pbe_1), groups(:proposed_group_1), groups(:proposed_group_2), groups(:proposed_group_3), groups(:proposed_group_4)], false])
    assert users(:f_student_pbe).can_render_home_page_widget?
    current_user_is :f_student_pbe

    get :home_page_widget, xhr: true
    assert_response :success

    assert_equal_hash({groups(:group_pbe_1).id => ans.answer_text}, assigns(:connection_question_answer_in_summary_hash))
  end

  def test_meeting_feedback_widget_failure_login
    current_program_is :albers

    get :meeting_feedback_widget, xhr: true
    assert_response :unauthorized
  end

  def test_meeting_feedback_widget_success
    current_user_is :f_mentor

    get :meeting_feedback_widget, xhr: true
    assert_response :success
  end

  def test_new_user_visits_programs_root
    program = programs(:nwen)
    member = members(:student_0)

    current_member_is :student_0
    current_program_is program
    get :show
    assert_redirected_to about_path
    assert_nil assigns(:current_user)
    assert_equal member, assigns(:current_member)
  end

  def test_new_user_visits_programs_root
    program = programs(:nwen)
    member = members(:student_0)

    current_member_is :student_0
    current_program_is program
    get :show
    assert_redirected_to about_path
    assert_nil assigns(:current_user)
    assert_equal member, assigns(:current_member)
  end

  def test_privacy_setting_tab_should_load_non_admin_roles
    current_user_is users(:f_admin)
    get :edit, params: { :tab => ProgramsController::SettingsTabs::PERMISSIONS}
    assert_response :success
    assert_equal ["mentor", "student", "user", "manager_role"], assigns(:roles).collect(&:name)
  end

  def test_privacy_setting_tab_should_load_non_admin_roles_only
    current_user_is users(:f_admin)
    role = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.administrative = true;
    role.save!
    programs(:albers).reload
    get :edit, params: { :tab => ProgramsController::SettingsTabs::PERMISSIONS}
    assert_response :success
    assert_equal ["student", "user", "manager_role"], assigns(:roles).collect(&:name)
  end

  def test_handle_feature_dependency_for_standalone_programs
    program = programs(:albers)
    organization = program.organization
    Organization.any_instance.stubs(:standalone?).returns(:true)
    mentoring_connections_v2_feature = Feature.find_by(name: FeatureName::MENTORING_CONNECTIONS_V2)

    organization.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    organization.enable_feature(FeatureName::COACHING_GOALS, true)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)

    assert program.coaching_goals_enabled?
    assert_false program.mentoring_connections_v2_enabled?

    login_as_super_user
    current_user_is :f_admin
    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::FEATURES,
      program: { organization: { enabled_features: ["mentoring_connections_v2", "coaching_goals", "manager"] } }}
    program.reload
    organization.reload
    assert_false program.coaching_goals_enabled?
    assert_false organization.coaching_goals_enabled?
    assert program.mentoring_connections_v2_enabled?
    assert organization.mentoring_connections_v2_enabled?
    assert program.manager_enabled?
    assert organization.manager_enabled?
  end

  def test_allow_default_reason_to_be_updated_superconsole
    current_user_is :f_admin
    current_program_is :albers
    program = programs(:albers)
    non_default_reason = group_closure_reasons(:group_closure_reasons_1)
    non_default_reason_2 = group_closure_reasons(:group_closure_reasons_2)
    default_reason = group_closure_reasons(:group_closure_reasons_6)
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true

    post_with_calendar_check :update, params: {
      :tab => ProgramsController::SettingsTabs::CONNECTION,
      :group_closure_reasons => {
        1 => {:reason => "AEIOU", :is_deleted => "1", :is_completed => "0", :is_default => "1"},
        2 => {:reason => "", :is_deleted => "1", :is_completed => "1", :is_default => "1"},
        6 => {:reason => "ABCD", :is_deleted => "1", :is_completed => "0", :is_default => "0"}
      }
    }
    assert non_default_reason.reload.is_deleted
    assert_equal false, non_default_reason.is_completed
    assert_equal "AEIOU", non_default_reason.reason
    assert_equal false, non_default_reason.is_default #is_default should not be updated

    assert_equal false, default_reason.reload.is_deleted
    assert default_reason.is_completed
    assert_equal "ABCD", default_reason.reason #only reason should be updated for default reasons
    assert default_reason.is_default
    assert_equal non_default_reason_2, group_closure_reasons(:group_closure_reasons_2).reload #will not update if reason is empty
  end

  def test_block_update_default_group_closure_reason_without_superconsole
    current_user_is :f_admin
    current_program_is :albers
    program = programs(:albers)
    non_default_reason = group_closure_reasons(:group_closure_reasons_1)
    default_reason = group_closure_reasons(:group_closure_reasons_6)

    assert_difference "GroupClosureReason.count", 1 do
      post_with_calendar_check :update, params: {
        :tab => ProgramsController::SettingsTabs::CONNECTION,
        :group_closure_reasons => {
          1 => {:reason => "AEIOU", :is_deleted => "1", :is_completed => "0"},
          6 => {:reason => "ABCD", :is_deleted => "1", :is_completed => "0"}
        },
        :new_group_closure_reasons => {
          1 => {:reason => "test", :is_deleted => "1", :is_completed => "0"},
          2 => {:reason => "", :is_deleted => "0", :is_completed => "0"}
        }
      }
    end
    assert non_default_reason.reload.is_deleted
    assert_equal false, non_default_reason.is_completed
    assert_equal "AEIOU", non_default_reason.reason
    assert_equal false, default_reason.reload.is_deleted
    assert default_reason.is_completed
    assert_equal "Connection has ended", default_reason.reason
    new_reason = GroupClosureReason.last
    assert_equal "test", new_reason.reason
    assert !new_reason.is_deleted
  end

  def test_update_mentor_request_style_from_admin_matched_to_self_matched
    current_user_is :no_mreq_admin
    current_program_is :no_mentor_request_program
    program = programs(:no_mentor_request_program)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    admin_role = program.find_role(RoleConstants::ADMIN_NAME)
    assert_equal Program::MentorRequestStyle::NONE, program.mentor_request_style
    assert_false student_role.has_permission_name?("send_mentor_request")
    assert_false admin_role.has_permission_name?("manage_mentor_requests")

    post_with_calendar_check :update, params: {
      program: { mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_MENTOR },
      tab: ProgramsController::SettingsTabs::MATCHING
    }

    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, program.reload.mentor_request_style
    assert student_role.reload.has_permission_name?("send_mentor_request")
    assert admin_role.reload.has_permission_name?("manage_mentor_requests")
  end

  def test_update_admin_matching_to_self_matching_with_mutiple_groups
    program = programs(:albers)
    program.mentor_request_style = Program::MentorRequestStyle::NONE
    program.save!
    program.enable_feature(FeatureName::OFFER_MENTORING, false)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    GroupsAlertData.expects(:multiple_existing_groups_note_data).once.returns([[1]])
    current_user_is :f_admin
    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::MATCHING, program: { enabled_features: [FeatureName::OFFER_MENTORING] },
      mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_MENTOR}
    assert_equal program.reload.mentor_request_style, Program::MentorRequestStyle::NONE
    assert_false program.mentor_offer_enabled?
  end

  def test_cannot_update_self_match_to_preferred_mentoring_with_pending_mentor_requests
    program = programs(:albers)
    assert program.mentor_requests.present?
    current_user_is :f_admin
    login_as_super_user

    post_with_calendar_check :update, params: {
        program: { mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN },
        tab: ProgramsController::SettingsTabs::MATCHING }

    assert program.reload.matching_by_mentee_alone?
  end

  def test_update_self_match_to_preferred_mentoring
    program = programs(:albers)
    program.mentor_requests.destroy_all
    current_user_is :f_admin

    post_with_calendar_check :update, params: {
        program: {
          mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN,
          allow_preference_mentor_request: true,
          min_preferred_mentors: 5 },
        tab: ProgramsController::SettingsTabs::MATCHING }

    assert program.reload.matching_by_mentee_and_admin?
    assert program.allow_preference_mentor_request
    assert_equal 5, program.min_preferred_mentors
  end

  def test_flash_meetings_widget_with_more_meetings_than_to_display
    current_user_is users(:f_mentor)
    meeting_hash = {meeting: meetings(:f_mentor_mkr_student), current_occurrence_time: meetings(:f_mentor_mkr_student).start_time}

    Meeting.stubs(:get_meetings_to_render_in_home_page_widget).with(members(:f_mentor), programs(:albers)).returns([meeting_hash, meeting_hash, meeting_hash, meeting_hash])

    get :flash_meetings_widget, xhr: true

    assert_response :success
    assert assigns(:show_view_all)
    assert_equal [meeting_hash, meeting_hash, meeting_hash], assigns(:meetings_to_show)
  end

  def test_flash_meetings_widget_with_less_meetings_than_to_display
    current_user_is users(:f_mentor)
    meeting_hash = {meeting: meetings(:f_mentor_mkr_student), current_occurrence_time: meetings(:f_mentor_mkr_student).start_time}
    
    Meeting.stubs(:get_meetings_to_render_in_home_page_widget).with(members(:f_mentor), programs(:albers)).returns([meeting_hash, meeting_hash])

    get :flash_meetings_widget, xhr: true

    assert_response :success
    assert_false assigns(:show_view_all)
    assert_equal [meeting_hash, meeting_hash], assigns(:meetings_to_show)
  end

  def test_flash_meetings_widget_with_no_meetings
    current_user_is users(:f_mentor)

    Meeting.stubs(:get_meetings_to_render_in_home_page_widget).with(members(:f_mentor), programs(:albers)).returns([])

    get :flash_meetings_widget, xhr: true

    assert_response :success
    assert_false assigns(:show_view_all)
    assert_equal [], assigns(:meetings_to_show)
  end

  def test_mentoring_connections_widget_for_mentor
    current_user_is users(:f_mentor)
    get :mentoring_connections_widget, xhr: true, params: { page: 1}
    assert_response :success
    assert_equal [groups(:mygroup)], assigns(:groups)
    groups(:mygroup).update_column(:status, Group::Status::CLOSED)
    get :mentoring_connections_widget, xhr: true, params: { page: 1}
    assert_response :success
    assert_equal [], assigns(:groups)
  end

  def test_mentoring_connections_widget_for_student
    current_user_is users(:f_mentor)
    get :mentoring_connections_widget, xhr: true, params: { page: 1}
    assert_response :success
    assert_equal [groups(:mygroup)], assigns(:groups)
    groups(:mygroup).update_column(:status, Group::Status::CLOSED)
    get :mentoring_connections_widget, xhr: true, params: { page: 1}
    assert_response :success
    assert_equal [], assigns(:groups)
  end

  def test_permission_denied_remove_third_role_non_super_user
    current_program_is :pbe
    current_user_is :f_admin_pbe
    assert programs(:pbe).has_role?(RoleConstants::TEACHER_NAME)
    assert_permission_denied do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: false }}
    end
  end

  def test_permission_denied_add_third_role_non_super_user
    current_program_is :ceg
    current_user_is :ceg_admin
    assert_false programs(:ceg).has_role?(RoleConstants::TEACHER_NAME)
    assert_permission_denied do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: true }}
    end
  end

  def test_flash_remove_third_role_with_references
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    program = programs(:pbe)
    current_program_is :pbe
    current_user_is :f_admin_pbe
    assert programs(:pbe).has_role?(RoleConstants::TEACHER_NAME)
    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: false }}
    assert_equal "Failed to remove third role.", flash[:error]
  end

  def test_flash_remove_third_role_with_tied_admin_views
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    program = programs(:pbe)
    current_program_is :pbe
    current_user_is :f_admin_pbe
    program.teacher_users.destroy_all
    admin_view = program.admin_views.find_by(default_view: [nil, AdminView::EDITABLE_DEFAULT_VIEWS].flatten)
    filter_params_hash = admin_view.filter_params_hash
    filter_params_hash[:roles_and_status][:role_filter_1][:roles] << RoleConstants::TEACHER_NAME
    admin_view.update_attributes!(filter_params: filter_params_hash.to_yaml)
    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: false }}
    assert_equal "Failed to remove third role.", flash[:error]
  end

  def test_invalid_enable_third_role
    TeacherRoleManager.any_instance.expects(:create).never
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    current_program_is :pbe
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    assert program.has_role?(RoleConstants::TEACHER_NAME)
    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: true }}
  end

  def test_invalid_disable_third_role
    TeacherRoleManager.any_instance.expects(:remove).never
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    current_program_is :ceg
    current_user_is :ceg_admin
    assert_false programs(:ceg).has_role?(RoleConstants::TEACHER_NAME)
    post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: false }}
  end

  def test_disable_third_role
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    current_program_is :pbe
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    assert program.has_role?(RoleConstants::TEACHER_NAME)
    program.teacher_users.destroy_all
    assert_difference "Role.count", -1 do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: false }}
    end
    assert_false program.reload.has_role?(RoleConstants::TEACHER_NAME)
    assert "The role 'Teacher' has been removed from the program. Other changes also have been saved.", flash[:notice]
  end

  def test_enable_third_role
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    current_program_is :ceg
    current_user_is :ceg_admin
    program = programs(:ceg)
    assert_false program.has_role?(RoleConstants::TEACHER_NAME)
    assert_difference "Role.count", 1 do
      post_with_calendar_check :update, params: { tab: ProgramsController::SettingsTabs::GENERAL, program: { third_role_enabled: true }}
    end
    assert program.reload.has_role?(RoleConstants::TEACHER_NAME)
    assert "The third Role has been enabled. Click here to change the custom term for the role. Other changes also have been saved.", flash[:notice]
  end

  def test_announcements_widget_for_mentor
    current_user_is :not_requestable_mentor
    get :announcements_widget
    announcements(:assemble).update_column(:updated_at, Time.now)
    assert_equal [announcements(:big_announcement), announcements(:assemble)], assigns(:announcements)
    create_viewed_object(ref_obj: announcements(:big_announcement), user: users(:not_requestable_mentor))
    get :announcements_widget
    assert_equal [announcements(:assemble), announcements(:big_announcement)], assigns(:announcements)
    announcement1 = create_announcement(:title => "Hello", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    announcements(:assemble).update_column(:updated_at, Time.now)
    get :announcements_widget
    assert_equal [announcement1, announcements(:assemble), announcements(:big_announcement)], assigns(:announcements)
  end

  def test_announcements_widget_for_student
    current_user_is :drafted_group_user
    get :announcements_widget
    announcements(:big_announcement).update_column(:updated_at, Time.now)
    assert_equal [announcements(:assemble), announcements(:big_announcement)], assigns(:announcements)
    create_viewed_object(ref_obj: announcements(:assemble), user: users(:drafted_group_user))
    get :announcements_widget
    assert_equal [announcements(:big_announcement), announcements(:assemble)], assigns(:announcements)
    announcement1 = create_announcement(:title => "Hello", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    announcements(:big_announcement).update_column(:updated_at, Time.now)
    get :announcements_widget
    assert_equal [announcement1, announcements(:big_announcement), announcements(:assemble)], assigns(:announcements)
  end

  def test_should_change_employee_article_publish_permission
    program = programs(:primary_portal)
    assert_false program.has_role_permission?(RoleConstants::EMPLOYEE_NAME, "write_article")

    current_user_is :portal_admin
    assert_difference 'RolePermission.count' do
      post :update, params: { permissions_tab: "true", program: { permissions: ["", "employees_publish_articles"] }, tab: ProgramsController::SettingsTabs::PERMISSIONS }
    end
    assert program.has_role_permission?(RoleConstants::EMPLOYEE_NAME, "write_article")
  end

  private

  def setup_for_recommendations
    program = programs(:albers)
    admin = users(:f_admin)
    student = users(:f_student)
    mentor = users(:f_mentor)
    ram = users(:ram)
    robert = users(:robert)
    current_user_is student
    current_program_is :albers

    #creating recommendation
    m = MentorRecommendation.new
    m.program = program
    m.sender = admin
    m.receiver = student
    m.status = MentorRecommendation::Status::PUBLISHED
    m.save!

    #creating recommendation preferences
    p1 = m.recommendation_preferences.new
    p1.position = 1
    p1.preferred_user = mentor
    p1.save

    p2 = m.recommendation_preferences.new
    p2.position = 2
    p2.preferred_user = ram
    p2.save!

    p3 = m.recommendation_preferences.new
    p3.position = 1
    p3.preferred_user = robert
    p3.save!
  end

  def assert_update_prompt_is_shown
    assert_select 'div#profile_update', 1
  end

  def assert_update_prompt_is_not_shown
    assert_no_select 'div#profile_update'
  end

  def assert_quick_link_item(class_name, href_link, text)
    assert_select 'li' do
      assert_select "a", :href => href_link, :text => text
    end
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def post_with_calendar_check(*args)
    organization = Program::Domain.get_organization(@request.domain, @controller.send(:current_subdomain)) if args[0] == :update
    program = organization.programs.where(root: @controller.current_root).first if organization
    initial_state = program.calendar_enabled? if program
    ret = post(*args)
    assert_equal initial_state, program.reload.calendar_enabled? if program
    ret
  end
end
