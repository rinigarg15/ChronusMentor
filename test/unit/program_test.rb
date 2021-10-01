# encoding: utf-8
require_relative './../test_helper.rb'

class ProgramTest < ActiveSupport::TestCase
  include GroupsReportExtensions

  def test_root_and_organization_required
    program =  Program.new(mentoring_period: 3.months, name: "Some program")
    assert_false program.valid?
    assert program.errors[:root]
    assert program.errors[:organization]
    assert program.errors[:engagement_type]

    program.build_organization
    assert_false program.valid?
    assert program.errors[:organization]
  end

  def test_has_role
    p = programs(:albers)
    r1 = Role.create!(name: "queen", program: p, administrative: true)
    r2 = Role.create!(name: "king", program: p)
    assert p.has_role?("queen")
    assert p.has_role?("king")
    assert_false p.has_role?("joker")
  end

  def test_get_first_role_term
    program = programs(:albers)
    assert program.get_first_role_term(:term), "Mentor"
    assert program.get_first_role_term(:term_downcase), "mentor"
    assert program.get_first_role_term(:pluralized_term), "Mentors"
    assert program.get_first_role_term(:pluralized_term_downcase), "mentors"
    assert program.get_first_role_term(:articleized_term), "a Mentor"
    assert program.get_first_role_term(:articleized_term_downcase), "a mentor"


    assert program.get_first_role_term(:term, true), "Administrator"
    assert program.get_first_role_term(:term_downcase, true), "administrator"
    assert program.get_first_role_term(:pluralized_term, true), "Administrators"
    assert program.get_first_role_term(:pluralized_term_downcase, true), "administrators"
    assert program.get_first_role_term(:articleized_term, true), "an Administrator"
    assert program.get_first_role_term(:articleized_term_downcase, true), "an administrator"
  end

  def test_is_career_developement_program
    assert_false Program.new.is_career_developement_program?
  end

  def test_has_many_pages_and_all_pages
    # CEG does not have any special page
    program = programs(:ceg)
    organization = programs(:org_anna_univ)

    pages = [:pages_4, :pages_5, :pages_6].map { |id| pages(id) }

    assert program.pages.empty?
    assert_equal pages, program.all_pages

    assert_difference "program.pages.count" do
      @page = program.pages.create!(:title => "Page 1", :content => "Hello")
    end

    assert_equal [@page], program.pages
    assert_equal (pages + [@page]).sort_by(&:position), program.all_pages
  end

  def test_has_many_campaigns
    assert_equal 8, programs(:albers).user_campaigns.count
  end

  def test_has_many_summaries
    assert_equal 1, programs(:albers).summaries.count
    assert_equal 1, programs(:psg).summaries.count
  end

  def test_connection_question_in_summary
    assert_equal common_questions(:string_connection_q), programs(:albers).connection_summary_question
    assert_equal common_questions(:string_connection_q_psg), programs(:psg).connection_summary_question
  end

  def test_has_one_program_invitation_campaign
    program = programs(:albers)
    program.program_invitation_campaign.destroy
    program.reload
    assert_nil program.program_invitation_campaign

    program_invitation_campaign = CampaignManagement::ProgramInvitationCampaign.create!(title: "Program Invitation Campaign Test 1", state: 0, program: program)
    assert_equal program_invitation_campaign, program.reload.program_invitation_campaign

    e = assert_raise(ActiveRecord::RecordInvalid) do
      CampaignManagement::ProgramInvitationCampaign.create!(title: "Program Invitation Campaign Test 2", state: 0, program: program)
    end
    assert_match("Program has already been taken", e.message)
  end

  def test_user_search_activity_association
    program = programs(:albers)
    user_search_activities = [user_search_activities(:user_search_activity_1), user_search_activities(:user_search_activity_2), user_search_activities(:user_search_activity_3)]
    assert_equal_unordered user_search_activities, program.user_search_activities
  end

  def test_can_disable_calendar
    program = programs(:albers)
    assert program.meeting_requests.active.exists?
    assert_false program.can_disable_calendar?
    program.meeting_requests.active.update_all(status: AbstractRequest::Status::CLOSED)
    assert program.can_disable_calendar?
    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_false program.can_disable_calendar?
    program.stubs(:ongoing_mentoring_enabled?).returns(true)
    assert program.can_disable_calendar?
    program.mailer_templates.last.update_attribute(:source, "some text {{number_of_pending_meeting_requests}}")
    assert_false program.can_disable_calendar?
  end

  def test_is_mailer_template_enabled
    program = programs(:albers)
    mailer_template = mailer_templates(:mailer_templates_3)
    mailer_template.update_attribute(:enabled, false)
    assert_false program.is_mailer_template_enabled(mailer_template.uid)
    mailer_template.update_attribute(:enabled, true)
    assert program.is_mailer_template_enabled(mailer_template.uid)
  end

  def test_does_not_have_mailer_templates_with_calendar_tags
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    assert program.does_not_have_mailer_templates_with_calendar_tags?
    template = program.mailer_templates.last
    template.update_attribute(:source, "some text {{number_of_pending_meeting_requests}}")
    assert_false program.does_not_have_mailer_templates_with_calendar_tags?
    program.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT, false)
    assert program.does_not_have_mailer_templates_with_calendar_tags?
  end

  def test_destroy_all_non_group_meetings
    create_meeting.update_attributes(group_id: nil)
    program = programs(:albers)
    assert program.meetings.non_group_meetings.exists?
    assert_no_difference "ActionMailer::Base.deliveries.count" do
      Program.destroy_all_non_group_meetings(program.id)
    end
    assert_false program.meetings.non_group_meetings.exists?
  end

  def test_prepare_to_disable_calendar
    create_meeting.update_attributes(group_id: nil)
    program = programs(:albers)
    assert program.meetings.non_group_meetings.exists?
    assert program.users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).count > 0
    assert_no_difference "ActionMailer::Base.deliveries.count" do
      program.prepare_to_disable_calendar
    end
    assert_false program.meetings.non_group_meetings.exists?
    assert_equal 0, program.users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).count
  end

  def test_prepare_to_re_enable_calendar
    program = programs(:albers)
    program.users[0].update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    program.users[1].update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    assert program.users.where(mentoring_mode: [User::MentoringMode::ONGOING, User::MentoringMode::ONE_TIME]).count > 0
    program.prepare_to_re_enable_calendar
    assert_equal 0, program.users.where(mentoring_mode: [User::MentoringMode::ONGOING, User::MentoringMode::ONE_TIME]).count
    assert_equal program.users.count, program.users.where(mentoring_mode: [User::MentoringMode::ONE_TIME_AND_ONGOING]).count
  end

  def test_has_one_group_view
    GroupView.destroy_all
    program = programs(:albers)
    assert_nil program.group_view

    group_view = GroupView.create!(program: program)
    assert_equal group_view, program.reload.group_view
  end

  def test_has_custom_role
    program = programs(:ceg)
    assert_false program.has_custom_role?
    program.roles.create!(:name => 'custom_role')
    assert program.has_custom_role?
  end

  def test_custom_roles
    program = programs(:ceg)
    assert_empty program.custom_roles
    new_role = program.roles.create!(name: 'custom_role')
    assert_equal [new_role], program.custom_roles
  end

  def test_mentoring_roles_with_permission
    program = programs(:pbe)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    teacher_role = program.roles.find_by(name: RoleConstants::TEACHER_NAME)
    admin_role = program.roles.find_by(name: RoleConstants::ADMIN_NAME)
    assert_equal_unordered [mentor_role.id, student_role.id], program.mentoring_roles_with_permission("view_mentors").pluck(:id)
    teacher_role.add_permission("view_teachers")
    assert_equal [teacher_role.id], program.mentoring_roles_with_permission("view_teachers").pluck(:id)
    teacher_role.remove_permission("view_teachers")
    admin_role.add_permission("view_teachers")
    assert_equal [], program.mentoring_roles_with_permission("view_teachers").pluck(:id)
  end

  def test_ytd_time_objects
    Timecop.freeze do
      assert_equal [Time.now.utc.beginning_of_year, Time.now.utc], programs(:albers).ytd_time_objects
    end
  end

  def test_get_program_ids_ary
    assert_equal [programs(:albers).id], programs(:albers).get_program_ids_ary
  end

  def test_completed_connections_ytd_query
    program = programs(:albers)
    Timecop.freeze do
      assert_equal "SELECT `groups`.* FROM `groups` WHERE `groups`.`program_id` = #{program.id} AND (groups.closure_reason_id IN (1,6)) AND (groups.published_at is not NULL) AND (`groups`.`closed_at` BETWEEN '#{program.ytd_time_objects[0].to_s(:db)}' AND '#{program.ytd_time_objects[1].to_s(:db)}')", program.completed_connections_ytd_query.to_sql
    end
  end

  def test_completed_connections_ytd_count
    assert_equal 1, programs(:albers).completed_connections_ytd_count
    assert_equal 0, programs(:ceg).completed_connections_ytd_count
  end

  def test_get_positive_outcome_groups_ytd_query
    assert_equal "SELECT groups.id as group_id, connection_memberships.user_id as connection_membership_user_id FROM `groups` INNER JOIN `connection_memberships` ON `connection_memberships`.`group_id` = `groups`.`id` WHERE 1=0", programs(:albers).get_positive_outcome_groups_ytd_query.to_sql
  end

  def test_successful_completed_connections_ytd_count
    assert_equal 0, programs(:albers).successful_completed_connections_ytd_count
  end

  def test_account_name
    program = programs(:albers)
    program.organization.account_name = "abc"
    assert_equal "abc", program.account_name
  end

  def test_url
    assert_equal "#{programs(:albers).organization.subdomain}.#{DEFAULT_HOST_NAME}/p/albers", programs(:albers).url
  end

  def test_status_string
    program = programs(:albers)
    assert_equal "Active", program.status_string
    assert_equal "something", programs(:albers).status_string("something")
    program.organization.active = false
    assert_equal "Inactive", program.status_string
    program.organization.active = true
    program.active = false
    assert_equal "Inactive", program.status_string
  end

  def test_organization_name
    program = programs(:albers)
    assert_equal program.organization.name, program.organization_name
  end

  def test_mentor_enrollment_mode_string
    assert_equal "membership_request", programs(:albers).mentor_enrollment_mode_string
  end

  def test_mentee_enrollment_mode_string
    assert_equal "membership_request", programs(:albers).mentee_enrollment_mode_string
  end

  def test_matching_mode_string
    assert_equal "Mentee requesting mentor", programs(:albers).matching_mode_string
    assert_equal "Mentee requesting Admin, Mentee requesting Admin (with preference)", programs(:psg).matching_mode_string
    assert_equal "Admin Matching", programs(:no_mentor_request_program).matching_mode_string
  end

  def test_engagement_mode_string
    assert_equal "Ongoing", programs(:albers).engagement_mode_string
    assert_equal "Circles", programs(:pbe).engagement_mode_string
  end

  def test_current_users_with_unpublished_or_published_profiles_count
    assert_equal 45, programs(:albers).current_users_with_unpublished_or_published_profiles_count
  end

  def test_current_users_with_published_profiles_count
    assert_equal 44, programs(:albers).current_users_with_published_profiles_count
  end

  def test_current_connected_users_count
    assert_equal 8, programs(:albers).current_connected_users_count
  end

  def test_current_active_connections_count
    assert_equal 6, programs(:albers).current_active_connections_count
  end

  def test_last_login
    assert_equal programs(:albers).users.pluck(:last_seen_at).compact.max, programs(:albers).last_login
  end

  def test_users_with_unpublished_or_published_profiles_ytd_count
    program = programs(:albers)
    assert_equal User.get_ids_of_users_active_between(program, *program.ytd_time_objects, include_unpublished: true).size, program.users_with_unpublished_or_published_profiles_ytd_count
  end

  def test_users_with_published_profiles_ytd_count
    program = programs(:albers)
    assert_equal User.get_ids_of_users_active_between(program, *program.ytd_time_objects).size, program.users_with_published_profiles_ytd_count
  end

  def test_users_connected_ytd_count
    program = programs(:albers)
    assert_equal User.get_ids_of_connected_users_active_between(program, *program.ytd_time_objects).size, program.users_connected_ytd_count
  end

  def test_connections_ytd_count
    program = programs(:albers)
    assert_equal Group.get_ids_of_groups_active_between(program, *program.ytd_time_objects).size, program.connections_ytd_count
  end

  def test_users_completed_connections_ytd_count
    program = programs(:albers)
    assert_equal ActiveRecord::Base.connection.exec_query(program.completed_connections_ytd_query.joins(:memberships).select("connection_memberships.user_id").to_sql).rows.flatten.compact.uniq.size, program.users_completed_connections_ytd_count
  end

  def test_users_successful_completed_connections_ytd_count
    program = programs(:albers)
    assert_equal ActiveRecord::Base.connection.exec_query(program.get_positive_outcome_groups_ytd_query.to_sql).to_hash.map{ |hsh| hsh["connection_membership_user_id"] }.compact.uniq.size, program.users_successful_completed_connections_ytd_count
  end

  def test_self_match_and_not_pbe
    program = programs(:albers)
    program.stubs(:career_based?).returns(false)
    assert_false program.self_match_and_not_pbe?

    program.stubs(:career_based?).returns(true)
    program.stubs(:self_match?).returns(false)
    assert_false program.self_match_and_not_pbe?

    program.stubs(:self_match?).returns(true)
    assert program.self_match_and_not_pbe?
  end

  def test_career_based_self_match_or_only_flash
    program = programs(:albers)
    program.stubs(:career_based?).returns(false)
    program.stubs(:self_match?).returns(true)
    program.stubs(:only_one_time_mentoring_enabled?).returns(false)
    assert_false program.career_based_self_match_or_only_flash?

    program.stubs(:career_based?).returns(true)
    assert program.career_based_self_match_or_only_flash?

    program.stubs(:self_match?).returns(false)
    assert_false program.career_based_self_match_or_only_flash?

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert program.career_based_self_match_or_only_flash?
  end

  def test_career_based_self_match_or_flash
    program = programs(:albers)
    program.stubs(:career_based?).returns(false)
    program.stubs(:self_match?).returns(true)
    program.stubs(:calendar_enabled?).returns(false)
    assert_false program.career_based_self_match_or_flash?

    program.stubs(:career_based?).returns(true)
    assert program.career_based_self_match_or_flash?

    program.stubs(:self_match?).returns(false)
    assert_false program.career_based_self_match_or_flash?

    program.stubs(:calendar_enabled?).returns(true)
    assert program.career_based_self_match_or_flash?
  end

  def test_career_based_ongoing_mentoring_and_not_calendar_enabled
    program = programs(:albers)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:calendar_enabled?).returns(false)
    assert program.career_based_ongoing_mentoring_and_not_calendar_enabled?

    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:calendar_enabled?).returns(true)
    assert_false program.career_based_ongoing_mentoring_and_not_calendar_enabled?

    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:calendar_enabled?).returns(false)
    assert_false program.career_based_ongoing_mentoring_and_not_calendar_enabled?

    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:calendar_enabled?).returns(true)
    assert_false program.career_based_ongoing_mentoring_and_not_calendar_enabled?
  end

  def test_match_report_admin_views
    program = programs(:albers)
    assert_equal 3, program.match_report_admin_views.count
    assert_equal_unordered [program.admin_views.find_by(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS).id, program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTEES).id, program.admin_views.find_by(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES).id], program.match_report_admin_views.pluck(:admin_view_id)

    assert_difference "MatchReportAdminView.count", -3 do
      program.destroy
    end
  end

  def test_create_default_match_report_section_settings
    program = programs(:albers)
    program.match_report_admin_views.destroy_all
    assert_equal 0, program.match_report_admin_views.count
    assert_difference "program.match_report_admin_views.count", 3 do
      program.create_default_match_report_section_settings
    end
    assert_equal_unordered [program.admin_views.find_by(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS).id, program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTEES).id, program.admin_views.find_by(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES).id], program.match_report_admin_views.pluck(:admin_view_id)
  end

  def test_can_show_match_report
    program = programs(:albers)
    program.stubs(:can_have_match_report?).returns(true)
    program.stubs(:match_report_enabled?).returns(true)
    assert program.can_show_match_report?
    program.stubs(:can_have_match_report?).returns(false)
    assert_false program.can_show_match_report?
    program.stubs(:match_report_enabled?).returns(false)
    assert_false program.can_show_match_report?
  end

  def test_can_have_match_report
    program = programs(:albers)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_career_developement_program?).returns(true)
    program.stubs(:project_based?).returns(true)
    program.stubs(:matching_by_mentee_and_admin?).returns(true)
    assert_false program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_career_developement_program?).returns(false)
    program.stubs(:project_based?).returns(true)
    assert_false program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_career_developement_program?).returns(true)
    program.stubs(:project_based?).returns(false)
    assert_false program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    program.stubs(:is_career_developement_program?).returns(false)
    program.stubs(:project_based?).returns(false)
    assert program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    program.stubs(:is_career_developement_program?).returns(true)
    program.stubs(:project_based?).returns(false)
    assert_false program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_career_developement_program?).returns(true)
    program.stubs(:project_based?).returns(true)
    program.stubs(:matching_by_mentee_and_admin?).returns(false)
    assert_false program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    program.stubs(:is_career_developement_program?).returns(false)
    program.stubs(:project_based?).returns(true)
    assert_false program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    program.stubs(:is_career_developement_program?).returns(true)
    program.stubs(:project_based?).returns(true)
    assert_false program.can_have_match_report?

    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_career_developement_program?).returns(false)
    program.stubs(:project_based?).returns(false)
    program.stubs(:matching_by_mentee_and_admin?).returns(false)
    assert program.can_have_match_report?
  end

  def test_get_flash_meeting_requested_ytd_count
    Timecop.travel(Time.now - 1.minute)
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    Timecop.return
    meeting = Meeting.last
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    count = program.get_flash_meeting_requested_ytd_count
    meeting.update_attribute(:owner_id, meeting.member_meetings.where.not(member_id: meeting.mentee_id).first.member_id)
    assert_equal count - 1, program.get_flash_meeting_requested_ytd_count
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    assert_equal count, program.get_flash_meeting_requested_ytd_count
    meeting.update_attribute(:created_at, (Time.now.beginning_of_year - 1.day))
    assert_equal count - 1, program.get_flash_meeting_requested_ytd_count
  end

  def test_get_flash_meeting_accepted_ytd_count
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    meeting.meeting_request.update_attributes!(accepted_at: (Time.now.beginning_of_year + 1.day), status: AbstractRequest::Status::ACCEPTED)
    assert_equal 1, program.get_flash_meeting_accepted_ytd_count
    meeting.update_attribute(:owner_id, meeting.member_meetings.where.not(member_id: meeting.mentee_id).first.member_id)
    assert_equal 0, program.get_flash_meeting_accepted_ytd_count
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year + 1.day))
    assert_equal 1, program.get_flash_meeting_accepted_ytd_count
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, program.get_flash_meeting_accepted_ytd_count
  end

  def test_get_flash_meeting_completed_ytd_count
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attributes!(state: Meeting::State::COMPLETED, state_marked_at: (Time.now - 2.hours))
    assert_equal 1, program.get_flash_meeting_completed_ytd_count
    meeting.update_attribute(:state_marked_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, program.get_flash_meeting_completed_ytd_count
    meeting.update_attribute(:state_marked_at, (Time.now - 2.hours))
    assert_equal 1, program.get_flash_meeting_completed_ytd_count
    meeting.update_attribute(:state, Meeting::State::CANCELLED)
    assert_equal 0, program.get_flash_meeting_completed_ytd_count
  end

  def test_users_with_accepted_flash_meeting_ytd_count
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    meeting.meeting_request.update_attributes!(accepted_at: (Time.now.beginning_of_year + 1.day), status: AbstractRequest::Status::ACCEPTED)
    assert_equal 2, program.users_with_accepted_flash_meeting_ytd_count
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, program.users_with_accepted_flash_meeting_ytd_count
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year + 1.day))
    assert_equal 2, program.users_with_accepted_flash_meeting_ytd_count
    meeting.meeting_request.update_attribute(:status, AbstractRequest::Status::REJECTED)
    assert_equal 0, program.users_with_accepted_flash_meeting_ytd_count
  end

  def test_users_with_completed_flash_meeting_ytd_count
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attributes!(state: Meeting::State::COMPLETED, state_marked_at: (Time.now - 2.hours))
    assert_equal 2, program.users_with_completed_flash_meeting_ytd_count
    meeting.update_attribute(:state_marked_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, program.users_with_completed_flash_meeting_ytd_count
  end

  def test_closed_connections_ytd_arel
    program = programs(:albers)
    Timecop.freeze do
      assert_equal "SELECT `groups`.* FROM `groups` WHERE `groups`.`program_id` = #{program.id} AND `groups`.`status` = 2 AND (`groups`.`closed_at` BETWEEN '#{program.ytd_time_objects[0].to_s(:db)}' AND '#{program.ytd_time_objects[1].to_s(:db)}')", program.closed_connections_ytd_arel.to_sql
    end
  end

  def test_closed_connections_ytd_count
    assert_equal 1, programs(:albers).closed_connections_ytd_count
  end

  def test_users_closed_connections_ytd_count
    assert_equal 2, programs(:albers).users_closed_connections_ytd_count
  end

  def test_has_many_meetings
    program = programs(:albers)
    assert_equal [meetings(:f_mentor_mkr_student), meetings(:student_2_not_req_mentor), meetings(:f_mentor_mkr_student_daily_meeting), meetings(:upcoming_calendar_meeting), meetings(:past_calendar_meeting), meetings(:completed_calendar_meeting), meetings(:cancelled_calendar_meeting)], program.meetings

    meeting = program.meetings.last
    meeting.update_attributes!(active: false)

    assert_false program.meetings.reload.include?(meeting)
  end

  def test_mentoring_slots
    prog = programs(:albers)

    assert_equal [mentoring_slots(:f_mentor)], prog.mentoring_slots
  end

  def test_has_many_three_sixty_surveys
    prog = programs(:albers)
    assert_equal 2, prog.three_sixty_surveys.size
    assert_equal "ThreeSixty::Survey", Program.reflect_on_association(:three_sixty_surveys).class_name
    assert_equal :destroy, Program.reflect_on_association(:three_sixty_surveys).options[:dependent]
  end

  def test_has_many_three_sixty_survey_assessees
    prog = programs(:albers)
    assert_equal 7, prog.three_sixty_survey_assessees.size
  end

  def test_has_many_report_view_columns
    program = programs(:albers)

    assert_equal 8, program.report_view_columns.for_groups_report.count
    assert_equal ["group", "mentors", "mentees", "started_on", "close_date", "messages_count", "total_activities", "current_status"], program.report_view_columns.for_groups_report.collect(&:column_key)

    program.report_view_columns.for_groups_report.first.update_attributes!(position: 100)
    assert_equal ["mentors", "mentees", "started_on", "close_date", "messages_count", "total_activities", "current_status", "group"], program.reload.report_view_columns.for_groups_report.collect(&:column_key)

    assert_equal 4, program.report_view_columns.for_demographic_report.count
    assert_equal ["country", "all_users_count", "mentors_count", "mentees_count"], program.report_view_columns.for_demographic_report.collect(&:column_key)

    program.report_view_columns.for_demographic_report.first.update_attributes!(position: 100)
    assert_equal ["all_users_count", "mentors_count", "mentees_count", "country"], program.reload.report_view_columns.for_demographic_report.collect(&:column_key)
  end

  def test_has_many_mentoring_model_tasks
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group = groups(:mygroup)

    task = create_mentoring_model_task(title: "TASK", required: false)
    assert program.mentoring_model_tasks.include?(task)
  end

  def test_program_has_many_recommendations
    # initial config
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_student)
    admin = users(:f_admin)
    ram = users(:ram)
    robert = users(:robert)

    recommendation0 = mentor_recommendations(:mentor_recommendation_1)

    # saving the first recommendation
    recommendation1 = create_mentor_recommendation(admin, student, program)

    # saving the second recommendation
    recommendation2 = create_mentor_recommendation(admin, robert, program)

    assert_equal_unordered program.mentor_recommendations, [recommendation0, recommendation1, recommendation2]
  end

  def test_new_articles
    Article.update_all(:created_at => 1.month.ago)
    program = programs(:albers)
    assert_equal [], program.new_articles
    article1 = create_article
    assert_equal [article1], program.new_articles
    article2 = create_article
    assert_equal [article1, article2], program.new_articles
    article2.update_attribute(:created_at, 2.months.ago)
    assert_equal [article1], program.new_articles
    programs(:albers).organization.enable_feature(FeatureName::ARTICLES, false)
    assert program.reload.new_articles.empty?
  end

  def test_new_qa_questions
    QaQuestion.update_all(:created_at => 1.month.ago)
    program = programs(:albers)
    assert_equal [], program.new_qa_questions
    question1 = create_qa_question
    assert_equal [question1], program.new_qa_questions
    question2 = create_qa_question
    assert_equal [question1, question2], program.new_qa_questions
    question2.update_attribute(:created_at, 2.months.ago)
    assert_equal [question1], program.new_qa_questions
    programs(:albers).organization.enable_feature(FeatureName::ANSWERS, false)
    assert program.reload.new_qa_questions.empty?
  end

  def test_new_mentors
    User.update_all(:created_at => 1.month.ago)
    program = programs(:albers)
    assert_equal [], program.new_mentors
    mentor1 = create_user(:role_names => [RoleConstants::MENTOR_NAME], :program => program, :name => "mentor", :email => "mentor_2@chronus.com")
    assert_equal [mentor1], program.new_mentors
    mentor2 = create_user(:role_names => [RoleConstants::MENTOR_NAME], :program => program, :name => "mentor", :email => "mentor_1@chronus.com")
    assert_equal [mentor1, mentor2], program.new_mentors
    mentor2.update_attribute(:created_at, 2.months.ago)
    assert_equal [mentor1], program.new_mentors
    mentor1.suspend_from_program!(users(:f_admin), "Sorry")
    assert_equal [], program.new_mentors
  end

  def test_new_students_count
    User.update_all(:created_at => 1.month.ago)
    program = programs(:albers)
    assert_equal 0, program.new_students_count
    student1 = create_user(:role_names => [RoleConstants::STUDENT_NAME], :program => program, :name => "student")
    assert_equal 1, program.new_students_count
    student2 = create_user(:role_names => [RoleConstants::STUDENT_NAME], :program => program, :name => "student_one")
    assert_equal 2, program.new_students_count
    student1.update_attribute(:created_at, 2.months.ago)
    assert_equal 1, program.new_students_count
    student2.suspend_from_program!(users(:f_admin), "Sorry")
    assert_equal 0, program.new_students_count
  end

  def test_program_has_users_as_members
    user = users(:f_admin)
    program = programs(:ceg)
    assert !program.member?(user)
    make_member_of(:ceg, :f_admin)
    assert program.member?(user)

    # Program has many members
    assert_equal_unordered [user, users(:arun_ceg), users(:ceg_admin), users(:f_mentor_ceg), users(:sarat_mentor_ceg), users(:ceg_mentor)],
      program.users

    make_member_of(:ceg, :f_student)
    program.reload
    assert_equal_unordered [user, users(:arun_ceg), users(:ceg_admin), users(:f_student), users(:f_mentor_ceg), users(:sarat_mentor_ceg), users(:ceg_mentor)], program.users
  end

  def test_program_should_have_name_and_root
    prog = Program.new
    assert_false prog.valid?
    assert_equal ["can't be blank"], prog.errors[:root]
    assert_equal ["can't be blank"], prog.errors[:name]
  end

  def test_program_sort_users_by
    p = programs(:albers)
    assert_equal(Program::SortUsersBy::FULL_NAME, p.sort_users_by)

    p.sort_users_by = 10
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :sort_users_by, "is not included in the list") do
      p.save!
    end

    p.sort_users_by = Program::SortUsersBy::LAST_NAME
    p.save!
    assert_equal(Program::SortUsersBy::LAST_NAME, p.reload.sort_users_by)
  end

  def test_build_and_save_user
    program = programs(:albers)
    user_details = {:last_name => "abc", :email => "abc@gmail.com", :password => "xyzxyz", :password_confirmation => "xyzxyz"}
    c = create_member(user_details)

    # Build student
    student = program.build_and_save_user!({}, [RoleConstants::STUDENT_NAME], c)
    assert student
    assert_equal [RoleConstants::STUDENT_NAME], student.role_names
    assert_equal UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, student.program_notification_setting

    suspend_user(student)
    assert student.suspended?
    # Build mentor, but the member is same so it will detect the student and add the corresponding roles
    # Also reactive the user
    mentor = program.build_and_save_user!({}, [RoleConstants::MENTOR_NAME], c)
    assert mentor
    assert mentor.suspended?
    assert student.reload.suspended?
    assert_equal [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], mentor.role_names
    assert_equal UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, mentor.program_notification_setting

    user_details = {:name => "abc", :email => "abc_admin@gmail.com", :password => "xyzxyz", :password_confirmation => "xyzxyz"}
    c1 = create_member(user_details)
    # Build admin
    admin = program.build_and_save_user!({}, [RoleConstants::ADMIN_NAME], c1)
    assert admin
    assert_equal [RoleConstants::ADMIN_NAME], admin.role_names
    assert_not_equal UserConstants::DigestV2Setting::ProgramUpdates::DAILY, admin.program_notification_setting
  end

  def test_build_and_save_user_for_existing_member
    program = programs(:nwen)
    members(:mkr_student).update_attribute(:state, Member::Status::SUSPENDED)
    member = members(:f_mentor_student)
    suspended_member = members(:mkr_student)
    assert_nil member.user_in_program(program)
    assert_nil suspended_member.user_in_program(program)

    assert_difference "member.reload.users.count" do
      program.build_and_save_user!({}, [RoleConstants::STUDENT_NAME], members(:f_mentor_student))
    end
    assert_no_difference "User.count" do
      program.build_and_save_user!({}, [RoleConstants::STUDENT_NAME], members(:mkr_student))
    end
  end

  def test_build_and_save_user_for_existing_suspended_user
    program = programs(:albers)
    user = users(:f_mentor)

    user.suspend_from_program!(users(:f_admin), "Suspension reason")
    assert user.suspended?

    assert_no_difference('ActionMailer::Base.deliveries.size') do
      program.build_and_save_user!({}, [RoleConstants::STUDENT_NAME], user.member, {admin: users(:f_admin)})
    end
    assert_false user.reload.suspended?

    user.suspend_from_program!(users(:f_admin), "Suspension reason")
    assert user.suspended?

    assert_no_difference('ActionMailer::Base.deliveries.size') do
      program.build_and_save_user!({}, [RoleConstants::STUDENT_NAME], user.member)
    end
    assert user.reload.suspended?

    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      program.build_and_save_user!({}, [RoleConstants::STUDENT_NAME], user.member, {admin: users(:f_admin), send_reactivation_email: true})
    end
    assert_false user.reload.suspended?
  end

  def test_mentor_questions_last_update_timestamp
    programs(:org_primary).profile_questions.destroy_all
    prog = programs(:albers)

    # Create a student question. It should't affect the mentor update timestamps
    create_student_question

    # No questions yet
    assert_equal(0, prog.mentor_questions_last_update_timestamp)

    # Add a few questions
    t1 = 3.days.ago
    Timecop.freeze(t1) do
      3.times { create_mentor_question }
    end
    tstamp = prog.reload.mentor_questions_last_update_timestamp
    assert_equal(t1.to_i, tstamp)

    # Add a new question
    t2 = 1.day.ago
    Timecop.freeze(t2) do
      create_mentor_question
    end
    tstamp = prog.reload.mentor_questions_last_update_timestamp
    assert_equal(t2.to_i, tstamp)

    # Update a mentor question
    t3 = 1.hour.ago
    Timecop.freeze(t3) do
      q = prog.reload.profile_questions_for(RoleConstants::MENTOR_NAME).last
      q.update_attributes(updated_at: t3)
    end
    tstamp = prog.reload.mentor_questions_last_update_timestamp
    assert_equal(t3.to_i, tstamp)

    # Update a student question
    Timecop.freeze(3.minutes.ago) do
      q = prog.reload.profile_questions_for(RoleConstants::STUDENT_NAME).last
      q.update_attributes(updated_at: 3.minutes.ago)
    end
    tstamp = prog.reload.mentor_questions_last_update_timestamp
    assert_equal(t3.to_i, tstamp)
  end

  def test_student_questions_last_update_timestamp
    programs(:org_primary).profile_questions.destroy_all
    prog = programs(:albers)
    # Create a student question. It should't affect the mentor update timestamps
    create_mentor_question

    # No questions yet
    assert_equal(0, prog.student_questions_last_update_timestamp)

    # Add a few questions
    t1 = 3.days.ago
    Timecop.freeze(t1) do
      3.times { create_student_question }
    end
    tstamp = prog.reload.student_questions_last_update_timestamp
    assert_equal(t1.to_i, tstamp)
  end

  def test_profile_questions_last_update_timestamp
    prog = programs(:albers)
    programs(:org_primary).profile_questions.destroy_all
    tm = 3.days.ago
    ts = 2.days.ago

    Timecop.freeze(tm) do
      create_mentor_question
    end
    Timecop.freeze(ts) do
      create_student_question
    end

    tstamp = prog.reload.student_questions_last_update_timestamp
    assert_equal(ts.to_i, tstamp)

    tstamp = prog.reload.mentor_questions_last_update_timestamp
    assert_equal(tm.to_i, tstamp)
  end

  def test_should_set_default_group_options_on_program_creation
    p = Program.new(:name => "Pgora name", :root => "Domain", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :organization => programs(:org_primary))

    assert p.valid?
    assert_equal Program::MentorRequestStyle::NONE, p.mentor_request_style
    assert_equal Program::DEFAULT_MENTORING_PERIOD, p.mentoring_period

    p =  Program.new(:name => "Pgora name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "Doma1in", :organization => programs(:org_anna_univ),
      :mentor_request_style => 1, :mentoring_period => 1.year, :allow_one_to_many_mentoring => true)

    assert p.valid?
    assert p.matching_by_mentee_and_admin?
    assert_equal 1.year, p.mentoring_period
    assert_equal p.role_names_to_join_directly_only_with_sso, []
  end

  def test_allow_users_to_join_directly_only_with_sso
    p = programs(:albers)
    assert_false p.allow_users_to_join_directly_only_with_sso?
    mentor_role = p.find_role('mentor')
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert p.allow_users_to_join_directly_only_with_sso?
  end

  def test_allow_membership_requests_or_join_directly_with_sso
    p = programs(:albers)
    assert_false p.allow_users_to_join_directly_only_with_sso?
    p.find_role('mentor').update_attributes(:membership_request => false, :join_directly_only_with_sso => true)
    p.find_role('student').update_attributes(:membership_request => false, :join_directly_only_with_sso => false)
    assert p.allow_join_now?
  end

  def test_role_names_to_join_directly_only_with_sso
    p = programs(:albers)
    assert_equal p.role_names_to_join_directly_only_with_sso, []
    mentor_role = p.find_role('mentor')
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert_equal p.role_names_to_join_directly_only_with_sso, ['mentor']
    mentee_role = p.find_role('student')
    mentee_role.membership_request = false
    mentee_role.join_directly_only_with_sso = true
    mentee_role.save
    assert_equal p.role_names_to_join_directly_only_with_sso, ['mentor','student']
  end

  def test_join_directly_only_with_sso_roles_present
    p = programs(:albers)
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    assert_false mentor_role.join_directly_only_with_sso?
    assert_false p.join_directly_only_with_sso_roles_present?(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert mentor_role.join_directly_only_with_sso?
    assert p.join_directly_only_with_sso_roles_present?(RoleConstants::MENTOR_NAME)
    assert p.join_directly_only_with_sso_roles_present?([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
  end

  def test_membership_request_only_roles_present
    p = programs(:albers)
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    assert mentor_role.membership_request?
    assert p.membership_request_only_roles_present?(RoleConstants::MENTOR_NAME)
    mentee_role = p.find_role('student')
    mentee_role.membership_request = false
    mentee_role.save
    assert p.membership_request_only_roles_present?([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert mentor_role.join_directly_only_with_sso?
    assert_false p.membership_request_only_roles_present?(RoleConstants::MENTOR_NAME)
    assert_false p.membership_request_only_roles_present?([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
  end

  def test_role_names_with_join_directly_or_join_directly_only_with_sso
    p = programs(:albers)
    assert_equal p.role_names_with_join_directly_or_join_directly_only_with_sso, []
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert_equal p.role_names_with_join_directly_or_join_directly_only_with_sso, [RoleConstants::MENTOR_NAME]
    mentee_role = p.find_role(RoleConstants::STUDENT_NAME)
    mentee_role.membership_request = false
    mentee_role.join_directly = true
    mentee_role.save
    assert_equal p.role_names_with_join_directly_or_join_directly_only_with_sso, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
  end

  def test_allow_join_directly_in_enrollment
    p = programs(:albers)
    assert_false p.allow_join_directly_in_enrollment?
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert p.reload.allow_join_directly_in_enrollment?
    mentor_role.join_directly_only_with_sso = false
    mentor_role.join_directly = true
    mentor_role.save
    assert p.reload.allow_join_directly_in_enrollment?
  end

  def test_has_allowing_join_with_criteria
    program = programs(:albers)

    assert_equal 0, program.roles.allowing_join_with_criteria.count
    assert_false program.has_allowing_join_with_criteria?

    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.update_attribute(:eligibility_rules, true)

    assert_equal 1, program.roles.allowing_join_with_criteria.count
    assert program.has_allowing_join_with_criteria?

    role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role.update_attribute(:eligibility_rules, true)

    assert_equal 2, program.roles.allowing_join_with_criteria.count
    assert program.has_allowing_join_with_criteria?
  end

  def test_invitable_roles_by_admins
    program = programs(:albers)
    something = "something"
    program.stubs(:find_role).with(RoleConstants::ADMIN_NAME).returns(something)
    something.stubs(:permission_names).returns([])
    assert_equal [], program.invitable_roles_by_admins

    something.stubs(:permission_names).returns(['invite_mentors'])
    assert_equal [RoleConstants::MENTOR_NAME], program.invitable_roles_by_admins.collect(&:name)

    something.stubs(:permission_names).returns(['invite_mentors', 'invite_students', 'invite_teachers'])
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], program.invitable_roles_by_admins.collect(&:name)
  end

  def test_should_not_accept_non_numerical_values_for_mentoring_period
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Program.create!(:name => "good", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "Willfull", :organization => programs(:org_anna_univ), :mentoring_period => 'abc')
    end
    assert_match("Mentoring period must be greater than 0", e.message)

    e = assert_raise(ActiveRecord::RecordInvalid) do
      Program.create!(:name => "good", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "Willfull", :organization => programs(:org_anna_univ), :mentoring_period => '-123')
    end
    assert_match("Mentoring period must be greater than 0", e.message)
  end

  def test_program_default_allow_end_users_to_see_match_scores
    program = programs(:albers)
    assert program.allow_end_users_to_see_match_scores

    new_program = Program.create!({:name => "notif program", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => 'match', :organization => programs(:org_primary)})
    assert new_program.allow_end_users_to_see_match_scores
  end

  def test_set_admin_for_program
    prog = programs(:albers)
    assert(!prog.owner)
    prog.set_owner!
    assert_equal prog.admin_users.first, prog.owner
  end

  def test_recent_activities_ordered_latest_first
    acts = []

    RecentActivity.destroy_all
    3.times do
      acts << RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS
      )
    end

    assert_equal acts.reverse, programs(:albers).recent_activities
  end

  def test_deliver_facilitation_messages_v2
    reference_time = Time.now.utc
    program = programs(:albers)
    program.groups.destroy_all
    program.reload
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    admin_member = program.admin_users.first.member
    facilitation_template_1 = create_mentoring_model_facilitation_template(send_on: 5, subject: "At 5th day", message: "day 5 message", roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    facilitation_template_2 = create_mentoring_model_facilitation_template(send_on: 9, subject: "At 9th day", message: "day 9 message", roles: program.get_roles([RoleConstants::STUDENT_NAME]))
    facilitation_template_3 = create_mentoring_model_facilitation_template(specific_date: (reference_time + 7.days).to_s, send_on: nil, subject: "At 7th day", message: "day 7 message", roles: program.get_roles([RoleConstants::STUDENT_NAME]))
    facilitation_template_4 = create_mentoring_model_facilitation_template(specific_date: (reference_time + 6.days - 2.hours).to_s, send_on: nil, subject: "At 6th day +2 UTC time zone", message: "day 6 +2 UTC message", roles: program.get_roles([RoleConstants::STUDENT_NAME]))
    facilitation_template_5 = create_mentoring_model_facilitation_template(specific_date: (reference_time + 7.days + 2.hours).to_s, send_on: nil, subject: "At 7th day -2 UTC time zone", message: "day 7 -2 UTC message", roles: program.get_roles([RoleConstants::STUDENT_NAME]))
    facilitation_template_varying_date = create_mentoring_model_facilitation_template(specific_date: (reference_time + 3.days).to_s, send_on: nil, subject: "Varying day", message: "varying message, test catches scenario where specific date and today date can be same", roles: program.get_roles([RoleConstants::STUDENT_NAME]))

    group = nil

    group = create_group({students: [users(:f_student)], mentors: [users(:f_mentor)], program: program, status: Group::Status::DRAFTED, creator_id: users(:f_admin).id})
    group.publish(users(:f_admin))

    1.upto(10) do |day|
      Timecop.travel(reference_time + day.days)
      if day == 4 || day == 5 || day == 6 || day == 7 || day == 8 || day == 9
        if day == 4
          assert_difference "ActionMailer::Base.deliveries.size", 1 do
            program.deliver_facilitation_messages_v2
          end
          mail = ActionMailer::Base.deliveries.last
          assert_equal group.students.map(&:email), mail.to
          assert_equal "Varying day - #{group.name}", mail.subject
          assert_match "varying message, test catches scenario where specific date and today date can be same", get_html_part_from(mail)
        elsif day == 5
          assert_difference "ActionMailer::Base.deliveries.size", 2 do
            program.deliver_facilitation_messages_v2
          end
          mails = ActionMailer::Base.deliveries.last(2)
          assert_equal group.students.map(&:email), mails[0].to
          assert_equal "At 5th day - #{group.name}", mails[0].subject
          assert_match "day 5 message", get_html_part_from(mails[0])
          assert_equal group.mentors.map(&:email), mails[1].to
          assert_equal "At 5th day - #{group.name}", mails[1].subject
          assert_match "day 5 message", get_html_part_from(mails[1])
        elsif day == 6
          assert_difference "ActionMailer::Base.deliveries.size", 1 do
            program.deliver_facilitation_messages_v2
          end
          mail = ActionMailer::Base.deliveries.last
          assert_equal group.students.map(&:email), mail.to
          assert_equal "At 6th day +2 UTC time zone - #{group.name}", mail.subject
          assert_match "day 6 +2 UTC message", get_html_part_from(mail)
        elsif day == 7
          assert_difference "ActionMailer::Base.deliveries.size", 1 do
            program.deliver_facilitation_messages_v2
          end
          mail = ActionMailer::Base.deliveries.last
          assert_equal group.students.map(&:email), mail.to
          assert_equal "At 7th day - #{group.name}", mail.subject
          assert_match "day 7 message", get_html_part_from(mail)
        elsif day == 8
          assert_difference "ActionMailer::Base.deliveries.size", 1 do
            program.deliver_facilitation_messages_v2
          end
          mail = ActionMailer::Base.deliveries.last
          assert_equal group.students.map(&:email), mail.to
          assert_equal "At 7th day -2 UTC time zone - #{group.name}", mail.subject
          assert_match "day 7 -2 UTC message", get_html_part_from(mail)
        elsif day == 9
          assert_difference "ActionMailer::Base.deliveries.size", 1 do
            program.deliver_facilitation_messages_v2
          end
          mails = ActionMailer::Base.deliveries.last(1)
          assert_equal group.students.map(&:email), mails[0].to
          assert_equal "At 9th day - #{group.name}", mails[0].subject
          assert_match "day 9 message", get_html_part_from(mails[0])
        end
      else
        assert_no_difference "ActionMailer::Base.deliveries.size" do
          program.deliver_facilitation_messages_v2
        end if day != 3
      end
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        program.deliver_facilitation_messages_v2
      end if day != 3
      Timecop.return
    end
  end

  def test_has_many_surveys
    survey_1 = create_program_survey(:program => programs(:ceg))
    survey_2 = create_program_survey(:program => programs(:ceg))

    # Assert that survey_2, survey_1 are in programs(:ceg).surveys
    assert ([survey_2, survey_1] - programs(:ceg).surveys.reload).blank?
  end

  def test_has_many_and_dependent_destroy
    program = programs(:albers)
    organization = program.organization
    resource_publications = []
    resource_publications << create_resource_publication
    resource_publications << create_resource_publication
    assert_equal 8, program.resource_publications.count
    assert_equal 2, program.program_languages.count

    albers_users_count = program.all_users.count
    albers_surveys_count = program.surveys.count
    albers_scraps_count = program.scraps.count
    assert_equal 8, program.meeting_requests.count
    create_meeting(force_non_time_meeting: true)
    assert_equal 9, program.reload.meeting_requests.count

    Organization.any_instance.stubs(:programs).returns([programs(:nwen)])
    suspended_member_ids = program.organization.members.suspended.pluck(:id)
    Member.expects(:transition_global_suspensions_to_program).with(suspended_member_ids).once
    Organization.expects(:transition_global_objects_to_standalone_program).with(program.parent_id).once
    Organization.expects(:transition_standalone_program_objects_to_organization).with(program.parent_id).once

    assert_difference "MeetingRequest.count",-9  do
      assert_difference 'Role.count', -program.roles.count do
        assert_difference "Announcement.count", -4 do
          assert_difference("User.count", -albers_users_count) do
            assert_difference 'Survey.count', -albers_surveys_count do
              assert_difference 'Scrap.count', -albers_scraps_count do
                assert_difference "Meeting.count", -8 do
                  assert_difference "ResourcePublication.count", -8 do
                    assert_difference "MentoringModel.count", -1 do
                      assert_difference "Feedback::Form.count", -1 do
                        assert_difference "ProgramLanguage.count", -2 do
                          assert_difference "UserSearchActivity.count", -3 do
                            program.destroy
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def test_find_invitation
    ProgramInvitation.destroy_all
    assert_false programs(:albers).find_invitation("ABCDEFGH")
    invite = ProgramInvitation.create!(
      :sent_to => 'abc@chronus.com',
      :user => users(:f_admin),
      :program => programs(:albers),
      :role_names => [RoleConstants::MENTOR_NAME],
      :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE,
      :message => 'some message')

    code = invite.code
    assert_equal invite, programs(:albers).find_invitation(code)
    assert_false programs(:albers).find_invitation(nil)
    invite.update_attribute(:expires_on, 1.day.ago)
    assert_false programs(:albers).find_invitation(code)
  end

  def test_has_many_membership_questions_sorted_by_position
    programs(:foster).organization.profile_questions.destroy_all
    programs(:ceg).organization.profile_questions.destroy_all
    programs(:foster).role_questions.each do |rq|
     rq.destroy
    end

    programs(:ceg).role_questions.each do |rq|
     rq.destroy
    end
    q1 = create_membership_profile_question(:program => programs(:foster))
    q2 = create_membership_profile_question(:program => programs(:foster))
    q3 = create_membership_profile_question(:program => programs(:foster))
    q4 = create_membership_profile_question(:program => programs(:ceg))

    assert_equal [q1, q2, q3], programs(:foster).role_questions.membership_questions.collect(&:profile_question).uniq.sort_by(&:position)
    assert_equal [q4], programs(:ceg).role_questions.membership_questions.collect(&:profile_question).uniq.sort_by(&:position)

    # Move q1 to the end
    q1.insert_at(10000)
    assert_equal [q2, q3, q1], programs(:foster).role_questions.membership_questions.collect(&:profile_question).uniq.sort_by(&:position)
  end

  def test_membership_questions_for_role
    org = programs(:org_primary)
    program = programs(:albers)
    admin_only_question = profile_questions(:profile_questions_4)
    program.role_questions.update_all(available_for: RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)
    mentoring_profile_section = org.sections.find_by(title: "Mentoring Profile")

    mentor_question_1 = create_membership_profile_question(question_text: 'Hello', section: mentoring_profile_section)
    mentor_question_2 = create_membership_profile_question(question_text: 'World')
    student_question_1 = create_membership_profile_question(question_text: 'Hello', role_names: [RoleConstants::STUDENT_NAME], section: mentoring_profile_section)
    student_question_2 = create_membership_profile_question(question_text: 'Land', role_names: [RoleConstants::STUDENT_NAME])

    assert_equal [mentor_question_2, mentor_question_1], program.membership_questions_for([RoleConstants::MENTOR_NAME])
    assert_equal [student_question_2, student_question_1], program.membership_questions_for([RoleConstants::STUDENT_NAME])
    assert_empty program.membership_questions_for([RoleConstants::ADMIN_NAME])

    admin_only_question.role_questions.update_all(admin_only_editable: true)
    assert_equal [admin_only_question, mentor_question_2, mentor_question_1], program.membership_questions_for([RoleConstants::MENTOR_NAME], include_admin_only_editable: true)
    assert_equal [admin_only_question, student_question_2, student_question_1], program.membership_questions_for([RoleConstants::STUDENT_NAME], include_admin_only_editable: true)
    assert_empty program.membership_questions_for([RoleConstants::ADMIN_NAME], include_admin_only_editable: true)
  end

  def test_all_users
    program = programs(:albers)
    assert_equal_unordered program.users, program.all_users
  end

  def test_role_users
    user_1 = create_user(:last_name => 'abc')
    user_2 = create_user(:last_name => 'xyz')

    create_role(:name => 'manager', :program => programs(:albers))
    create_role(:name => 'general_manager', :program => programs(:albers))
    programs(:albers).roles.reload
    user_1.add_role('manager')
    user_2.add_role('manager')
    user_2.add_role('general_manager')
    assert_equal [user_1, user_2], programs(:albers).manager_users
    assert_equal [user_2], programs(:albers).general_manager_users
  end

  def test_role_permission
    p = programs(:albers)

    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
    assert_difference 'RolePermission.count' do
      p.add_role_permission(RoleConstants::STUDENT_NAME, "write_article")
    end
    assert p.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")

    assert_difference 'RolePermission.count', -1 do
      p.remove_role_permission(RoleConstants::STUDENT_NAME, "write_article")
    end
    assert_false p.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
  end

  def test_create_default_roles
    programs(:no_subdomain).roles.destroy_all

    # 3 roles per program
    assert_difference 'Role.count', 3 do
      # 5 RolePermission mappings per program
      assert_difference 'RolePermission.count', 68 do
        programs(:no_subdomain).create_default_roles
      end
    end
  end

  def test_build_default_roles
    program = programs(:no_subdomain)
    program.roles.destroy_all

    assert_equal [], program.roles

    assert_no_difference 'Role.count' do
      assert_no_difference 'RolePermission.count' do
        program.build_default_roles
      end
    end
    assert_equal RoleConstants::DEFAULT_ROLE_NAMES, program.roles.collect(&:name)
  end

  def test_create_role
    assert_difference 'Role.count', 1 do
      assert_difference 'RolePermission.count', 1 do
        programs(:albers).create_role(RoleConstants::BOARD_OF_ADVISOR_NAME)
      end
    end
  end

  def test_searchable_classes
    assert_equal [User, QaQuestion, Article, Resource, Topic],
      programs(:albers).searchable_classes(users(:f_student))

    programs(:org_primary).enable_feature(FeatureName::ARTICLES, false)
    programs(:albers).reload
    assert_equal [User, QaQuestion, Resource, Topic],
      programs(:albers).searchable_classes(users(:f_student))

    programs(:org_primary).enable_feature(FeatureName::ANSWERS, false)
    programs(:albers).reload
    assert_equal [User, Resource, Topic],
      programs(:albers).searchable_classes(users(:f_student))

    programs(:albers).organization.enable_feature(FeatureName::ARTICLES)
    programs(:org_primary).reload
    programs(:albers).reload
    remove_role_permission(fetch_role(:albers, :student), 'view_articles')
    assert_equal [User, Resource, Topic], programs(:albers).searchable_classes(users(:f_student).reload)

    programs(:org_primary).enable_feature(FeatureName::ANSWERS)
    programs(:org_primary).reload
    programs(:albers).reload
    assert programs(:org_primary).has_feature?(FeatureName::ANSWERS)
    add_role_permission(fetch_role(:albers, :student), 'view_articles')
    remove_role_permission(fetch_role(:albers, :student), 'view_questions')
    assert_equal [User, Article, Resource, Topic],
      programs(:albers).searchable_classes(users(:f_student).reload)

    add_role_permission(fetch_role(:albers, :student), 'view_questions')
    remove_role_permission(fetch_role(:albers, :student), 'view_students')
    assert programs(:org_primary).has_feature?(FeatureName::ANSWERS)

    # Should still fetch mentors.
    assert_equal [User, QaQuestion, Article, Resource, Topic],
      programs(:albers).searchable_classes(users(:f_student).reload)

    remove_role_permission(fetch_role(:albers, :student), 'view_mentors')
    # No users now.
    assert_equal [QaQuestion, Article, Resource, Topic],
      programs(:albers).searchable_classes(users(:f_student).reload)

    # Nothing to search.
    remove_role_permission(fetch_role(:albers, :student), 'view_questions')
    remove_role_permission(fetch_role(:albers, :student), 'view_articles')
    programs(:albers).enable_feature(FeatureName::RESOURCES, false)
    programs(:albers).enable_feature(FeatureName::FORUMS, false)
    assert programs(:albers).searchable_classes(users(:f_student).reload).empty?
  end

  def test_articles_enabled
    assert programs(:albers).articles_enabled?
    programs(:albers).enable_feature(FeatureName::ARTICLES, false).reload
    assert_false programs(:albers).articles_enabled?
  end

  def test_qa_enabled
    assert programs(:albers).qa_enabled?
    programs(:albers).enable_feature(FeatureName::ANSWERS, false).reload
    assert_false programs(:albers).qa_enabled?
  end

  def test_forums_enabled
    assert programs(:albers).forums_enabled?
    programs(:albers).enable_feature(FeatureName::FORUMS, false).reload
    assert_false programs(:albers).forums_enabled?
  end

  def test_inactivity_tracking_period_in_days
    p = programs(:albers)
    p.inactivity_tracking_period_in_days = 180
    assert_equal(180.days, p.inactivity_tracking_period)
    assert_equal(180, p.inactivity_tracking_period_in_days)

    p.inactivity_tracking_period_in_days = 7
    assert_equal(7.days, p.inactivity_tracking_period)
    assert_equal(7, p.inactivity_tracking_period_in_days)

    p.inactivity_tracking_period = 60.days
    assert_equal(60.days, p.inactivity_tracking_period)
    assert_equal(60, p.inactivity_tracking_period_in_days)

    p.inactivity_tracking_period_in_days = nil
    assert_nil p.inactivity_tracking_period

    assert_nil p.auto_terminate_reason_id
  end

  def test_has_many_scraps
    s = create_scrap(:content => "scrap message content", :group => groups(:mygroup),  :sender => members(:f_mentor))
    assert programs(:albers).scraps.include?(s)
    groups(:mygroup).terminate!(users(:f_admin), 'hello', groups(:mygroup).program.permitted_closure_reasons.first.id)
    assert groups(:mygroup).closed?
    assert programs(:albers).scraps.include?(s)
  end

  def test_connection_feedack_enabled
    programs(:albers).update_attribute :inactivity_tracking_period, nil
    assert_false programs(:albers).connection_feedback_enabled?
    programs(:albers).update_attribute :inactivity_tracking_period, 30.days
    assert programs(:albers).connection_feedback_enabled?
    programs(:albers).update_attribute :inactivity_tracking_period, nil
    assert_false programs(:albers).connection_feedback_enabled?
  end

  def test_mentor_request_style_validations
    program = Program.new
    assert_equal Program::MentorRequestStyle::NONE, program.mentor_request_style
    program = programs(:albers)
    assert program.valid?
    program.mentor_request_style = nil
    assert_false program.valid?
    assert "can't be blank", program.errors[:mentor_request_style]
  end

  def test_matching_style_1
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, programs(:albers).mentor_request_style
    assert programs(:albers).matching_by_mentee_alone?
  end

  def test_matching_style_2
    assert_equal Program::MentorRequestStyle::MENTEE_TO_ADMIN, programs(:moderated_program).mentor_request_style
    assert programs(:moderated_program).matching_by_mentee_and_admin?
  end

  def test_matching_style_3
    assert_equal Program::MentorRequestStyle::NONE, programs(:no_mentor_request_program).mentor_request_style
    assert programs(:no_mentor_request_program).matching_by_admin_alone?
  end

  def test_slot_config_required
    program = programs(:albers)
    Role.any_instance.stubs(:slot_config_required?).returns(true)
    program.roles.all? { |role| assert_false program.is_slot_config_required_for?(role) }

    Role.any_instance.stubs(:slot_config_required?).returns(false)
    program.roles.each { |role| assert_false program.is_slot_config_required_for?(role) }

    program = programs(:pbe)
    Role.any_instance.stubs(:slot_config_required?).returns(true)
    assert program.roles.all? { |role| program.is_slot_config_required_for?(role) }

    Role.any_instance.stubs(:slot_config_required?).returns(false)
    program.roles.all? { |role| assert_false program.is_slot_config_required_for?(role) }
  end

  def test_slot_config_optional
    program = programs(:albers)
    Role.any_instance.stubs(:slot_config_optional?).returns(true)
    program.roles.all? { |role| assert_false program.is_slot_config_optional_for?(role) }

    Role.any_instance.stubs(:slot_config_optional?).returns(false)
    program.roles.all? { |role| assert_false program.is_slot_config_optional_for?(role) }

    program = programs(:pbe)
    Role.any_instance.stubs(:slot_config_optional?).returns(true)
    assert program.roles.all? { |role| program.is_slot_config_optional_for?(role) }

    Role.any_instance.stubs(:slot_config_optional?).returns(false)
    program.roles.all? { |role| assert_false program.is_slot_config_optional_for?(role) }
  end

  def test_slot_config_enabled
    program = programs(:albers)
    Role.any_instance.stubs(:slot_config_enabled?).returns(true)
    program.roles.all? { |role| assert_false program.is_slot_config_enabled_for?(role) }

    Role.any_instance.stubs(:slot_config_enabled?).returns(false)
    program.roles.all? { |role| assert_false program.is_slot_config_enabled_for?(role) }

    program = programs(:pbe)
    Role.any_instance.stubs(:slot_config_enabled?).returns(true)
    assert program.roles.all? { |role| program.is_slot_config_enabled_for?(role) }

    Role.any_instance.stubs(:slot_config_enabled?).returns(false)
    program.roles.all? { |role| assert_false program.is_slot_config_enabled_for?(role) }

    Role.any_instance.stubs(:slot_config_enabled?).returns(true)
    assert program.slot_config_enabled?

    Role.any_instance.stubs(:slot_config_enabled?).returns(false)
    assert_false program.slot_config_enabled?
  end

  def test_additional_admins
    assert_equal [users(:f_admin), users(:ram)], programs(:albers).admin_users
    assert_equal [users(:ram)], programs(:albers).additional_admins
  end

  def test_active_admins_except_mentor_admins
    admin_user = users(:no_subdomain_admin)
    program = admin_user.program
    assert_equal [admin_user], program.active_admins_except_mentor_admins

    admin_user.member.update_attribute(:email, SUPERADMIN_EMAIL)
    assert_empty program.reload.active_admins_except_mentor_admins
  end

  def test_program_forums_with_role
    group = groups(:mygroup)
    program = group.program
    group_forum = create_forum(group_id: group.id)

    assert group_forum.in?(program.forums)
    assert_equal_unordered [forums(:forums_2), forums(:common_forum)], program.program_forums_with_role(RoleConstants::MENTOR_NAME)
    assert_equal_unordered [forums(:forums_1), forums(:common_forum)], program.program_forums_with_role(RoleConstants::STUDENT_NAME)
    assert_equal_unordered [forums(:forums_1), forums(:forums_2), forums(:common_forum)], program.program_forums_with_role("all")
  end

  def test_notify_added_mentor_user
    user = users(:f_mentor)
    added_by = users(:f_admin)
    ChronusMailer.expects(:mentor_added_notification).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, added_by)
  end

  def test_notify_added_admin
    user = users(:f_admin)
    ChronusMailer.expects(:admin_added_directly_notification).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, user)
  end

  def test_notify_added_student_user
    user = users(:f_student)
    added_by = users(:f_admin)
    ChronusMailer.expects(:mentee_added_notification).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, added_by)
  end

  def test_notify_added_mentor_student_user
    user = users(:f_mentor_student)

    added_by = users(:f_admin)
    ChronusMailer.expects(:user_with_set_of_roles_added_notification).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, added_by)
  end

  def test_notify_custom_role_added
    user = users(:f_user)

    added_by = users(:f_admin)
    ChronusMailer.expects(:user_with_set_of_roles_added_notification).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, added_by)
  end

  def test_allowing_membership_requests
    p = programs(:albers)
    program_counts = Program.allowing_membership_requests.size
    assert Program.allowing_membership_requests.include?(p)
    mentor_role = p.find_role('mentor')
    mentor_role.membership_request = false
    mentor_role.save
    mentee_role = p.find_role('student')
    mentee_role.membership_request = false
    mentee_role.save
    assert_false Program.allowing_membership_requests.include?(p)
    programs_allowing_membership_requests = Program.allowing_membership_requests
    assert_equal program_counts - 1 , programs_allowing_membership_requests.reload.size
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert Program.allowing_membership_requests.include?(p)
    programs_allowing_membership_requests = Program.allowing_membership_requests
    assert_equal program_counts , programs_allowing_membership_requests.reload.size
  end

  def test_has_membership_requests
    p = programs(:albers)
    p.membership_requests.each do |memreq|
      memreq.destroy!
    end
    assert p.has_membership_requests?
    mentor_role = p.find_role('mentor')
    mentor_role.membership_request = false
    mentor_role.save
    assert p.has_membership_requests?
    mentee_role = p.find_role('student')
    mentee_role.membership_request = false
    mentee_role.save

    assert_false p.has_membership_requests?
    mentee_role.join_directly = true
    mentee_role.save
    assert_false p.has_membership_requests?
    mentee_role.join_directly = false
    mentee_role.join_directly_only_with_sso = true
    mentee_role.save
    assert_false p.has_membership_requests?
    create_membership_request
    assert p.has_membership_requests?
  end

  def test_in_organization_scope
    assert_equal_unordered programs(:org_primary).programs, Program.in_organization(programs(:org_primary))
  end

  def test_published_scope
    assert_equal_unordered programs(:org_primary).programs, programs(:org_primary).programs.published_programs
  end

  def test_members_in_connections
    program = programs(:albers)
    connection_ids = "some ids"
    Connection::Membership.stubs(:user_ids_in_groups).with(connection_ids, program, "some type").returns([users(:f_admin).id])
    assert_equal_unordered [members(:f_admin)], program.members_in_connections(connection_ids, "some type")
  end

  def test_activate_default_theme
    programs(:albers).update_attributes(theme_id: nil)
    assert_nil programs(:albers).active_theme
    programs(:albers).assign_default_theme
    assert_equal themes(:wcag_theme), programs(:albers).active_theme
  end

  def test_active_scope
    assert programs(:albers).active?

    programs(:org_primary).active = false
    programs(:org_primary).save!

    assert_false programs(:albers).reload.active?

    assert_false Program.active.include?(programs(:albers))
    assert Program.active.include?(programs(:foster))
  end

  def test_named_scope_role_questions_for
    program = programs(:albers)
    mentor_role = program.get_role(RoleConstants::MENTOR_NAME)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)
    mentor_questions = program.role_questions.select{|q| q.role==mentor_role}
    student_questions = program.role_questions.select{|q| q.role==student_role}
    assert_equal_unordered mentor_questions, program.role_questions_for([RoleConstants::MENTOR_NAME])
    assert_equal_unordered student_questions, program.role_questions_for([RoleConstants::STUDENT_NAME])
    assert_equal_unordered [mentor_questions, student_questions].flatten, program.role_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_equal [], program.role_questions_for([])
  end

  def test_named_scope_profile_questions_for
    program = programs(:albers)
    mentor_role = program.get_role(RoleConstants::MENTOR_NAME)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)
    mentor_questions = program.role_questions.select{|q| q.role==mentor_role}.collect(&:profile_question)
    student_questions = program.role_questions.select{|q| q.role==student_role}.collect(&:profile_question)
    assert_equal_unordered mentor_questions, program.profile_questions_for([RoleConstants::MENTOR_NAME])
    assert_equal_unordered student_questions, program.profile_questions_for([RoleConstants::STUDENT_NAME])
    assert_equal_unordered [mentor_questions, student_questions].flatten.uniq, program.profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_equal [], program.profile_questions_for([])
  end

  def test_named_scope_profile_questions_for_options
    program = programs(:albers)
    name_question = programs(:org_primary).profile_questions_with_email_and_name.select{|q| q.name_type?}[0]
    email_question = programs(:org_primary).profile_questions_with_email_and_name.select{|q| q.email_type?}[0]
    skype_question = programs(:org_primary).profile_questions_with_email_and_name.select{|q| q.skype_id_type?}[0]
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME]).include?(email_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME]).include?(name_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => true}).include?(email_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => true}).include?(name_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => true, eager_loaded: true}).include?(email_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => true, eager_loaded: true}).include?(name_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], {:skype => true}).include?(skype_question)
    assert !program.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => false}).include?(email_question)
    assert !program.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => false}).include?(name_question)
    assert !program.profile_questions_for([RoleConstants::MENTOR_NAME], {:skype => false}).include?(skype_question)

    membership_profile_question = profile_questions(:single_choice_q)
    membership_profile_question.role_questions.destroy_all
    assert !program.profile_questions_for([RoleConstants::MENTOR_NAME], {skype: false, all_role_questions: true}).include?(membership_profile_question)
    create_role_question(program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME], profile_question: membership_profile_question, available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], {skype: false, all_role_questions: true}).include?(membership_profile_question)
  end

  def test_named_scope_sections_for
    program = programs(:albers)
    mentor_role = program.get_role(RoleConstants::MENTOR_NAME)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)
    mentor_questions = program.role_questions.select{|q| q.role==mentor_role}.collect(&:profile_question)
    student_questions = program.role_questions.select{|q| q.role==student_role}.collect(&:profile_question)
    assert_equal_unordered mentor_questions.collect(&:section).uniq, program.sections_for([RoleConstants::MENTOR_NAME])
    assert_equal_unordered student_questions.collect(&:section).uniq, program.sections_for([RoleConstants::STUDENT_NAME])
    assert_equal_unordered [mentor_questions, student_questions].flatten.uniq.collect(&:section).uniq, program.sections_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_equal [], program.sections_for([])
  end

  def test_default_role_names
    assert_equal [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], programs(:albers).default_role_names
  end

  def test_default_survey_types
    assert_equal [Survey::Type::PROGRAM, Survey::Type::ENGAGEMENT], programs(:albers).default_survey_types
  end

  def test_required_profile_questions_except_default_for
    program = programs(:albers)
    name_question = programs(:org_primary).profile_questions_with_email_and_name.select{|q| q.name_type?}[0]
    email_question = programs(:org_primary).profile_questions_with_email_and_name.select{|q| q.email_type?}[0]
    single_choice_role_q = role_questions(:single_choice_role_q) #Mentor Role
    single_choice_role_q.required = true
    single_choice_role_q.save!

    assert_false program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME]).include?(email_question)
    assert_false program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME]).include?(name_question)
    assert program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME]).include?(profile_questions(:single_choice_q))
    assert_false program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME]).include?(profile_questions(:string_q))

    assert_false program.required_profile_questions_except_default_for([RoleConstants::STUDENT_NAME]).include?(email_question)
    assert_false program.required_profile_questions_except_default_for([RoleConstants::STUDENT_NAME]).include?(name_question)
    assert_false program.required_profile_questions_except_default_for([RoleConstants::STUDENT_NAME]).include?(profile_questions(:single_choice_q))
    assert_false program.required_profile_questions_except_default_for([RoleConstants::STUDENT_NAME]).include?(profile_questions(:string_q))

    assert_false program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).include?(email_question)
    assert_false program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).include?(name_question)
    assert program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).include?(profile_questions(:single_choice_q))
    assert_false program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).include?(profile_questions(:string_q))
  end

  def test_make_subscription_changes
    org = programs(:org_anna_univ)
    prog = org.programs.first
    #Premium subscription- Default
    assert prog.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")
    assert prog.allow_mentoring_requests
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, prog.mentor_request_style
    assert_equal 2592000, prog.inactivity_tracking_period

    #Basic subscription
    org.update_attribute(:subscription_type, Organization::SubscriptionType::BASIC)
    org.make_subscription_changes
    prog.make_subscription_changes
    assert prog.reload.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")
    assert prog.allow_mentoring_requests
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, prog.mentor_request_style
    assert_equal 2592000, prog.inactivity_tracking_period

    #Enterprise subscription
    org.update_attribute(:subscription_type, Organization::SubscriptionType::ENTERPRISE)
    org.reload.make_subscription_changes
    prog.make_subscription_changes
    assert prog.reload.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")
    assert prog.allow_mentoring_requests
    assert_equal 2592000, prog.inactivity_tracking_period
  end

  def test_subscription_type_basic
    org = programs(:org_anna_univ)
    org.update_attribute(:subscription_type, Organization::SubscriptionType::BASIC)
    org.make_subscription_changes
    prog = Program.create!(:name => "good", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "Willfull", :organization => org)
    assert prog.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")

    assert prog.allow_mentoring_requests
    assert_equal Program::MentorRequestStyle::NONE, prog.mentor_request_style
    assert_equal 2592000, prog.inactivity_tracking_period
  end

  def test_subscription_type_premium
    org = programs(:org_anna_univ)
    org.update_attribute(:subscription_type, Organization::SubscriptionType::PREMIUM)
    org.make_subscription_changes
    prog = Program.create!(:name => "good", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "Willfull", :organization => org)
    assert prog.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")
    assert prog.allow_mentoring_requests
    assert_equal 2592000, prog.inactivity_tracking_period
  end

  def test_subscription_type_enterprise
    org = programs(:org_anna_univ)
    org.update_attribute(:subscription_type, Organization::SubscriptionType::ENTERPRISE)
    org.make_subscription_changes
    prog = Program.create!(:name => "good", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "Willfull", :organization => org)
    assert prog.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")
    assert prog.allow_mentoring_requests
    assert_equal 2592000, prog.inactivity_tracking_period
  end

  def test_update_permissions_content_related
    prog = programs(:albers)
    assert_false prog.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
    programs(:albers).update_permissions(Program::Permissions::PUBLISH_ARTICLES[0][:label])
    assert prog.reload.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
    programs(:albers).update_permissions([])
    assert_false prog.reload.has_role_permission?(RoleConstants::STUDENT_NAME, "write_article")
  end

  def test_invoke_feature_dependancy
    prog = programs(:albers)

    assert_difference "RolePermission.count" do
      prog.invoke_feature_dependancy_offer_mentoring(true)
    end
    assert prog.reload.has_role_permission?(RoleConstants::MENTOR_NAME, "offer_mentoring")

    assert_difference "RolePermission.count", -1 do
      prog.invoke_feature_dependancy_offer_mentoring(false)
    end
    assert_false prog.reload.has_role_permission?(RoleConstants::MENTOR_NAME, "offer_mentoring")
  end

  def test_email_template_disabled_for_activity
    org = programs(:org_primary)
    prog = programs(:albers)
    mailer = AdminWeeklyStatus
    uid = mailer.mailer_attributes[:uid]

    t1 = mailer.org_template(org)
    t2 = mailer.prog_template(prog)
    assert t1.nil?
    assert t2.nil?
    assert_false prog.email_template_disabled_for_activity?(mailer)

    t1 = org.mailer_templates.create!(:uid => uid, :enabled => false)
    assert_false t1.enabled?
    assert prog.reload.email_template_disabled_for_activity?(mailer)

    t1.update_attributes!(:enabled => true)
    assert t1.enabled?
    assert_false prog.reload.email_template_disabled_for_activity?(mailer)

    t2 = prog.mailer_templates.create!(:uid => uid, :enabled => false)
    assert t1.enabled?
    assert_false t2.enabled?
    assert prog.reload.email_template_disabled_for_activity?(mailer)

    t2.update_attributes!(:enabled => true)
    assert t1.enabled?
    assert t2.enabled?
    assert_false prog.reload.email_template_disabled_for_activity?(mailer)
  end

  def test_enabled_features_and_disabled_features
    assert programs(:org_primary).enabled_features.include?(FeatureName::ARTICLES)
    assert programs(:albers).enabled_features.include?(FeatureName::ARTICLES)

    programs(:org_primary).enable_feature(FeatureName::ARTICLES, false)
    assert_false programs(:org_primary).enabled_features.include?(FeatureName::ARTICLES)
    assert_false programs(:albers).reload.enabled_features.include?(FeatureName::ARTICLES)
    assert programs(:org_primary).disabled_features.include?(FeatureName::ARTICLES)
    assert programs(:albers).disabled_features.include?(FeatureName::ARTICLES)

    programs(:albers).enable_feature(FeatureName::ARTICLES)
    assert_false programs(:org_primary).enabled_features.include?(FeatureName::ARTICLES)
    assert programs(:albers).reload.enabled_features.include?(FeatureName::ARTICLES)
    assert programs(:org_primary).disabled_features.include?(FeatureName::ARTICLES)

    assert_false programs(:nwen).enabled_features.include?(FeatureName::ARTICLES)
    programs(:nwen).enable_feature(FeatureName::ARTICLES)
    assert programs(:nwen).reload.enabled_features.include?(FeatureName::ARTICLES)
    assert_false programs(:org_primary).enabled_features.include?(FeatureName::ARTICLES)
    assert programs(:org_primary).disabled_features.include?(FeatureName::ARTICLES)
  end

  def test_enabled_disabled_features_ignore_organization_level_features
    program = programs(:albers)
    organization = program.organization

    organization.enable_feature(FeatureName::MANAGER)
    assert organization.reload.enabled_features.include?(FeatureName::MANAGER)
    assert_false organization.disabled_features.include?(FeatureName::MANAGER)
    assert program.reload.enabled_features.include?(FeatureName::MANAGER)
    assert_false program.disabled_features.include?(FeatureName::MANAGER)

    program.enable_feature(FeatureName::MANAGER, false)
    assert program.reload.enabled_features.include?(FeatureName::MANAGER)
    assert_false program.disabled_features.include?(FeatureName::MANAGER)
  end

  def test_has_feature
    assert programs(:org_primary).has_feature?(FeatureName::ARTICLES)
    assert programs(:albers).has_feature?(FeatureName::ARTICLES)

    programs(:org_primary).enable_feature(FeatureName::ARTICLES, false)
    assert_false programs(:org_primary).has_feature?(FeatureName::ARTICLES)
    assert_false programs(:albers).reload.has_feature?(FeatureName::ARTICLES)

    programs(:albers).enable_feature(FeatureName::ARTICLES)
    assert_false programs(:org_primary).has_feature?(FeatureName::ARTICLES)
    assert programs(:albers).reload.has_feature?(FeatureName::ARTICLES)

    assert_false programs(:nwen).has_feature?(FeatureName::ARTICLES)
    programs(:nwen).enable_feature(FeatureName::ARTICLES)
    assert programs(:nwen).reload.has_feature?(FeatureName::ARTICLES)
    assert_false programs(:org_primary).has_feature?(FeatureName::ARTICLES)
  end

  def test_has_many_features_should_include_only_enabled_ones
    programs(:albers).enable_feature(FeatureName::ARTICLES, false)
    assert_false programs(:albers).enabled_db_features.collect(&:name).include?(FeatureName::ARTICLES)

    assert_no_difference "OrganizationFeature.count" do
      programs(:albers).enable_feature(FeatureName::ARTICLES)
    end

    assert programs(:albers).enabled_db_features.collect(&:name).include?(FeatureName::ARTICLES)
  end

  def test_forum_moderation_enabled
    programs(:org_primary).enable_feature(FeatureName::MODERATE_FORUMS)
    assert programs(:org_primary).has_feature?(FeatureName::MODERATE_FORUMS)
    assert programs(:albers).moderation_enabled?

    programs(:albers).enable_feature(FeatureName::MODERATE_FORUMS, false)
    assert_false programs(:albers).moderation_enabled?
    assert programs(:org_primary).has_feature?(FeatureName::MODERATE_FORUMS)

    programs(:albers).enable_feature(FeatureName::MODERATE_FORUMS)
    assert programs(:org_primary).has_feature?(FeatureName::MODERATE_FORUMS)
    assert programs(:albers).moderation_enabled?
  end

  def test_create_default_admin_views_and_default
    program = programs(:albers)

    assert_difference "AdminViewColumn.count", -167 do
      assert_difference "AdminView.count", -17 do
        program.admin_views.destroy_all
      end
    end

    assert_equal [], programs(:albers).admin_views.default

    assert_difference "AdminViewColumn.count", 37 do
      assert_difference "AdminView.count", 4 do
        program.reload.create_default_admin_views
      end
    end

    assert_difference "AdminView.count", 13 do
      program.create_default_abstract_views_for_program_management_report
    end

    assert_equal_unordered ["All Users", 
      "All Administrators", 
      "All Mentors", 
      "All Students", 
      "Application Accepted, Awaiting Signup",
      "Never Connected Students", 
      "Currently Unconnected Students", 
      "Users With Low Profile Scores", 
      "Registered Mentors with Unpublished Profiles", 
      "Registered Students with Unpublished Profiles", 
      "Mentors With Low Profile Scores", 
      "Students With Low Profile Scores", 
      "Never Connected Mentors", 
      "Mentors With Pending Mentoring Requests", 
      "Students Who Sent Mentoring Request But Not Connected", 
      "Students Who Haven't Sent Mentoring Request", "Available Mentors"], programs(:albers).admin_views.default.collect(&:title)
    assert_equal_unordered ["All Users", "All Mentors", "All Students", "All Administrators"], programs(:albers).admin_views.default.where(favourite: true).pluck(:title)

    assert_equal_unordered program.admin_views.collect(&:id), program.admin_views.default.collect(&:id)
    assert_equal programs(:org_anna_univ).admin_views.first.favourite, true
  end

  def test_create_default_admin_views_and_default_with_same_view
    program = programs(:albers)
    all_users_view = program.admin_views.where(title: "All Users").first
    all_users_view.update_attribute(:title, "All People")

    low_profile_users = program.admin_views.where(title: "Mentors With Low Profile Scores").first
    program.admin_views.where(default_view: AbstractView::DefaultType::MENTORS).first.destroy
    low_profile_users.update_attribute(:default_view, AbstractView::DefaultType::MENTORS)

    all_admins = program.admin_views.where(title: "All Administrators").first

    all_views = program.admin_views
    (all_views - [all_users_view, low_profile_users, all_admins]).each do |av|
      av.destroy
    end

    assert_difference "AdminViewColumn.count", 10 do
      assert_difference "AdminView.count", 1 do
        program.reload.create_default_admin_views
      end
    end

    assert_equal low_profile_users, program.admin_views.where(default_view: AbstractView::DefaultType::MENTORS).first

    assert_difference "AdminView.count", 12 do
      program.create_default_abstract_views_for_program_management_report
    end

    assert_equal all_admins, program.admin_views.where(title: "All Administrators").first
    assert_nil program.admin_views.where(default_view: AbstractView::DefaultType::MENTORS).first
  end

  def test_profile_questions_for_admin_user
    program = programs(:albers)
    profile_question = profile_questions(:multi_experience_q)
    role_question = profile_question.role_questions[0]
    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_question.reload
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)
    assert_false program.profile_questions_for([RoleConstants::MENTOR_NAME]).include?(profile_question)
    assert_false program.profile_questions_for([RoleConstants::MENTOR_NAME], user: mentor_user).include?(profile_question)
    assert_false program.profile_questions_for([RoleConstants::MENTOR_NAME], eager_loaded: true).include?(profile_question)
    assert_false program.profile_questions_for([RoleConstants::MENTOR_NAME], user: mentor_user, eager_loaded: true).include?(profile_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], user: admin_user).include?(profile_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).include?(profile_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], user: admin_user, eager_loaded: true).include?(profile_question)
    assert program.profile_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true, eager_loaded: true).include?(profile_question)
  end

  def test_role_questions_for_admin_user
    program = programs(:albers)
    profile_question = profile_questions(:multi_experience_q)
    role_question = profile_question.role_questions[0]
    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_question.reload
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)
    assert_false program.role_questions_for([RoleConstants::MENTOR_NAME]).include?(role_question)
    assert_false program.role_questions_for([RoleConstants::MENTOR_NAME], user: mentor_user).include?(role_question)
    assert program.role_questions_for([RoleConstants::MENTOR_NAME], user: admin_user).include?(role_question)
    assert program.role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).include?(role_question)

    assert_false program.role_questions_for([RoleConstants::MENTOR_NAME], eager_loaded: true).include?(role_question)
    assert_false program.role_questions_for([RoleConstants::MENTOR_NAME], user: mentor_user, eager_loaded: true).include?(role_question)
    assert program.role_questions_for([RoleConstants::MENTOR_NAME], user: admin_user, eager_loaded: true).include?(role_question)
    assert program.role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true, eager_loaded: true).include?(role_question)
  end

  def test_role_profile_questions_excluding_name_type
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)
    program = programs(:albers)
    name_question = programs(:org_primary).name_question.role_questions[0]
    email_question = programs(:org_primary).email_question.role_questions[0]

    profile_question = profile_questions(:multi_experience_q)
    role_question = profile_question.role_questions[0]
    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_question.reload

    profile_question2 = profile_questions(:string_q)
    role_question2 = profile_question2.role_questions[0]
    role_question2.update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    role_question2.reload

    assert_false program.role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], mentor_user).include?(role_question)
    assert_false program.role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], mentor_user).include?(role_question2)
    assert_false program.role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], mentor_user).include?(name_question)

    assert program.role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).include?(role_question)
    assert_false program.role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).include?(role_question2)
    assert_false program.role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).include?(name_question)
    assert program.role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).include?(email_question)
  end

  def test_in_summary_role_profile_questions_excluding_name_type
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)
    program = programs(:albers)
    default_question_ids = programs(:org_primary).default_questions.pluck(:id)

    profile_question = profile_questions(:multi_experience_q)
    role_question = profile_question.role_questions.first
    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ALL)
    role_question.update_attribute(:in_summary, true)
    role_question.reload

    profile_question2 = profile_questions(:string_q)
    role_question2 = profile_question2.role_questions.first
    role_question2.update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    role_question2.reload

    assert program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], mentor_user).include?(role_question)
    assert_false program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], mentor_user).include?(role_question2)
    assert_false (program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], mentor_user).collect(&:id) & default_question_ids).any?

    assert program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).include?(role_question)
    assert_false program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).include?(role_question2)
    assert_false (program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).collect(&:id) & default_question_ids).any?

    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert role_question.in_summary
    assert_false program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], mentor_user).include?(role_question)
    assert_false program.in_summary_role_profile_questions_excluding_name_type([RoleConstants::MENTOR_NAME], admin_user).include?(role_question)
  end

  def test_bulk_matches_association
    program = programs(:albers)
    bulk_matches = [bulk_matches(:bulk_match_1), bulk_matches(:bulk_match_2)]
    assert_equal_unordered bulk_matches, program.bulk_matches
    assert_equal bulk_matches(:bulk_match_1), program.student_bulk_match
    assert_equal bulk_matches(:bulk_match_2), program.mentor_bulk_match
  end

  def test_update_join_settings
    prog = programs(:albers)

    assert prog.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert_false prog.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_students")
    assert_false prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")

    mentor_role = prog.find_role(RoleConstants::MENTOR_NAME)
    mentee_role = prog.find_role(RoleConstants::STUDENT_NAME)

    assert mentor_role.membership_request?
    assert mentor_role.invitation?
    assert_false mentor_role.join_directly?
    assert mentee_role.membership_request?
    assert mentee_role.invitation?
    assert_false mentee_role.join_directly?

    join_settings = {
      RoleConstants::MENTOR_NAME => [RoleConstants::JoinSetting::JOIN_DIRECTLY, RoleConstants::JoinSetting::INVITATION,
                                     RoleConstants::InviteRolePermission::MENTOR_CAN_INVITE, RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE],
      RoleConstants::STUDENT_NAME =>[RoleConstants::JoinSetting::MEMBERSHIP_REQUEST, RoleConstants::JoinSetting::INVITATION,
                                     RoleConstants::InviteRolePermission::MENTOR_CAN_INVITE]
                     }

    programs(:albers).update_join_settings(join_settings)

    assert prog.reload.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_mentors")
    assert prog.has_role_permission?(RoleConstants::MENTOR_NAME, "invite_students")
    assert prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_mentors")
    assert_false prog.has_role_permission?(RoleConstants::STUDENT_NAME, "invite_students")

    mentor_role.reload
    mentee_role.reload

    assert_false mentor_role.membership_request?
    assert mentor_role.invitation?
    assert mentor_role.join_directly?
    assert mentee_role.membership_request?
    assert mentee_role.invitation?
    assert_false mentee_role.join_directly?
  end

  def test_find_role
    p = programs(:albers)
    assert_nil p.find_role('a role that dosent exist')
    assert_equal p.find_role(RoleConstants::MENTOR_NAME).name, RoleConstants::MENTOR_NAME
  end

  def test_find_roles
    p = programs(:albers)
    assert p.find_roles('a role that dosent exist').empty?
    roles = p.find_roles(RoleConstants::MENTOR_NAME)
    assert_equal 1, roles.size
    assert_equal RoleConstants::MENTOR_NAME, roles.first.name
    roles = p.find_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_equal 2, roles.size
    role_names = roles.collect(&:name)
    assert role_names.include?(RoleConstants::MENTOR_NAME)
    assert role_names.include?(RoleConstants::STUDENT_NAME)
  end

  def test_allow_multiple_role_option_in_membership_request
    p = programs(:albers)
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    student_role = p.find_role(RoleConstants::STUDENT_NAME)
    assert p.allow_multiple_role_option_in_membership_request?
    mentor_role.membership_request = false
    mentor_role.join_directly = true
    mentor_role.save
    assert_false p.allow_multiple_role_option_in_membership_request?
    student_role.membership_request = false
    student_role.join_directly = true
    student_role.save
    assert p.allow_multiple_role_option_in_membership_request?
    student_role.join_directly = false
    student_role.save
    mentor_role.join_directly = false
    mentor_role.save
    assert_false p.allow_multiple_role_option_in_membership_request?

    mentor_role.membership_request = false
    mentor_role.eligibility_rules = true
    mentor_role.join_directly = false
    student_role.membership_request = false
    student_role.join_directly = false
    mentor_role.save
    student_role.save
    assert_false p.allow_multiple_role_option_in_membership_request?

    student_role.eligibility_rules = true
    student_role.save
    assert p.allow_multiple_role_option_in_membership_request?
  end

  def test_calendar_setting_association
    assert_equal "CalendarSetting", Program.reflect_on_association(:calendar_setting).class_name
    assert_equal :destroy, Program.reflect_on_association(:calendar_setting).options[:dependent]
  end

  def test_member_meeting_association
    program = programs(:albers)
    member_meeting_ids = program.meetings.includes(:member_meetings).collect(&:member_meetings).flatten.collect(&:id)
    assert_equal_unordered program.member_meetings.pluck(:id), member_meeting_ids
  end

  def test_dashboard_reports_association
    program = programs(:albers)
    assert_equal [], program.dashboard_reports

    obj = program.dashboard_reports.create(report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)
    assert_equal [obj.id], program.dashboard_reports.pluck(:id)
    assert_equal :destroy, Program.reflect_on_association(:dashboard_reports).options[:dependent]
  end

  def test_get_calendar_slot_time
    assert_equal Meeting::SLOT_TIME_IN_MINUTES, programs(:nwen).get_calendar_slot_time
    assert_equal 30, programs(:albers).get_calendar_slot_time
    programs(:albers).calendar_setting.update_attribute(:slot_time_in_minutes, 0)
    assert_equal Meeting::SLOT_TIME_IN_MINUTES, programs(:albers).get_calendar_slot_time
  end

  def test_is_max_capacity_student_setting_initialized
    program1 = programs(:albers)
    program2 = programs(:ceg)
    assert_false program1.is_max_capacity_student_setting_initialized?
    assert_false program2.is_max_capacity_student_setting_initialized?
  end

  def test_feedback_journal_setting
    assert programs(:albers).allow_private_journals?
    programs(:albers).update_attribute(:allow_private_journals, false)
    assert_false programs(:albers).allow_private_journals?

    assert programs(:albers).allow_connection_feedback?
    programs(:albers).update_attribute(:allow_connection_feedback, false)
    assert_false programs(:albers).allow_connection_feedback?
  end

  def test_create_default_name_role_question
    org = programs(:org_primary)
    prog = programs(:albers)
    name_q = org.name_question
    name_q.role_questions.destroy_all
    assert_empty name_q.reload.role_questions
    assert_difference "RoleQuestion.count", prog.roles_without_admin_role.count do
      prog.create_default_name_role_question!(name_q)
    end
    role_questions = name_q.reload.role_questions
    roles = prog.roles_without_admin_role
    assert_equal_unordered roles, role_questions.collect(&:role)
    role_questions.each do |rq|
      assert_equal name_q, rq.profile_question
      assert_equal RoleQuestion::AVAILABLE_FOR::BOTH, rq.available_for
      assert rq.required?
      assert_equal RoleQuestion::PRIVACY_SETTING::ALL, rq.private
      assert rq.filterable?
      assert rq.in_summary?
    end
  end

  def test_create_or_promote_user_as_admin
    program = programs(:pbe)
    admin_user = users(:f_admin_pbe)
    members(:f_student).update_attribute(:state, Member::Status::SUSPENDED)
    member = members(:f_mentor)
    member_1 = members(:mkr_student)
    member_2 = members(:f_student)

    user = member.user_in_program(program)
    user_1 = member_1.user_in_program(program)
    user_2 = member_2.user_in_program(program)
    assert_false user.is_admin?
    assert_nil user_1
    assert_false user_2.is_admin?

    assert_no_difference "User.count" do
      assert_difference "RecentActivity.count", 1 do
        assert_emails 1 do
          program.create_or_promote_user_as_admin(member, admin_user)
        end
      end
    end
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::ADMIN_NAME], user.reload.role_names

    assert_difference "User.count", 1 do
      assert_no_difference "RecentActivity.count" do
        assert_emails 1 do
          program.create_or_promote_user_as_admin(member_1, admin_user)
        end
      end
    end
    assert_equal [RoleConstants::ADMIN_NAME], member_1.user_in_program(program).role_names

    assert_no_difference "User.count" do
      assert_no_difference "RecentActivity.count" do
        assert_no_emails do
          program.create_or_promote_user_as_admin(member_2, admin_user)
        end
      end
    end
    assert_equal [RoleConstants::STUDENT_NAME], user_2.reload.role_names
  end

  def test_preferred_mentoring_for_mentee_to_admin
    program = programs(:moderated_program)
    assert program.preferred_mentoring_for_mentee_to_admin?
    program.update_attributes!(:allow_preference_mentor_request => false)
    assert_false program.reload.preferred_mentoring_for_mentee_to_admin?
  end

  def test_matching_by_mentee_and_admin_with_preference
    program = programs(:moderated_program)
    assert program.preferred_mentoring_for_mentee_to_admin?
    assert program.matching_by_mentee_and_admin?
    assert program.matching_by_mentee_and_admin_with_preference?
    program.update_attributes!(:allow_preference_mentor_request => false)
    program = program.reload
    assert_false program.preferred_mentoring_for_mentee_to_admin?
    assert program.matching_by_mentee_and_admin?
    assert_false program.reload.allow_preference_mentor_request?
  end

  def test_meeting_requests
    program = programs(:albers)
    assert_equal 8, program.meeting_requests.count

    meeting = create_meeting(force_non_group_meeting: true)

    assert_equal meeting.meeting_request, program.reload.meeting_requests.last
  end

  def test_project_requests
    program = programs(:pbe)
    program.project_requests.destroy_all
    assert_equal [], program.project_requests
    request = program.project_requests.create!(message: "Hi", sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
    assert_equal [request], program.project_requests.reload
  end

  def test_program_has_many_topics_and_posts
    forum = programs(:albers).forums.first
    assert_difference "forum.reload.topics.size", 2 do
      assert_difference "forum.reload.topics.count(&:posts)", 2 do
        topic1 = create_topic(forum: forum)
        topic2 = create_topic(forum: forum)
      end
    end
  end

  def test_validate_engagement_type
    program = programs(:albers)
    assert program.valid?

    # Allow blank
    program.engagement_type = nil
    assert program.valid?

    # Validate numericality
    program.engagement_type = "test"
    assert_false program.valid?

    # Validate inclusion
    Program::EngagementType.all.each do |eng_type|
      program.engagement_type = eng_type
      assert program.valid?
    end
    program.engagement_type = 100
    assert_false program.valid?
  end

  def test_validate_program_type
    program = programs(:albers)
    assert program.valid?

    # Allow blank
    program.program_type = nil
    assert_nil program.program_type
    assert program.valid?

    # TODO #CareerDev #Check with if this is important
    # Validate inclusion
    # program.program_type = "test"
    # assert_false program.valid?

    Program::ProgramType.all.each do |eng_type|
      program.program_type = eng_type
      assert program.valid?
    end
  end

  def test_validate_number_of_licenses
    program = programs(:albers)
    assert program.valid?

    # Allow blank
    program.number_of_licenses = nil
    assert_nil program.number_of_licenses
    assert program.valid?

    # Validate numericality
    program.number_of_licenses = -5
    assert_false program.valid?
    program.number_of_licenses = 0
    assert_false program.valid?
    program.number_of_licenses = 543
    assert program.valid?
  end

  def test_create_default_group_view_and_default_columns
    program = programs(:albers)
    assert_difference "GroupViewColumn.count", -18 do
      assert_difference "GroupView.count", -1 do
        program.group_view.destroy
      end
    end

    assert_nil program.reload.group_view

    assert_difference "GroupViewColumn.count", 18 do
      assert_difference "GroupView.count" do
        Program.create_default_group_view(program.id)
      end
    end
    roles_hsh = program.roles.includes(:translations, :customized_term).index_by(&:id)
    default_columns = ["Mentoring Connection Name", "Mentor", "Student", "Notes", "Closed by", "Closed on", "Reason", "Available since", "Pending Mentoring Connection requests", "Started on", "Last activity", "Closes on", "Mentor Messages", "Mentor Login Instances", "Student Messages", "Student Login Instances", "Created by", "Drafted since"]
    assert_equal_unordered default_columns, programs(:albers).reload.group_view.group_view_columns.collect{|c| c.get_title(roles_hsh)}
  end

  def test_create_default_mentoring_model
    program = programs(:albers)
    mentoring_model = program.mentoring_models.first
    assert_equal mentoring_model, program.default_mentoring_model
    created_mentoring_model = nil
    roles_hash = program.roles.group_by(&:name)

    assert_no_difference "MentoringModel.count" do
      created_mentoring_model = program.create_default_mentoring_model!
    end
    assert_equal created_mentoring_model, mentoring_model

    mentoring_model.destroy
    assert program.reload.mentoring_models.size.zero?
    assert_nil program.default_mentoring_model

    assert_difference "ObjectRolePermission.count", 10 do
      assert_difference "MentoringModel.count" do
        created_mentoring_model = program.create_default_mentoring_model!
      end
    end

    assert_equal 1, program.reload.mentoring_models.count
    created_mentoring_model = program.mentoring_models.first

    assert created_mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::ADMIN_NAME].first)

    assert created_mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false created_mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::MENTOR_NAME].first)

    assert created_mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_false created_mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::STUDENT_NAME].first)

    created_mentoring_model.destroy
    program.mentoring_models.create!(title: "Carrie Mathison", default: false, mentoring_period: 6.months)
    assert_false program.reload.mentoring_models.count.zero?

    assert_difference "MentoringModel.count" do
      created_mentoring_model = program.create_default_mentoring_model!
    end

    assert_equal created_mentoring_model, program.reload.default_mentoring_model

    assert_no_difference "MentoringModel.count" do
      program.create_default_mentoring_model!
    end
  end

  def test_career_based
    program = programs(:albers)

    program.engagement_type = nil
    assert_false program.career_based?

    program.engagement_type = Program::EngagementType::PROJECT_BASED
    assert_false program.career_based?
    assert program.ongoing_mentoring_enabled?

    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.reload

    program.engagement_type = Program::EngagementType::CAREER_BASED
    assert program.career_based?
    assert_false program.ongoing_mentoring_enabled?

    program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    assert program.career_based?
    assert program.ongoing_mentoring_enabled?
  end

  def test_project_based
    program = programs(:albers)
    assert_equal Program.where(engagement_type: Program::EngagementType::PROJECT_BASED), Program.project_based

    program.engagement_type = nil
    assert_false program.project_based?

    program.engagement_type = Program::EngagementType::CAREER_BASED
    assert_false program.project_based?

    program.engagement_type = Program::EngagementType::PROJECT_BASED
    assert program.project_based?

    program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    assert_false program.project_based?
  end

  def test_active_users_by_roles
    program = programs(:albers)
    assert_equal_unordered program.mentor_users.active, program.active_users_by_roles([RoleConstants::MENTOR_NAME])
    assert_equal_unordered program.student_users.active, program.active_users_by_roles([RoleConstants::STUDENT_NAME])
    assert_equal_unordered program.admin_users.active, program.active_users_by_roles([RoleConstants::ADMIN_NAME])
    assert_equal_unordered program.mentor_users.active | program.student_users.active | program.admin_users.active, program.active_users_by_roles([RoleConstants::ADMIN_NAME, RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME])
  end

  def test_students_by_user
    result = programs(:albers).students_by_user

    assert result.is_a?(Hash)
    assert_equal 1, result[users(:f_mentor).id]
    assert_equal 2, result[users(:robert).id]
    assert_equal 4, result[users(:mentor_1).id]
    assert_equal 2, result[users(:not_requestable_mentor).id]
  end

  def test_pending_mentor_offers_size
    program = programs(:albers)

    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    program.invoke_feature_dependancy_offer_mentoring(true)

    attributes = {
      mentor: users(:f_mentor),
      student: users(:f_student),
      status: MentorOffer::Status::PENDING
    }
    program.mentor_offers.create!(attributes)

    options = program.pending_mentor_offers_size
    assert_equal 1, options[users(:f_mentor).id]

    admin = users(:f_admin)
    assert options[admin.id].nil?
  end

  def test_available_slots_by_user
    program = programs(:albers)

    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    program.invoke_feature_dependancy_offer_mentoring(true)

    attributes = {
      mentor: users(:f_mentor),
      student: users(:f_student),
      status: MentorOffer::Status::PENDING
    }
    program.mentor_offers.create!(attributes)

    options = program.available_slots_by_user
    assert_equal 2, options[users(:f_mentor).id]
    assert_equal 2, options[users(:robert).id]
    assert_equal 4, options[users(:mentor_1).id]
    assert_equal 2, options[users(:not_requestable_mentor).id]
  end

  def test_get_all_tags_true
    program = programs(:albers)
    all_tags = ["tag1", "tag2", "tag3", "tag4"] # Depends on ChronusFixtureGenerator - populate_user_tags
    assert_equal all_tags, program.get_all_tags
  end

  def test_get_all_tags_false
    program = programs(:albers)
    all_tags = ["tag1", "tag2", "tag3", "tag4"] # Depends on ChronusFixtureGenerator - populate_user_tags
    tag_objects = program.get_all_tags(false)
    assert_equal all_tags, tag_objects.collect(&:name)
  end

  def test_has_new_updates_from_true
    program = programs(:albers)
    assert program.has_new_updates_from?(WEEKLY_UPDATE_PERIOD.ago)
  end

  def test_has_has_new_updates_from_false
    program = programs(:albers)
    empty_array = []
    program.expects(:new_articles).returns(empty_array)
    program.expects(:new_qa_questions).returns(empty_array)
    assert_false program.has_new_updates_from?(WEEKLY_UPDATE_PERIOD.ago)
  end

  def test_has_one_match_setting
    program = programs(:albers)
    match_setting = program.match_setting
    assert_equal 0.0, match_setting.min_match_score
    assert_equal 0.0, match_setting.max_match_score
    # Duplicate setting should not be created for program
    assert_no_difference "Matching::Persistence::Setting.count" do
      Program.create_default_match_setting!(program.id)
    end
  end

  def test_update_match_scores_range
    program = programs(:albers)
    match_setting = program.match_setting
    assert_equal 0.0, match_setting.min_match_score
    assert_equal 0.0, match_setting.max_match_score

    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.9)
    program.update_match_scores_range!
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.9, match_setting.max_match_score

    set_mentor_cache(users(:rahim).id, users(:f_mentor).id, 0.9)
    program.update_match_scores_range!
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.9, match_setting.max_match_score

    set_mentor_cache(users(:rahim).id, users(:f_mentor).id, 0.8)
    assert_nil program.update_match_scores_range!(0.0, 0.9)
    assert_nil program.update_match_scores_range!(nil, 0.9)
    assert_nil program.update_match_scores_range!(0.0, nil)
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.9, match_setting.max_match_score

    reset_cache(users(:f_student))
  end

  def test_update_match_setting_attributes
    program = programs(:albers)
    Matching::Persistence::Setting.any_instance.expects(:update_attributes!).with(min_match_score: 0.0, max_match_score: 0.9)
    program.update_match_setting_attributes!(0.0, 0.9)

    Matching::Persistence::Setting.any_instance.stubs(:present?).returns(false)
    Matching::Persistence::Setting.expects(:create!).with(min_match_score: 0.0, max_match_score: 0.9, program_id: program.id)
    program.update_match_setting_attributes!(0.0, 0.9)
  end

  def test_update_match_scores_range_for_student
    program = programs(:albers)
    match_setting = program.match_setting
    assert_equal 0.0, match_setting.min_match_score
    assert_equal 0.0, match_setting.max_match_score

    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.9)
    program.update_match_scores_range_for_student!(users(:f_student))
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.9, match_setting.max_match_score

    set_empty_mentor_cache(users(:f_student).id)
    program.update_match_scores_range_for_student!(users(:f_student))
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.9, match_setting.max_match_score
    reset_cache(users(:f_student))

    Matching::Database::Score.any_instance.stubs(:get_min_max_by_mentee_id).returns([nil, nil]).once
    Program.any_instance.expects(:update_program_match_scores_range_wrt_old_scores).with(0.0, 0.9)
    program.update_match_scores_range_for_student!(users(:f_student), 0.0, 0.9)

    Matching::Database::Score.any_instance.stubs(:get_min_max_by_mentee_id).returns([0.0, 0.8]).once
    Program.any_instance.expects(:update_program_match_scores_range_wrt_old_scores).with(0.0, 0.9)
    program.update_match_scores_range_for_student!(users(:f_student), 0.0, 0.9)

    Matching::Database::Score.any_instance.stubs(:get_min_max_by_mentee_id).returns([0.1, 1.0]).once
    Program.any_instance.expects(:update_program_match_scores_range_wrt_old_scores).with(0.0, 0.9)
    program.update_match_scores_range_for_student!(users(:f_student), 0.0, 0.9)

    Matching::Database::Score.any_instance.stubs(:get_min_max_by_mentee_id).returns([0.0, 0.9]).once
    Program.any_instance.expects(:update_program_match_scores_range_wrt_old_scores).never
    program.update_match_scores_range_for_student!(users(:f_student), 0.0, 0.9)

    Matching::Database::Score.any_instance.stubs(:get_min_max_by_mentee_id).returns([0.0, 0.9]).once
    Program.any_instance.expects(:update_program_match_scores_range_wrt_old_scores).never
    program.update_match_scores_range_for_student!(users(:f_student), 0.0, 0.9)
  end

  def test_update_match_scores_range_for_student_no_existing_cache
    program = programs(:albers)
    user = users(:f_student)
    match_setting = program.match_setting

    program.update_match_scores_range_for_student!(user)
    assert_equal 0.0, match_setting.min_match_score
    assert_equal 0.0, match_setting.max_match_score
  end

  def test_update_match_scores_range_for_student_keep_existing_value
    program = programs(:albers)
    match_setting = program.match_setting
    match_setting.update_attributes!(min_match_score: -0.1, max_match_score: 1)
    assert_equal -0.1, match_setting.min_match_score
    assert_equal 1.0, match_setting.max_match_score

    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.9)
    program.update_match_scores_range_for_student!(users(:f_student))
    assert_equal -0.1, match_setting.reload.min_match_score
    assert_equal 1.0, match_setting.max_match_score
    reset_cache(users(:f_student))
  end

  def test_update_match_scores_range_for_min_max
    program = programs(:albers)
    match_setting = program.match_setting
    assert_equal 0.0, match_setting.min_match_score
    assert_equal 0.0, match_setting.max_match_score

    program.update_match_scores_range_for_min_max!(nil, nil)
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.0, match_setting.max_match_score

    program.update_match_scores_range_for_min_max!(nil, 0.80)
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.0, match_setting.max_match_score

    program.update_match_scores_range_for_min_max!(0.15, 0.75)
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.75, match_setting.max_match_score

    program.update_match_scores_range_for_min_max!(0.10, 0.60)
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.75, match_setting.max_match_score

    program.update_match_scores_range_for_min_max!(0.20, 0.85)
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.85, match_setting.max_match_score
    reset_match_setting(program)
  end

  def test_update_program_match_scores_range_wrt_old_scores
    program = programs(:albers)
    Matching::Cache::Refresh.perform_program_delta_refresh(program.id)
    match_setting = program.match_setting
    assert_equal 0.0, match_setting.min_match_score
    assert_equal 0.0, match_setting.max_match_score
    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.9)
    program.update_match_scores_range!
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.9, match_setting.max_match_score

    Program.any_instance.expects(:update_match_scores_range_later!).with(0.0, 0.9)
    Matching::Cache::Refresh.remove_mentor(users(:f_mentor).id, program.id)
    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.9)
    program.update_match_scores_range!
    assert_equal 0.0, match_setting.reload.min_match_score
    assert_equal 0.9, match_setting.max_match_score

    Program.any_instance.expects(:update_match_scores_range_later!).with(0.0, nil)
    Matching::Cache::Refresh.remove_student(users(:rahim).id, program.id)
    Matching::Cache::Refresh.perform_program_delta_refresh(program.id)
  end

  def test_get_partition_size_for_program
    assert_equal 1, programs(:albers).get_partition_size_for_program
  end

  def test_get_user_ids_based_on_roles
     program = programs(:albers)
     assert_equal program.student_users.pluck(:id), program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
     assert_equal program.mentor_users.pluck(:id), program.get_user_ids_based_on_roles(RoleConstants::MENTOR_NAME)
  end

  def test_choice_based_questions_ids_for_role
    program = programs(:albers)
    student_ques = program.role_questions_for([RoleConstants::STUDENT_NAME], fetch_all: true).role_profile_questions
        .joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]).pluck("role_questions.id")
    assert_equal_unordered student_ques, program.choice_based_questions_ids_for_role([RoleConstants::STUDENT_NAME])

    mentor_ques = program.role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).role_profile_questions
        .joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]).pluck("role_questions.id")
    assert_equal_unordered mentor_ques, program.choice_based_questions_ids_for_role([RoleConstants::MENTOR_NAME])

    prof_q = create_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Pick one", question_choices: "alpha, beta, gamma")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!
    assert_equal_unordered (student_ques + [student_question.id]), program.choice_based_questions_ids_for_role([RoleConstants::STUDENT_NAME])
    assert_equal_unordered (mentor_ques + [mentor_question.id]), program.choice_based_questions_ids_for_role([RoleConstants::MENTOR_NAME])
  end

  def test_show_match_label_questions_ids_for_role
    program = programs(:albers)
    organization = programs(:org_primary)

    student_ques = program.role_questions_for([RoleConstants::STUDENT_NAME], fetch_all: true).role_profile_questions
        .joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::LOCATION]).pluck("role_questions.id")
    assert_equal_unordered student_ques, program.show_match_label_questions_ids_for_role([RoleConstants::STUDENT_NAME])

    mentor_ques = program.role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).role_profile_questions
        .joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::LOCATION]).pluck("role_questions.id")
    assert_equal_unordered mentor_ques, program.show_match_label_questions_ids_for_role([RoleConstants::MENTOR_NAME])
  end

  def test_invite_member_for_roles_assign_roles
    program = programs(:albers)
    member = members(:f_mentor_student)
    user = users(:f_mentor_student)
    invitor = users(:f_admin)
    program2 = programs(:nwen)
    role_type = ProgramInvitation::RoleType::ASSIGN_ROLE

    assert_false member.user_roles_in_program(program).include?(RoleConstants::ADMIN_NAME)
    assert member.user_roles_in_program(program).include?(RoleConstants::MENTOR_NAME)
    assert member.user_roles_in_program(program).include?(RoleConstants::STUDENT_NAME)
    assert member.user_roles_in_program(program2).empty?

    program.expects(:create_member_invitation_for_roles).times(1).returns(true)
    assert_equal true, program.invite_member_for_roles([RoleConstants::ADMIN_NAME], invitor, member, 'message', role_type)

    program.expects(:create_member_invitation_for_roles).times(0)
    assert_nil program.invite_member_for_roles([], invitor, member, 'message', role_type)

    program.expects(:create_member_invitation_for_roles).times(0)
    assert_nil program.invite_member_for_roles([RoleConstants::MENTOR_NAME], invitor, member, 'message', role_type)

    program2.expects(:create_member_invitation_for_roles).times(1).returns(true)
    assert_equal true, program2.invite_member_for_roles([RoleConstants::MENTOR_NAME], invitor, member, 'message', role_type)

    user.suspend_from_program!(invitor, "Suspension")
    program.expects(:create_member_invitation_for_roles).times(1).returns(true)
    assert_equal true, program.invite_member_for_roles([RoleConstants::MENTOR_NAME], invitor, member.reload, 'message', role_type)

    member.update_attribute(:state, Member::Status::SUSPENDED)
    program2.expects(:create_member_invitation_for_roles).times(0)
    assert_nil program2.invite_member_for_roles([RoleConstants::STUDENT_NAME], invitor, member, 'message', role_type)
  end

  def test_invite_member_for_roles_allow_roles
    program = programs(:albers)
    member = members(:mkr_student)
    invitor = users(:f_admin)
    program2 = programs(:nwen)
    role_type = ProgramInvitation::RoleType::ALLOW_ROLE

    assert_false member.user_roles_in_program(program).include?(RoleConstants::ADMIN_NAME)
    assert_false member.user_roles_in_program(program).include?(RoleConstants::MENTOR_NAME)
    assert member.user_roles_in_program(program).include?(RoleConstants::STUDENT_NAME)
    assert member.user_roles_in_program(program2).empty?

    program.expects(:create_member_invitation_for_roles).times(0)
    assert_nil program.invite_member_for_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], invitor, member, 'message', role_type)

    program.expects(:create_member_invitation_for_roles).times(0)
    assert_nil program.invite_member_for_roles([RoleConstants::MENTOR_NAME], invitor, member, 'message', role_type)

    program.expects(:create_member_invitation_for_roles).times(0)
    assert_nil program.invite_member_for_roles([RoleConstants::STUDENT_NAME], invitor, member, 'message', role_type)

    program2.expects(:create_member_invitation_for_roles).times(1).returns(false)
    assert_equal false, program2.invite_member_for_roles([RoleConstants::STUDENT_NAME], invitor, member, 'message', role_type)

    member.update_attribute(:state, Member::Status::SUSPENDED)
    assert member.user_roles_in_program(program2).empty?

    program2.expects(:create_member_invitation_for_roles).times(0)
    assert_nil program2.invite_member_for_roles([RoleConstants::STUDENT_NAME], invitor, member, 'message', role_type)
  end

  def test_non_admin_role_can_send_invite
    @current_program = programs(:albers)
    mentor_role = @current_program.find_role(RoleConstants::MENTOR_NAME)

    assert mentor_role.has_permission_name?('invite_mentors')
    assert_false mentor_role.has_permission_name?('invite_students')

    assert @current_program.non_admin_role_can_send_invite?
  end

  def test_create_member_invitation_for_roles
    program = programs(:albers)
    member = members(:f_mentor_student)
    invitor = users(:f_admin)
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      assert_difference "ProgramInvitation.count", 1 do
        program.create_member_invitation_for_roles(['admin'], member.email, 'message', invitor, ProgramInvitation::RoleType::ASSIGN_ROLE, {locale: :ta})
      end
    end
    assert_equal "ta", program.program_invitations.last.locale
  end

  def test_create_member_invitation_for_roles_without_sending_mail
    program = programs(:albers)
    member = members(:f_mentor_student)
    invitor = users(:f_admin)
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      assert_difference "ProgramInvitation.count", 1 do
        program.create_member_invitation_for_roles(['admin'], member.email, 'message', invitor, ProgramInvitation::RoleType::ASSIGN_ROLE, {skip_sending_instantly: true})
      end
    end
  end

  def test_populate_default_campaigns
    program = programs(:albers)
    CampaignPopulator.expects(:setup_program_with_default_campaigns).once
    CampaignPopulator.expects(:link_program_invitation_campaign_to_mailer_template).once
    program.populate_default_campaigns
  end


  def test_populate_default_customized_terms
    CustomizedTerm.destroy_all
    program = programs(:albers)

    assert_difference 'CustomizedTerm.count', 5 do
      program.populate_default_customized_terms
    end
    assert_equal [CustomizedTerm::TermType::MENTORING_CONNECTION_TERM, CustomizedTerm::TermType::MEETING_TERM, CustomizedTerm::TermType::RESOURCE_TERM,
                  CustomizedTerm::TermType::ARTICLE_TERM, CustomizedTerm::TermType::MENTORING_TERM], CustomizedTerm.pluck(:term_type)
    assert_equal program, CustomizedTerm.first.ref_obj

    assert_no_difference 'CustomizedTerm.count' do
      program.populate_default_customized_terms
    end
  end

  def test_connection_memberships_association
    program = programs(:albers)
    assert_equal_unordered program.groups.collect(&:memberships).flatten.collect(&:id), program.connection_memberships.pluck(:id)
  end

  def test_get_connection_limit
    program = programs(:albers)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::NONE)
    program.get_connection_limit
    assert_equal program.can_increase_connection_limit, 0
    assert_equal program.can_decrease_connection_limit, 0
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::ONLY_DECREASE)
    program.get_connection_limit
    assert_equal program.can_increase_connection_limit, 0
    assert_equal program.can_decrease_connection_limit, 1
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::ONLY_INCREASE)
    program.get_connection_limit
    assert_equal program.can_increase_connection_limit, 1
    assert_equal program.can_decrease_connection_limit, 0
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::BOTH)
    program.get_connection_limit
    assert_equal program.can_increase_connection_limit, 1
    assert_equal program.can_decrease_connection_limit, 1
  end

  def test_set_connection_limit
    program = programs(:albers)
    program.set_connection_limit(0, 0)#(increase_limit, decrease_limit)
    assert_equal program.connection_limit_permission, Program::ConnectionLimit::NONE
    program.set_connection_limit(1, 0)#(increase_limit, decrease_limit)
    assert_equal program.connection_limit_permission, Program::ConnectionLimit::ONLY_INCREASE
    program.set_connection_limit(0, 1)#(increase_limit, decrease_limit)
    assert_equal program.connection_limit_permission, Program::ConnectionLimit::ONLY_DECREASE
    program.set_connection_limit(1, 1)#(increase_limit, decrease_limit)
    assert_equal program.connection_limit_permission, Program::ConnectionLimit::BOTH
  end

  def test_allow_mentor_update_maxlimit
    program = programs(:albers)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::ONLY_INCREASE)
    assert program.allow_mentor_update_maxlimit?
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::ONLY_DECREASE)
    assert program.allow_mentor_update_maxlimit?
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::BOTH)
    assert program.allow_mentor_update_maxlimit?
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::NONE)
    assert_false program.allow_mentor_update_maxlimit?
  end

  def test_update_mentors_connection_limit
    program = programs(:albers)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::BOTH)
    mentor_user1 = program.mentor_users.first
    mentor_user2 = program.mentor_users.last
    mentee_user = program.student_users.first
    mentor_user1.update_attributes(:max_connections_limit => 20)
    mentor_user2.update_attributes(:max_connections_limit => 15)
    mentee_user.update_attributes(:max_connections_limit => 15)
    g1 = create_group(:student => users(:f_student),:mentor => mentor_user1)
    g2 = create_group(:student => users(:rahim), :mentor => mentor_user1)
    program.update_mentors_connection_limit(1)
    assert_equal 1, mentor_user1.reload.max_connections_limit
    assert_equal 1, mentor_user2.reload.max_connections_limit
    assert_equal 15, mentee_user.reload.max_connections_limit
  end

  def test_get_terms_for_view
    assert_equal_unordered [programs(:albers).term_for(CustomizedTerm::TermType::MENTORING_TERM), programs(:albers).term_for(CustomizedTerm::TermType::MEETING_TERM), programs(:albers).term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM), programs(:albers).term_for(CustomizedTerm::TermType::ARTICLE_TERM), programs(:albers).term_for(CustomizedTerm::TermType::RESOURCE_TERM)] + programs(:albers).roles.non_administrative.collect(&:customized_term), programs(:albers).get_terms_for_view
  end

  def test_active_groups
    program = programs(:albers)
    mygroup = groups(:mygroup)
    assert_equal 10, program.groups.size
    assert_equal 6, program.active_groups.size
    assert_equal [], (program.active_groups.pluck(:id) & [:group_4, :drafted_group_1, :drafted_group_2, :drafted_group_3].collect{|group_sym| groups(group_sym).id })
    assert program.active_groups.include?(mygroup)
    mygroup.terminate!(users(:f_admin), "Banned for binge watching House of Cards :)", groups(:mygroup).program.permitted_closure_reasons.first.id)
    assert_false program.active_groups.include?(mygroup)
  end

  def test_program_sections_should_be_fetched_by_positon
    program = programs(:albers)
    section1 = program.report_sections[0]
    section2 = program.report_sections[-1]
    assert_not_equal section1.id, section2.id
    temp_position = section1.position
    section1.update_attribute(:position, section2.position)
    section2.update_attribute(:position, temp_position)
    assert_equal section2.id, program.reload.report_sections[0].id
    assert_equal section1.id, program.reload.report_sections[-1].id
  end

  def test_get_most_viewed_community_contents
    program = programs(:albers)
    previous_month = Time.current.prev_month
    time_range = ((previous_month.beginning_of_month)..(previous_month.end_of_month))
    article = program.articles.first
    article.update_attribute(:created_at, Time.current.prev_month.end_of_month - 5.days)
    assert_equal [{:object=>article, :views=>0, :obj_priority=>1, :role_id=>nil}], program.get_most_viewed_community_contents(time_range, 3)
    assert_equal [], program.get_most_viewed_community_contents(time_range, 0)
    qa_question = program.qa_questions.first
    qa_question.update_attribute(:created_at, Time.current.prev_month.end_of_month - 5.days)
    assert_equal [{:object=>qa_question, :views=>1, :obj_priority=>3, :role_id=>nil}, {:object=>article, :views=>0, :obj_priority=>1, :role_id=>nil}], program.get_most_viewed_community_contents(time_range, 3)
    article.update_attribute(:view_count, 1)
    assert_equal [{:object=>article, :views=>1, :obj_priority=>1, :role_id=>nil}, {:object=>qa_question, :views=>1, :obj_priority=>3, :role_id=>nil}], program.get_most_viewed_community_contents(time_range, 3)
  end

  def test_get_recent_community_contents
    program = programs(:albers)
    current_time = Time.now

    article1 = articles(:economy)
    article2 = articles(:india)
    article3 = articles(:kangaroo)
    article1.update_attribute(:created_at, current_time - 10.seconds)
    article2.update_attribute(:created_at, current_time - 20.seconds)
    article3.update_attribute(:created_at, current_time - 30.seconds)

    qa_question_1 = qa_questions(:what)
    qa_question_2 = qa_questions(:why)
    qa_question_3 = qa_questions(:question_for_stopwords_test)
    qa_question_1.update_attribute(:created_at, current_time - 10.seconds)
    qa_question_2.update_attribute(:created_at, current_time - 20.seconds)
    qa_question_3.update_attribute(:created_at, current_time - 30.seconds)

    assert_empty program.get_recent_community_contents(0, articles: true, forums: true, qa: true)
    assert_equal [ { object: article1, obj_priority: 1, role_id: nil }, { object: article2, obj_priority: 1, role_id: nil }, { object: article3, obj_priority: 1, role_id: nil }, { object: qa_question_1, obj_priority: 3, role_id: nil }, { object: qa_question_2, obj_priority: 3, role_id: nil }, { object: qa_question_3, obj_priority: 3, role_id: nil } ], program.get_recent_community_contents(3, articles: true, forums: true, qa: true)

    topic = create_topic(program.forums[0])
    assert_equal [ { object: article1, obj_priority: 1, role_id: nil }, { object: article2, obj_priority: 1, role_id: nil }, { object: article3, obj_priority: 1, role_id: nil }, { object: topic, obj_priority: 2, role_id: program.roles.find_by(name: RoleConstants::MENTOR_NAME).id }, { object: topic, obj_priority: 2, role_id: program.roles.find_by(name: RoleConstants::STUDENT_NAME).id }, { object: qa_question_1, obj_priority: 3, role_id: nil }, { object: qa_question_2, obj_priority: 3, role_id: nil }, { object: qa_question_3, obj_priority: 3, role_id: nil } ], program.get_recent_community_contents(3, articles: true, forums: true, qa: true)
  end

  def test_get_most_viewed_topics
    program = programs(:albers)
    topic = create_topic(program.forums[0])
    time_range = ((1.year.ago)..(1.year.from_now))
    assert_equal [{:object=>topic, :views=>0, :obj_priority=>100, :role_id=>program.roles.find_by(name: RoleConstants::MENTOR_NAME).id}, {:object=>topic, :views=>0, :obj_priority=>100, :role_id=>program.roles.find_by(name: RoleConstants::STUDENT_NAME).id}], program.get_most_viewed_topics(time_range, 3, 100)
    assert_equal [], program.get_most_viewed_topics(time_range, 0, 100)
  end

  def test_get_recent_topics
    program = programs(:albers)
    topic = create_topic(program.forums[0])
    assert_equal [{:object=>topic, :obj_priority=>100, :role_id=>program.roles.find_by(name: RoleConstants::MENTOR_NAME).id}, {:object=>topic, :obj_priority=>100, :role_id=>program.roles.find_by(name: RoleConstants::STUDENT_NAME).id}], program.get_recent_topics(3, 100)
    assert_equal [], program.get_recent_topics(0, 100)
  end

  def test_unconnected_user_widget_content
    program = programs(:albers)
    current_time = Time.now
    view_options = {key: "val"}
    Time.stubs(:now).returns(current_time)
    time_range_1 = (((current_time - 1.month).beginning_of_day)..current_time)
    time_range_2 = (((current_time - 2.month).beginning_of_day)..((current_time - 1.month).end_of_day))

    Program.any_instance.stubs(:get_most_viewed_community_contents).with(time_range_1, Program::UNCONNECTED_USER_WIDGET_TILES_COUNT, view_options).returns(["a", "b"])
    Program.any_instance.stubs(:get_most_viewed_community_contents).with(time_range_2, Program::UNCONNECTED_USER_WIDGET_TILES_COUNT, view_options).returns(["c", "d"])
    Program.any_instance.stubs(:get_recent_community_contents).with(Program::UNCONNECTED_USER_WIDGET_TILES_COUNT, view_options).returns(["e", "f"])

    assert_equal ["a", "b", "c", "d", "e", "f"], program.unconnected_user_widget_content(view_options)
  end

  def test_project_request_reminder_duration_validation
    program =  Program.new(
      needs_project_request_reminder: true, name: "Some program",
      organization: Organization.first, project_request_reminder_duration: nil
    )
    program.root = "someroot"
    assert_false program.valid?
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :project_request_reminder_duration, "is not a number") do
      program.save!
    end

    program =  Program.new(
      :name => "Some program", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, organization: Organization.first
    )
    program.root = "someroot"
    assert program.valid?
    assert_nothing_raised do
      program.save!
    end

    program =  Program.new(
      needs_project_request_reminder: true, name: "Some program", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
      organization: Organization.first, project_request_reminder_duration: 0
    )
    program.root = "someroot1"
    assert_false program.valid?
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :project_request_reminder_duration, "must be greater than 0") do
      program.save!
    end

    program =  Program.new(
      needs_project_request_reminder: true, name: "Some program", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
      organization: Organization.first, project_request_reminder_duration: 1
    )
    program.root = "someroot1"
    assert program.valid?
    assert_nothing_raised do
      program.save!
    end
  end

  def test_create_default_program_management_report_V2
    organization = Organization.create!({:name => "Some Organization"})
    program =  Program.create!({:name => "agi program", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => 'ursa', :organization => organization})
    program.abstract_views.where(default_view: AbstractView::DefaultType.default_program_management_report_type).destroy_all
    assert_equal [],  program.reload.abstract_views.where(default_view: AbstractView::DefaultType.default_program_management_report_type)
    program.report_sections.destroy_all
    assert_equal 0, program.report_sections.count
    assert_equal 0, program.report_sections.map(&:metrics).flatten.size

    program.create_default_abstract_views_for_program_management_report
    Program.create_default_program_management_report(program.id)
    assert_equal ["Application Accepted, Awaiting Signup",
      "Never Connected Mentees",
      "Currently Unconnected Mentees",
      "Users With Low Profile Scores",
      "Flagged Content",
      "Pending Meeting Requests",
      "Pending Membership Applications",
      "Pending Mentoring Requests",
      "Invitations Awaiting Acceptance",
      "Pending Connections Requests",
      "Connections with no Activity",
      "Connections with no Recent Activity",
      "Connections with Overdue Tasks"
    ], program.reload.abstract_views.where(default_view: AbstractView::DefaultType.default_program_management_report_type).map(&:title)
    assert_equal ["Membership", "Matching", "Engagement"], program.report_sections.map(&:title)
    assert_equal [
      ["Membership", "Pending Membership Applications"],
      ["Membership", "Invitations Awaiting Acceptance"],
      ["Membership", "Application Accepted, Awaiting Signup"],
      ["Membership", "Mentors yet to Publish Profile"],
      ["Membership", "Mentees yet to Publish Profile"],
      ["Membership", "Mentors With Low Profile Scores"],
      ["Membership", "Mentees With Low Profile Scores"],
      ["Matching", "Never Connected Mentees"],
      ["Matching", "Currently Unconnected Mentees"],
      ["Matching", "Drafted Connections"],
      ["Matching", "Mentors In Drafted Connections"],
      ["Matching", "Mentees In Drafted Connections"],
      ["Matching", "Mentors Yet To Be Drafted"],
      ["Matching", "Mentees Yet To Be Drafted"],
      ["Matching", "Never Connected Mentors"]
    ], program.reload.report_sections.map(&:metrics).flatten.map{|m| [m.section.title, m.title] }
  end

  def test_create_default_alerts_for_program_management_report
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_MENTOR
    program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    program.save!

    program.abstract_views.collect(&:metrics).flatten.each{|m| m.destroy}
    assert_equal 0, program.report_sections.map(&:metrics).flatten.size

    program.create_default_metrics_for_program_management_report
    program.create_default_alerts_for_program_management_report

    metrics = program.reload.report_sections.map(&:metrics).flatten
    assert_equal_unordered ["Program applicants who are awaiting your acceptance for more than 15 days",
      "Invitations awaiting acceptance, which are sent 15 days before",
      "Mentoring requests received 15 days before and that have not yet been accepted or declined",
      "Meeting requests received 7 days before and that have not yet been accepted or declined",
      "Students who have joined over a month ago and never been connected",
      "Mentors who have joined over a month ago and never been connected"], metrics.collect(&:alerts).flatten.collect(&:description)
    assert_equal_unordered (1..6).to_a, metrics.collect(&:alerts).flatten.collect(&:default_alert)
    assert_no_difference "Report::Alert.count" do
      program.create_default_alerts_for_program_management_report
    end
  end

  def test_create_default_alerts_for_program_management_report_without_metric
    program = programs(:albers)
    Report::Alert.delete_all
    assert_difference "Report::Alert.count", 5 do
      program.create_default_alerts_for_program_management_report
    end
    Report::Alert.last.metric.destroy
    Report::Alert.delete_all
    assert_difference "Report::Alert.count", 4 do
      program.create_default_alerts_for_program_management_report
    end
  end

  def test_create_default_admin_views_and_its_dependencies
    program = programs(:albers)

    Program.any_instance.expects(:create_default_admin_views).once.returns
    Program.any_instance.expects(:create_default_abstract_views_for_program_management_report).once.returns
    Program.any_instance.expects(:populate_default_campaigns).once.returns

    Program.create_default_admin_views_and_its_dependencies(program.id)
  end

  def test_create_default_abstract_views_for_program_management_report_V2
    program = programs(:albers)
    program.abstract_views.where(default_view: AbstractView::DefaultType.default_program_management_report_type).destroy_all

    program.create_default_abstract_views_for_program_management_report
    assert_equal [
      "Application Accepted, Awaiting Signup",
      "Never Connected Students",
      "Currently Unconnected Students",
      "Users With Low Profile Scores",
      "Flagged Content",
      "Pending Meeting Requests",
      "Pending Membership Applications",
      "Pending Mentoring Requests",
      "Invitations Awaiting Acceptance",
      "Pending Mentoring Connections Requests",
      "Mentoring Connections with no Activity",
      "Mentoring Connections with no Recent Activity",
      "Mentoring Connections with Overdue Tasks"
    ], program.abstract_views.reload.where(default_view: AbstractView::DefaultType.default_program_management_report_type).pluck(:title)
  end

  def test_update_default_abstract_views_for_program_management_report
    program = programs(:albers)
    program.abstract_views.where(default_view: AbstractView::DefaultType.default_program_management_report_type).destroy_all
    program.create_default_abstract_views_for_program_management_report

    metrics_only_onetime_enabled  = ["Pending Mentoring Requests", "Pending Meeting Requests", "Never Connected Students", "Currently Unconnected Students"]
    metrics_only_ongoing_enabled = ["Pending Mentoring Requests", "Never Connected Students", "Currently Unconnected Students", "Never Connected Mentors", "Mentors With Pending Mentoring Requests", "Students Who Sent Mentoring Request But Not Connected", "Students Who Haven't Sent Mentoring Request"]
    metrics_both_onetime_and_ongoing_enabled = ["Pending Mentoring Requests", "Pending Meeting Requests", "Never Connected Students", "Currently Unconnected Students", "Never Connected Mentors", "Mentors With Pending Mentoring Requests", "Students Who Sent Mentoring Request But Not Connected", "Students Who Haven't Sent Mentoring Request"]

    program.update_default_abstract_views_for_program_management_report
    assert_equal metrics_only_ongoing_enabled, program.report_sections.reload.find_by(default_section: Report::Section::DefaultSections::CONNECTION).metrics.pluck(:title)

    program.enable_feature(FeatureName::CALENDAR)
    program.update_default_abstract_views_for_program_management_report
    assert_equal metrics_both_onetime_and_ongoing_enabled, program.report_sections.reload.find_by(default_section: Report::Section::DefaultSections::CONNECTION).metrics.pluck(:title)

    program.enable_feature(FeatureName::CALENDAR, false)
    program.update_default_abstract_views_for_program_management_report
    assert_equal metrics_only_ongoing_enabled, program.report_sections.reload.find_by(default_section: Report::Section::DefaultSections::CONNECTION).metrics.pluck(:title)

    program.enable_feature(FeatureName::CALENDAR)
    program.update_column(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.update_default_abstract_views_for_program_management_report
    assert_equal metrics_only_onetime_enabled, program.report_sections.reload.find_by(default_section: Report::Section::DefaultSections::CONNECTION).metrics.pluck(:title)

    program.update_column(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    program.update_default_abstract_views_for_program_management_report
    assert_equal metrics_both_onetime_and_ongoing_enabled, program.report_sections.reload.find_by(default_section: Report::Section::DefaultSections::CONNECTION).metrics.pluck(:title)
  end

  def test_create_default_sections_for_program_management_report_and_create_default_metrics_for_program_management_report_V2
    organization = Organization.create!({:name => "Some Organization"})
    program =  Program.create!({:name => "agi program", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => 'ursa', :organization => organization})
    program.report_sections.destroy_all
    assert_equal 0, program.report_sections.count
    assert_equal 0, program.report_sections.map(&:metrics).flatten.size
    program.create_default_sections_for_program_management_report
    assert_equal ["Membership", "Matching", "Engagement"], program.reload.report_sections.map(&:title)
    assert_equal 0, program.report_sections.map(&:metrics).flatten.size
    program.create_default_metrics_for_program_management_report
    assert_equal [
      ["Membership", "Pending Membership Applications"],
      ["Membership", "Invitations Awaiting Acceptance"],
      ["Membership", "Application Accepted, Awaiting Signup"],
      ["Membership", "Mentors yet to Publish Profile"],
      ["Membership", "Mentees yet to Publish Profile"],
      ["Membership", "Mentors With Low Profile Scores"],
      ["Membership", "Mentees With Low Profile Scores"],
      ["Matching", "Never Connected Mentees"],
      ["Matching", "Currently Unconnected Mentees"],
      ["Matching", "Drafted Connections"],
      ["Matching", "Mentors In Drafted Connections"],
      ["Matching", "Mentees In Drafted Connections"],
      ["Matching", "Mentors Yet To Be Drafted"],
      ["Matching", "Mentees Yet To Be Drafted"],
      ["Matching", "Never Connected Mentors"]
    ], program.reload.report_sections.map(&:metrics).flatten.map{|m| [m.section.title, m.title] }
  end

  def test_enabled_organization_languages_including_english
    organization = programs(:org_primary)
    program = programs(:albers)
    assert organization.organization_languages.enabled.where(language_name: "es").exists?
    assert_equal_unordered ["English", "Hindi (Hindilu)", "Telugu (Telugulu)"], program.enabled_organization_languages_including_english.map(&:to_display)

    organization.organization_languages.where(language_name: "es").update_all(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    assert_equal_unordered ["English", "Hindi (Hindilu)"], program.enabled_organization_languages_including_english.map(&:to_display)
  end

  def test_languages_enabled_and_has_multiple_languages_for_everyone
    organization = programs(:org_primary)
    program = programs(:albers)

    organization.enable_feature(FeatureName::LANGUAGE_SETTINGS, false)
    organization.organization_languages.update_all(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    assert_false program.languages_enabled_and_has_multiple_languages_for_everyone?

    organization.enable_feature(FeatureName::LANGUAGE_SETTINGS, true)
    organization.organization_languages.update_all(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    assert_false program.reload.languages_enabled_and_has_multiple_languages_for_everyone?

    organization.enable_feature(FeatureName::LANGUAGE_SETTINGS, false)
    organization.organization_languages.update_all(enabled: OrganizationLanguage::EnabledFor::ALL)
    assert_false program.reload.languages_enabled_and_has_multiple_languages_for_everyone?

    organization.enable_feature(FeatureName::LANGUAGE_SETTINGS, true)
    organization.organization_languages.update_all(enabled: OrganizationLanguage::EnabledFor::ALL)
    assert program.reload.languages_enabled_and_has_multiple_languages_for_everyone?
  end

  def test_get_enabled_organization_language
    program = programs(:albers)
    organization = programs(:org_primary)
    assert organization.organization_languages.enabled.where(language_name: "es").exists?
    organization.organization_languages.where(language_name: "es").update_all(enabled: OrganizationLanguage::EnabledFor::NONE)
    assert_equal "English", program.get_enabled_organization_language(:en).title
    assert_equal "Hindi", program.get_enabled_organization_language(:de).title
    assert_nil program.get_enabled_organization_language(:es)
    assert_nil program.get_enabled_organization_language(:invalid)
  end

  def test_restricted_sti_attributes
    assert_equal Program::ORGANIZATION_ATTRIBUTES.map(&:to_s), Program.restricted_sti_attributes
    assert_equal Program::ORGANIZATION_ATTRIBUTES.map(&:to_s), Program.get_restricted_sti_attributes

    Program::ORGANIZATION_ATTRIBUTES.each do |attribute|
      program = programs(:albers)
      program.stubs("#{attribute}_changed?").returns(true)
      assert_false program.valid?
      assert_equal ["is invalid"], program.errors.messages[attribute]
    end
  end

  def test_set_position
    organization = programs(:org_primary)
    maximum_position = organization.programs.maximum(:position).to_i
    program = Program.new(organization: organization, engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, name: "Some program")
    program.root = "someroot1"
    program.save!
    new_position = maximum_position + 1
    assert_equal new_position, program.position
  end

  def test_set_position_for_first_program
    organization = Organization.create!({:name => "Some Organization"})
    maximum_position = organization.programs.maximum(:position).to_i
    program = Program.new(organization: organization, engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, name: "Some program")
    program.root = "someroot1"
    program.save!
    new_position = maximum_position + 1
    assert_equal new_position, program.position
  end

  def test_feedback_survey
    program = programs(:albers)
    survey = program.surveys.find_by(name: "Mentoring Connection Activity Feedback")
    assert_equal survey, program.feedback_survey
    assert_false program.feedback_survey_changed?(survey.id)
    assert_false program.feedback_survey_changed?(survey.id.to_s)
    assert program.feedback_survey_changed?(survey.id + 1)

    survey.update_attributes!(form_type: nil)
    assert program.feedback_survey_changed?(survey.id)
    assert program.feedback_survey_changed?(survey.id.to_s)
  end

  def test_report_alerts_association
    Report::Alert.destroy_all
    metric = Report::Metric.where(abstract_view_id: programs(:foster).abstract_views.collect(&:id)).first
    alert = create_alert_for_metric(metric, {})
    assert_equal [alert], programs(:foster).report_alerts
    assert_equal [], programs(:org_primary).report_alerts
    assert_difference "Report::Alert.count", -1 do
      programs(:foster).destroy
    end
  end

  def test_mentor_request_expiration_days_is_valid
    program = programs(:albers)
    program.update_attributes(:mentor_request_expiration_days => 0)
    assert_equal ["must be greater than 0"], program.errors[:mentor_request_expiration_days]
    assert_equal ["Expiration days must be greater than 0"], program.errors.full_messages

    program.update_attributes(:mentor_request_expiration_days => 'some text')
    assert_equal ["is not a number"], program.errors[:mentor_request_expiration_days]
    assert_equal ["Expiration days is not a number"], program.errors.full_messages

    program.update_attributes(:mentor_request_expiration_days => 4.54)
    assert_equal ["must be an integer"], program.errors[:mentor_request_expiration_days]
    assert_equal ["Expiration days must be an integer"], program.errors.full_messages

    program.update_attributes(:mentor_request_expiration_days => nil)
    assert_equal [], program.errors[:mentor_request_expiration_days]

    program.update_attributes(:mentor_request_expiration_days => 3)
    assert_equal [], program.errors[:mentor_request_expiration_days]
  end

  def test_circle_request_auto_expiration_days
    program = programs(:albers)
    program.update_attributes(:circle_request_auto_expiration_days => 0)
    assert_equal ["must be greater than 0"], program.errors[:circle_request_auto_expiration_days]

    program.update_attributes(:circle_request_auto_expiration_days => 'some text')
    assert_equal ["is not a number"], program.errors[:circle_request_auto_expiration_days]

    program.update_attributes(:circle_request_auto_expiration_days => 4.54)
    assert_equal ["must be an integer"], program.errors[:circle_request_auto_expiration_days]

    program.update_attributes(:circle_request_auto_expiration_days => nil)
    assert_equal [], program.errors[:circle_request_auto_expiration_days]
  end

  def test_project_request_reminder_duration_less_than_auto_expiration
    program = programs(:albers)
    
    program.update_attributes!(:circle_request_auto_expiration_days => nil, :project_request_reminder_duration => 5, :needs_project_request_reminder => true)
    assert_equal [], program.errors[:project_request_reminder_duration]
    
    program.update_attributes!(:circle_request_auto_expiration_days => 1, :project_request_reminder_duration => 5, :needs_project_request_reminder => false)
    assert_equal [], program.errors[:project_request_reminder_duration]

    program.update_attributes!(:circle_request_auto_expiration_days => 10, :project_request_reminder_duration => 5, :needs_project_request_reminder => true)
    assert_equal [], program.errors[:project_request_reminder_duration]
    
    program.update_attributes(:circle_request_auto_expiration_days => 1, :project_request_reminder_duration => 5, :needs_project_request_reminder => true)
    assert_equal ["should be less than expiration duration"], program.errors[:project_request_reminder_duration]
  end

  def test_meeting_request_auto_expiration_days
    program = programs(:albers)
    program.update_attributes(:meeting_request_auto_expiration_days => 0)
    assert_equal ["must be greater than 0"], program.errors[:meeting_request_auto_expiration_days]

    program.update_attributes(:meeting_request_auto_expiration_days => 'some text')
    assert_equal ["is not a number"], program.errors[:meeting_request_auto_expiration_days]

    program.update_attributes(:meeting_request_auto_expiration_days => 4.54)
    assert_equal ["must be an integer"], program.errors[:meeting_request_auto_expiration_days]

    program.update_attributes(:meeting_request_auto_expiration_days => nil)
    assert_equal [], program.errors[:meeting_request_auto_expiration_days]
  end

  def test_meeting_request_reminder_duration_less_than_meeting_request_auto_expiration_days
    program = programs(:albers)
    program.update_attributes!(:meeting_request_auto_expiration_days => nil, :meeting_request_reminder_duration => 5, :needs_meeting_request_reminder => true)
    program.update_attributes!(:meeting_request_auto_expiration_days => 1, :meeting_request_reminder_duration => 5, :needs_meeting_request_reminder => false)
    program.update_attributes!(:meeting_request_auto_expiration_days => 10, :meeting_request_reminder_duration => 5, :needs_meeting_request_reminder => true)
    program.update_attributes(:meeting_request_auto_expiration_days => 1, :meeting_request_reminder_duration => 5, :needs_meeting_request_reminder => true)
    assert_equal ["should be less than expiration duration"], program.errors[:meeting_request_reminder_duration]
  end

  def test_create_default_meeting_feedback_surveys
    program = programs(:foster)
    program.surveys.destroy_all
    assert_difference "MeetingFeedbackSurvey.count", 2 do
      assert_no_difference "SurveyQuestion.count" do
        Program.create_default_meeting_feedback_surveys(program.id, true)
      end
    end
    program.reload
    assert_equal ["Meeting Feedback Survey For Mentors", "Meeting Feedback Survey For Students"], program.surveys.map(&:name)
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], program.surveys.pluck(:role_name)

    program.surveys.destroy_all
    assert_difference "MeetingFeedbackSurvey.count", 2 do
      assert_difference "SurveyQuestion.count", 13 do
        Program.create_default_meeting_feedback_surveys(program.id)
      end
    end
  end

  def test_get_old_meeting_feedback_survey
    program = programs(:albers)
    assert_nil program.get_old_meeting_feedback_survey

    m = program.surveys.of_meeting_feedback_type.first
    m.update_attribute(:role_name, nil)
    assert_equal m.id, program.reload.get_old_meeting_feedback_survey.id
  end

  def test_get_meeting_feedback_survey_for_role
    program = programs(:albers)
    m = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)

    assert_equal RoleConstants::MENTOR_NAME, m.role_name
    assert_equal MeetingFeedbackSurvey.name, m.type
  end

  def test_get_meeting_feedback_survey_for_user_in_meeting
    program = programs(:albers)
    user = users(:f_admin)
    meeting = Meeting.first

    meeting.stubs(:get_role_of_user).with(user).returns(RoleConstants::MENTOR_NAME)
    m = program.get_meeting_feedback_survey_for_user_in_meeting(user, meeting)
    assert_equal RoleConstants::MENTOR_NAME, m.role_name
    assert_equal MeetingFeedbackSurvey.name, m.type

    meeting.stubs(:get_role_of_user).with(user).returns(RoleConstants::STUDENT_NAME)
    m = program.get_meeting_feedback_survey_for_user_in_meeting(user, meeting)
    assert_equal RoleConstants::STUDENT_NAME, m.role_name
    assert_equal MeetingFeedbackSurvey.name, m.type
  end

  def test_create_default_feedback_rating_questions
    program = programs(:albers)
    feedback_forms = Feedback::Form.where(:program_id => program.id)
    feedback_form = feedback_forms.first
    assert_equal 1, feedback_form.questions.count
    #destroying existing questions and form
    feedback_form.destroy

    # creating default questions
    program.create_default_feedback_rating_questions
    feedback_forms = Feedback::Form.where(:program_id => program.id)
    assert_equal 1, feedback_forms.count

    feedback_form = feedback_forms.first
    assert_equal 1, feedback_form.questions.count

    question = feedback_form.questions.first
    assert_equal question.question_text, "Comments"
    assert_equal question.question_type, CommonQuestion::Type::TEXT
  end

  def test_consider_mentoring_mode
    prog = programs(:albers)
    assert_false prog.consider_mentoring_mode?
    prog.enable_feature(FeatureName::CALENDAR, true)
    assert_false prog.consider_mentoring_mode?
    prog.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    assert prog.reload.consider_mentoring_mode?
  end

  def test_has_general_availability
    prog = programs(:albers)
    prog.enable_feature(FeatureName::CALENDAR, true)
    prog.calendar_setting.allow_mentor_to_configure_availability_slots = true
    prog.calendar_setting.allow_mentor_to_describe_meeting_preference = false
    prog.calendar_setting.save!

    assert_false prog.has_general_availability?
    prog.calendar_setting.update_attribute(:allow_mentor_to_describe_meeting_preference, true)
    assert prog.reload.has_general_availability?
  end

  def test_ongoing_mentoring_enabled
    # changing engagement type of program to career based with ongoin
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    assert programs(:albers).ongoing_mentoring_enabled?

    # changing engagement type of program to project based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert programs(:albers).ongoing_mentoring_enabled?

    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false programs(:albers).ongoing_mentoring_enabled?
  end

  def test_ab_test_enabled_for_default_enabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    assert Experiments::Example.enabled?

    prog = programs(:albers)
    assert prog.ab_test_enabled?('example')

    org = prog.organization
    org.ab_tests.create!(test: 'example', enabled: false)
    assert_false prog.reload.ab_test_enabled?('example')

    org.enable_ab_test('example', true)
    assert prog.reload.ab_test_enabled?('example')

    prog.ab_tests.create!(test: 'example', enabled: false)
    assert_false prog.reload.ab_test_enabled?('example')

    prog.enable_ab_test('example', true)
    assert prog.reload.ab_test_enabled?('example')
  end

  def test_ab_test_enabled_for_default_disabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Experiments::Example.stubs(:enabled?).returns(false)
    assert_false Experiments::Example.enabled?

    prog = programs(:albers)
    assert_false prog.ab_test_enabled?('example')

    org = prog.organization
    org.ab_tests.create!(test: 'example', enabled: true)
    assert prog.reload.ab_test_enabled?('example')

    org.enable_ab_test('example', false)
    assert_false prog.reload.ab_test_enabled?('example')

    prog.ab_tests.create!(test: 'example', enabled: true)
    assert prog.reload.ab_test_enabled?('example')

    prog.enable_ab_test('example', false)
    assert_false prog.reload.ab_test_enabled?('example')
  end

  def test_mentoring_role_ids
    program = programs(:albers)
    assert_equal_unordered [program.find_role('student').id, program.find_role('mentor').id], program.mentoring_role_ids
  end

  def test_should_display_proposed_projects_emails
    program = programs(:pbe)
    mentoring_roles = program.roles.for_mentoring
    student_role = mentoring_roles.where(name: "student").first

    assert student_role.needs_approval_to_create_circle?

    program.add_role_permission(student_role.name, RolePermission::PROPOSE_GROUPS)
    program.reload

    assert program.has_role_permission?(student_role.name, RolePermission::PROPOSE_GROUPS)
    assert program.should_display_proposed_projects_emails?

    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(false)
    assert_false program.should_display_proposed_projects_emails?

    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(true)

    mentoring_roles.each do |role|
      program.remove_role_permission(role.name, RolePermission::PROPOSE_GROUPS)
    end

    assert_false program.should_display_proposed_projects_emails?
  end

  def test_has_roles_that_can_invite
    program = programs(:ceg)
    assert program.has_roles_that_can_invite?
    non_admins = program.roles_without_admin_role
    non_admins.each do |non_admin|
      non_admins.each do |role|
        permission = "invite_#{role.name.pluralize}"
        program.remove_role_permission(non_admin.name, permission)
      end
    end
    assert_false program.has_roles_that_can_invite?
  end

  def test_should_send_admin_weekly_status
    program = programs(:albers)
    assert program.should_send_admin_weekly_status?

    program.membership_requests.destroy_all
    program.mentor_users.each do |mu|
      mu.created_at = Time.now - 3.weeks
      mu.save!
    end
    program.student_users.each do |su|
      su.created_at = Time.now - 3.weeks
      su.save!
    end

    program.articles.destroy_all

    program.enable_feature(FeatureName::CALENDAR)
    program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    program.save!

    program.mentor_requests.each do |mr|
      mr.created_at = Time.now - 1.day
      mr.save!
    end

    program.meeting_requests.each do |mr|
      mr.created_at = Time.now - 1.day
      mr.save!
    end

    program.groups.each do |gr|
      gr.published_at = Time.now - 1.day
      gr.save!
    end

    program.reload
    assert program.should_send_admin_weekly_status?

    program.mentor_request_style == Program::MentorRequestStyle::NONE
    program.engagement_type = Program::EngagementType::CAREER_BASED
    program.save!
    program.reload

    program.enable_feature(FeatureName::CALENDAR, false)
    program.reload
    program.groups.active.select(&:expiring_next_week?).each do |active_gr|
      active_gr.destroy
    end
    program.reload
    assert_false program.should_send_admin_weekly_status?

    create_survey_answer
    assert program.should_send_admin_weekly_status?
    SurveyAnswer.last.destroy

    org = programs(:org_primary)
    new_program = org.programs.new
    new_program.name = "Sample Program"
    new_program.root = "sampprog"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED
    new_program.save!

    assert_false new_program.should_send_admin_weekly_status?
  end

  def test_should_send_admin_weekly_status_for_project_based_program
    program = programs(:pbe)
    since = 1.week.ago

    program.project_requests.update_all(:created_at => 1.day.ago)
    program.users.update_all(:created_at => 2.weeks.ago)
    program.groups.published.destroy_all
    program.groups.active.destroy_all

    assert program.project_based?
    assert program.should_send_admin_weekly_status?

    program.groups.proposed.destroy_all
    assert program.should_send_admin_weekly_status?

    program.project_requests.active.recent(since).destroy_all
    assert_false program.should_send_admin_weekly_status?
  end

  def test_can_mentor_get_mentor_requests
    p = programs(:albers)
    p.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    p.save!
    assert p.ongoing_mentoring_enabled?
    assert p.can_mentor_get_mentor_requests?

    p.engagement_type = Program::EngagementType::CAREER_BASED
    p.save!
    assert_false p.ongoing_mentoring_enabled?
    assert_false p.can_mentor_get_mentor_requests?

    p.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    p.save!
    p.update_column(:mentor_request_style, Program::MentorRequestStyle::NONE)

    assert p.matching_by_admin_alone?
    assert_false p.can_mentor_get_mentor_requests?
  end

  def test_get_admin_weekly_status_hash
    p = programs(:albers)

    User.where("id IN (?)", (p.student_users+p.mentor_users).flatten).update_all(:created_at => 1.day.ago)
    p.membership_requests.update_all({:created_at => 1.day.ago})
    p.mentor_requests.update_all({:created_at => 1.day.ago})
    p.meeting_requests.update_all({:created_at => 1.day.ago})
    p.groups.update_all({:created_at => 1.day.ago})
    p.articles.update_all({:created_at => 1.day.ago})

    p.reload
    hash = p.get_admin_weekly_status_hash

    assert_equal hash[:membership_requests][:since], p.membership_requests.size
    assert_equal hash[:mentor_users][:since], p.mentor_users.size
    assert_equal hash[:student_users][:since], p.student_users.size
    assert_equal hash[:mentor_requests][:since], p.mentor_requests.size
    assert_equal hash[:articles][:since], p.articles.published.size

    assert_equal hash[:pending_mentor_requests][:since], p.mentor_requests.active.size
    assert_nil hash[:meeting_requests]
    assert_nil hash[:active_meeting_requests]

    assert_equal hash[:new_survey_responses], 0

    assert_false hash[:membership_requests][:values_not_changed]
    assert_false hash[:mentor_users][:values_not_changed]
    assert_false hash[:student_users][:values_not_changed]
    assert_false hash[:mentor_requests][:values_not_changed]
    assert_false hash[:pending_mentor_requests][:values_not_changed]

    assert_false hash[:articles][:values_not_changed]


    User.where("id IN (?)", (p.student_users+p.mentor_users).flatten).update_all(:created_at => 10.days.ago)
    p.membership_requests.update_all({:created_at => 10.days.ago})
    p.mentor_requests.update_all({:created_at => 10.days.ago})
    p.meeting_requests.update_all({:created_at => 10.days.ago})
    p.groups.update_all({:created_at => 10.days.ago})
    p.articles.update_all({:created_at => 10.days.ago})
    create_survey_answer

    p.reload
    hash = p.get_admin_weekly_status_hash

    assert_equal hash[:membership_requests][:week_before], p.membership_requests.size
    assert_equal hash[:mentor_users][:week_before], p.mentor_users.size
    assert_equal hash[:student_users][:week_before], p.student_users.size
    assert_equal hash[:mentor_requests][:week_before], p.mentor_requests.size
    assert_nil hash[:meeting_requests]
    assert_equal hash[:pending_mentor_requests][:week_before], p.mentor_requests.active.size
    assert_nil hash[:active_meeting_requests]
    assert_equal hash[:articles][:week_before], p.articles.published.size

    assert_false hash[:membership_requests][:values_not_changed]
    assert_false hash[:mentor_users][:values_not_changed]
    assert_false hash[:student_users][:values_not_changed]
    assert_false hash[:mentor_requests][:values_not_changed]
    assert_false hash[:pending_mentor_requests][:values_not_changed]
    assert_false hash[:articles][:values_not_changed]

    p.enable_feature(FeatureName::CALENDAR, true)
    p.reload
    hash = p.get_admin_weekly_status_hash

    assert_equal hash[:membership_requests][:week_before], p.membership_requests.size
    assert_equal hash[:mentor_users][:week_before], p.mentor_users.size
    assert_equal hash[:student_users][:week_before], p.student_users.size
    assert_equal hash[:mentor_requests][:week_before], p.mentor_requests.size
    assert_equal hash[:meeting_requests][:week_before], p.meeting_requests.size
    assert_equal hash[:pending_mentor_requests][:week_before], p.mentor_requests.active.size
    assert_equal hash[:active_meeting_requests][:week_before], p.meeting_requests.active.size
    assert_equal hash[:articles][:week_before], p.articles.published.size
    assert_equal hash[:new_survey_responses], 1

    assert_false hash[:membership_requests][:values_not_changed]
    assert_false hash[:mentor_users][:values_not_changed]
    assert_false hash[:student_users][:values_not_changed]
    assert_false hash[:mentor_requests][:values_not_changed]
    assert_false hash[:meeting_requests][:values_not_changed]
    assert_false hash[:pending_mentor_requests][:values_not_changed]
    assert_false hash[:active_meeting_requests][:values_not_changed]
    assert_false hash[:articles][:values_not_changed]

    p = programs(:pbe)

    p.groups.update_all({:created_at => 1.day.ago})
    p.project_requests.update_all({:created_at => 1.day.ago})

    p.reload
    hash = p.get_admin_weekly_status_hash

    assert_equal hash[:pending_projects_for_approval], p.groups.proposed.count
    assert_equal hash[:pending_project_requests][:since], p.project_requests.active.count
    assert_equal hash[:pending_project_requests][:week_before], p.project_requests.active.count
    assert_false hash[:pending_project_requests][:values_not_changed]
  end

  def test_email_priamry_color
    program = programs(:albers)

    Organization.any_instance.stubs(:email_priamry_color).returns("#333333")
    program.update_attributes(theme_id: nil)
    assert_false program.email_theme_override.present?
    assert_false program.theme_vars[EmailTheme::PRIMARY_COLOR].present?
    assert_equal program.email_priamry_color, "#333333"

    theme_vars = {EmailTheme::PRIMARY_COLOR => "#111112"}
    Program.any_instance.stubs(:theme_vars).returns(theme_vars)
    assert_equal program.email_priamry_color, "#111112"

    program.update_attribute(:email_theme_override, "#222222")
    assert_equal program.email_priamry_color, "#222222"
  end

  def test_get_role_names_without_admin_role
    program = programs(:albers)
    assert_equal ["mentor", "student", "user"], program.role_names_without_admin_role
  end

  def test_get_searchable_classes
    user = users(:f_student)
    program = user.program
    assert_equal [User,QaQuestion,Article, Resource, Topic], program.searchable_classes(user)
    remove_role_permission(fetch_role(:albers, :student), "view_mentors")
    remove_role_permission(fetch_role(:albers, :student), "view_students")
    remove_role_permission(fetch_role(:albers, :student), "view_users")
    remove_role_permission(fetch_role(:albers, :student), "view_articles")
    assert_equal [QaQuestion, Resource, Topic], program.searchable_classes(user.reload)
    remove_role_permission(fetch_role(:albers, :student), "view_questions")
    assert_equal [Resource, Topic], program.searchable_classes(user.reload)
    add_role_permission(fetch_role(:albers, :student), "view_articles")
    assert_equal [Article, Resource, Topic], program.searchable_classes(user.reload)
  end

  def test_mail_classes_at_program_level
    assert_equal_unordered [MeetingRequestStatusAcceptedNotificationToSelf, NewArticleNotification, MeetingCreationNotificationToOwner, MembershipRequestSentNotification], Program::MAILS_TO_DISABLE_BY_DEFAULT.mail_classes_at_program_level
  end

  def test_disable_program_observer
    assert_false  Program.new.disable_program_observer
  end

  def test_tracks_and_portals_scope
    portal = programs(:primary_portal)
    track = programs(:nch_mentoring)
    assert Program.portals.include?(portal)
    assert_false Program.portals.include?(track)

    assert Program.tracks.include?(track)
    assert_false Program.tracks.include?(portal)
  end

  def test_zero_match_score_message_translated
    program = programs(:ceg)
    assert_equal "Not a match", program.zero_match_score_message
    Globalize.with_locale(:en) do
      program.update_attribute(:zero_match_score_message, "english message")
    end
    Globalize.with_locale(:"fr-CA") do
      program.update_attribute(:zero_match_score_message, "french message")
    end
    Globalize.with_locale(:en) do
      assert_equal "english message", program.zero_match_score_message
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french message", program.zero_match_score_message
    end
  end

  def test_program_has_one_instruction
    program = programs(:albers)
    MentorRequest::Instruction.create!(:program => program)
    MembershipRequest::Instruction.create!(:program => program)
    assert_equal MentorRequest::Instruction.last.program, program
    assert_equal MembershipRequest::Instruction.last.program, program
    assert_equal true, program.mentor_request_instruction.translations.loaded?
    assert_equal true, program.membership_instruction.translations.loaded?
  end

  def test_populate_zero_match_score_message_with_default_value_if_nil
    program = programs(:albers)
    program.populate_zero_match_score_message_with_default_value_if_nil([:en, :"fr-CA"])

    GlobalizationUtils.run_in_locale(:en) do
      assert_equal "program_settings_strings.content.zero_match_score_message_placeholder".translate, program.zero_match_score_message
    end
    GlobalizationUtils.run_in_locale(:"fr-CA") do
      assert_equal "program_settings_strings.content.zero_match_score_message_placeholder".translate, program.zero_match_score_message
    end
  end

  def test_has_many_program_events
    prog = programs(:albers)
    assert_equal_unordered [program_events(:ror_meetup), program_events(:birthday_party)], prog.program_events
    assert_equal true, prog.program_events.first.translations.loaded?
  end

  def test_program_root_name
    assert_equal "p1", Program.program_root_name
    assert_equal "p8", Program.program_root_name(8)
  end

  def test_engagement_enabled
    program  = programs(:albers)
    assert program.engagement_enabled?
    program.engagement_type = nil
    program.save!
    assert_false program.engagement_enabled?
    program.enable_feature(FeatureName::CALENDAR, true)
    assert program.engagement_enabled?

    portal = programs(:primary_portal)
    assert_false portal.engagement_enabled?
  end

  def test_matching_enabled
    program  = programs(:albers)
    assert program.matching_enabled?
    program.engagement_type = nil
    program.save!
    assert_false program.matching_enabled?
    program.enable_feature(FeatureName::CALENDAR, true)
    assert program.matching_enabled?

    portal = programs(:primary_portal)
    assert_false portal.matching_enabled?
  end

  def test_dual_request_mode
    student = users(:f_student)
    mentor = users(:f_mentor)
    program = programs(:albers)

    Program.any_instance.stubs(:calendar_enabled?).returns(false)
    assert_false program.dual_request_mode?(mentor, student, true)


    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    User.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false program.dual_request_mode?(mentor, student, true)

    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(true)
    User.any_instance.stubs(:can_view_mentoring_calendar?).returns(false)
    assert_false program.dual_request_mode?(mentor, student, true)

    User.any_instance.stubs(:can_view_mentoring_calendar?).returns(true)
    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(false)
    assert_false program.dual_request_mode?(mentor, student, true)

    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(true)
    assert_false program.dual_request_mode?(mentor, student, true)
    assert program.dual_request_mode?(mentor, student, false)

    mentor.received_meeting_requests.where(sender_id: student.id).destroy_all
    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([true, ""])
    assert_false program.dual_request_mode?(mentor, student, true)
    assert program.dual_request_mode?(mentor, student, false)

    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([false, ""])
    assert program.dual_request_mode?(mentor, student, true)
    assert program.dual_request_mode?(mentor, student, false)
  end

  def test_demographic_report_view_columns
    expected_output = ReportViewColumn::DemographicReport::Key::DEFAULT_KEYS +
                      [ReportViewColumn::DemographicReport::Key::MENTORS_COUNT,
                       ReportViewColumn::DemographicReport::Key::MENTEES_COUNT]
    assert_equal expected_output, programs(:albers).demographic_report_view_columns
  end

  def test_should_import_and_setup_campaign
    program = programs(:albers)
    program.program_invitation_campaign.destroy
    program.abstract_campaigns.destroy_all
    assert_difference 'CampaignManagement::AbstractCampaign.count', 3 do
      program.populate_default_campaigns
    end
    assert_equal CampaignManagement::AbstractCampaign.last(3).collect(&:title), ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up"]
    program.reload
    assert program.program_invitation_campaign.featured
    template = program.program_invitation_campaign.campaign_messages.first.email_template
    assert_equal ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid], template.uid
  end

  def test_should_not_create_default_campaigns_if_not_enabled
    program = programs(:albers)
    program.program_invitation_campaign.destroy
    program.abstract_campaigns.destroy_all
    assert_difference 'CampaignManagement::AbstractCampaign.count', 3 do
      program.populate_default_campaigns
    end
    program.reload

    program.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT, false)
    program.program_invitation_campaign.destroy
    program.abstract_campaigns.destroy_all
    assert_difference 'CampaignManagement::AbstractCampaign.count', 1 do
      program.populate_default_campaigns
    end
    assert_empty program.reload.user_campaigns
  end

  def test_logo_url
    program = programs(:albers)
    asset = program.create_program_asset
    asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    asset.save!
    translation_id = asset.translation.id
    assert_match(/logos\/#{translation_id}\/original\/test_pic.png/, program.logo_url)
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_match(/logos\/#{translation_id}\/original\/test_pic.png/, program.logo_url)
    end
  end

  def test_logo_url_in_non_default_locale
    program = programs(:albers)
    asset = program.create_program_asset
    GlobalizationUtils.run_in_locale("fr-CA") do
      asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      asset.save!
      translation_id = asset.translation.id
      assert_match(/logos\/#{translation_id}\/original\/test_pic.png/, program.logo_url)
    end
  end

  def test_banner_url
    program = programs(:albers)
    asset = program.create_program_asset
    asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    asset.save!
    translation_id = asset.translation.id
    assert_match(/banners\/#{translation_id}\/original\/test_pic.png/, program.banner_url)
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_match(/banners\/#{translation_id}\/original\/test_pic.png/, program.banner_url)
    end
  end

  def test_banner_url_in_non_default_locale
    program = programs(:albers)
    asset = program.create_program_asset
    GlobalizationUtils.run_in_locale("fr-CA") do
      asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      asset.save!
      translation_id = asset.translation.id
      assert_match(/banners\/#{translation_id}\/original\/test_pic.png/, program.banner_url)
    end
  end

  def test_allows_apply_to_join_for_a_role
    program = programs(:albers)

    roles = program.roles_without_admin_role

    assert_equal 3, roles.count

    mentor_role = roles.find_by_name(RoleConstants::MENTOR_NAME)
    student_role = roles.find_by_name(RoleConstants::STUDENT_NAME)
    user_role = roles.find_by_name("user")

    assert mentor_role.can_show_apply_to_join_ticked?(program)
    assert student_role.can_show_apply_to_join_ticked?(program)
    assert_false user_role.can_show_apply_to_join_ticked?(program)

    assert program.allows_apply_to_join_for_a_role?

    Role.any_instance.stubs(:can_show_apply_to_join_ticked?).returns(true)
    assert program.allows_apply_to_join_for_a_role?

    Role.any_instance.stubs(:can_show_apply_to_join_ticked?).returns(false)
    assert_false program.allows_apply_to_join_for_a_role?
  end

  def test_allows_users_to_apply_to_join_in_project
    program = programs(:pbe)

    roles = program.roles.for_mentoring

    assert_equal 3, roles.count

    mentor_role = roles.find_by_name(RoleConstants::MENTOR_NAME)
    student_role = roles.find_by_name(RoleConstants::STUDENT_NAME)
    teacher_role = roles.find_by_name(RoleConstants::TEACHER_NAME)

    assert mentor_role.has_permission_name?("send_project_request")
    assert student_role.has_permission_name?("send_project_request")
    assert_false teacher_role.has_permission_name?("send_project_request")

    assert program.allows_users_to_apply_to_join_in_project?

    programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    mentor_role.reload
    assert_false mentor_role.has_permission_name?("send_project_request")
    assert program.allows_users_to_apply_to_join_in_project?

    programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).remove_permission("send_project_request")
    student_role.reload
    assert_false student_role.has_permission_name?("send_project_request")
    assert_false program.allows_users_to_apply_to_join_in_project?
  end

  def test_update_bulk_match_default
    program = programs(:albers)
    assert_equal 1, program.student_bulk_match.default
    assert_equal 0, program.mentor_bulk_match.default
    assert_equal 0, program.bulk_recommendation.default
    program.update_bulk_match_default(BulkRecommendation.name)
    assert_equal 0, program.student_bulk_match.reload.default
    assert_equal 0, program.mentor_bulk_match.reload.default
    assert_equal 1, program.bulk_recommendation.reload.default

    program.update_bulk_match_default(BulkMatch.name)
    assert_equal 1, program.student_bulk_match.reload.default
    assert_equal 0, program.mentor_bulk_match.reload.default
    assert_equal 0, program.bulk_recommendation.reload.default

    program.update_bulk_match_default(BulkMatch.name, BulkMatch::OrientationType::MENTOR_TO_MENTEE)
    assert_equal 0, program.student_bulk_match.reload.default
    assert_equal 1, program.mentor_bulk_match.reload.default
    assert_equal 0, program.bulk_recommendation.reload.default    

    program = programs(:no_subdomain)
    assert_nil program.bulk_recommendation
    program.update_bulk_match_default(BulkRecommendation.name)
  end

  def test_get_program_health_url
    program = programs(:albers)
    assert_equal program.get_program_health_url, "http://chronusmentor.chronus.com/entries/29618078-Measuring-the-health-of-your-program"
  end

  def test_survey_question_ids
    program = programs(:albers)
    q = create_survey_question
    assert program.survey_question_ids.include?(q.id)

    count = program.survey_question_ids.size
    assert_difference "SurveyQuestion.count", -count do
      program.surveys.destroy_all
    end
  end

  def test_removed_as_feature_from_ui
    program = programs(:albers)
    removed_feature = [
      FeatureName::OFFER_MENTORING, FeatureName::CALENDAR, FeatureName::CAREER_DEVELOPMENT
    ] + FeatureName.tandem_features
    assert_equal_unordered removed_feature, program.removed_as_feature_from_ui

    #standalone organization case
    program = programs(:foster)
    removed_feature = [
      FeatureName::OFFER_MENTORING, FeatureName::CALENDAR
    ] + FeatureName.tandem_features
    assert_equal_unordered removed_feature, program.removed_as_feature_from_ui

  end

  def test_create_calendar_setting_for_program
    program = programs(:nch_mentoring)
    program.enable_feature(FeatureName::CALENDAR)
    program.calendar_setting.destroy
    program.reload

    Program.any_instance.expects(:create_calendar_setting).once
    Program.create_calendar_setting_for_program(program.id)

    non_existant_program_id = 12312
    Program.any_instance.expects(:create_calendar_setting).never
    Program.create_calendar_setting_for_program(non_existant_program_id)
  end

  def test_allow_multiple_groups_between_users
    program = programs(:albers)

    assert program.career_based?
    program.stubs(:project_based?).returns(false)
    program.stubs(:allow_one_to_many_mentoring?).returns(false)
    program.stubs(:matching_by_admin_alone?).returns(false)
    program.stubs(:mentor_offer_enabled?).returns(false)
    assert_false program.allow_multiple_groups_between_student_mentor_pair?
    assert_false program.show_existing_groups_alert?

    program.stubs(:project_based?).returns(true)
    program.stubs(:career_based?).returns(false)
    assert program.allow_multiple_groups_between_student_mentor_pair?
    assert_false program.show_existing_groups_alert?

    program.stubs(:project_based?).returns(false)
    program.stubs(:career_based?).returns(true)
    program.stubs(:allow_one_to_many_mentoring?).returns(true)
    assert_false program.allow_multiple_groups_between_student_mentor_pair?
    assert_false program.show_existing_groups_alert?

    program.stubs(:matching_by_admin_alone?).returns(true)
    assert program.allow_multiple_groups_between_student_mentor_pair?
    assert program.show_existing_groups_alert?

    program.stubs(:mentor_offer_enabled?).returns(true)
    assert_false program.allow_multiple_groups_between_student_mentor_pair?
    assert_false program.show_existing_groups_alert?

    program.stubs(:mentor_offer_enabled?).returns(false)
    program.stubs(:allow_one_to_many_mentoring?).returns(false)
    assert_false program.allow_multiple_groups_between_student_mentor_pair?
    assert_false program.show_existing_groups_alert?
  end

  def test_get_mentor_recommendation_example_content
    # Program is not matching by mentee and admin with preference and allows end users to see match scores
    program = programs(:albers)
    assert_match "Connect", program.get_mentor_recommendation_example_content
    assert_match "90%", program.get_mentor_recommendation_example_content
    assert_match "match", program.get_mentor_recommendation_example_content
    assert_no_match(/Request Mentoring Connection/, program.get_mentor_recommendation_example_content)

    # Program is not matching by mentee and admin with preference and does not allow end users to see match scores
    program.allow_end_users_to_see_match_scores = false
    program.save!
    assert_match "Connect", program.get_mentor_recommendation_example_content
    assert_no_match(/90%/, program.get_mentor_recommendation_example_content)
    assert_no_match(/match/, program.get_mentor_recommendation_example_content)
    assert_no_match(/Request Mentoring Connection/, program.get_mentor_recommendation_example_content)

    # Program is matching by mentee and admin with preference and allows end users to see match scores
    program.allow_preference_mentor_request = true
    program.save!
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_ADMIN)
    assert program.reload.matching_by_mentee_and_admin_with_preference?

    assert_no_match(/90%/, program.get_mentor_recommendation_example_content)
    assert_no_match(/match/, program.get_mentor_recommendation_example_content)
    assert_match "Request Mentoring Connection", program.get_mentor_recommendation_example_content

    # Program is matching by mentee and admin with preference and does not allow end users to see match scores
    program.allow_end_users_to_see_match_scores = true
    program.save!
    assert_match "90%", program.get_mentor_recommendation_example_content
    assert_match "match", program.get_mentor_recommendation_example_content
    assert_match "Request Mentoring Connection", program.get_mentor_recommendation_example_content
  end


  def test_user_csv_import_association
    program = programs(:albers)

    assert_equal program.user_csv_imports, []

    user_csv_import = program.user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.update_attribute(:local_csv_file_path, UserCsvImport.save_user_csv_to_be_imported(fixture_file_upload("/files/csv_import.csv", "text/csv").read, "csv_import.csv", user_csv_import.id))

    assert_equal program.user_csv_imports, [user_csv_import]
  end

  def test_delayed_sending_of_program_invitations_admin
    member = members(:dormant_member)
    program = programs(:no_subdomain)

    assert_emails do
      assert_difference "ProgramInvitation.count" do
        Program.delayed_sending_of_program_invitations(program.id, [member.id], nil, users(:no_subdomain_admin).id, [RoleConstants::MENTOR_NAME], 0, locale: :de, is_sender_admin: true)
      end
    end
    assert_equal "de", program.program_invitations.last.locale
    email = ActionMailer::Base.deliveries.last
    assert_equal member.email, email.to[0]
    assert_match "Invitation to join #{program.name} [[ áš ]] a mentor", email.subject
    assert_match "I would like to invite you to join", get_html_part_from(email)
  end

  def test_delayed_sending_of_program_invitations_enduser
    member = members(:f_student)
    invitor = users(:f_mentor)
    program = invitor.program
    assert invitor.can_invite_mentors?

    assert_emails do
      assert_difference "ProgramInvitation.count" do
        Program.delayed_sending_of_program_invitations(program.id, [member.id], "test messages", invitor.id, [RoleConstants::MENTOR_NAME], 0, is_sender_admin: false)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal member.email, email.to[0]
    assert_match "Invitation from #{invitor.name} to join #{program.name} as a mentor!", email.subject
    assert_match "test messages", get_html_part_from(email)
  end

  def test_handle_program_asset_of_standalone_program
    standalone_program = programs(:foster)
    standalone_organization = standalone_program.organization
    assert_no_difference "ProgramAsset.count" do
      standalone_program.handle_program_asset_of_standalone_program
    end

    standalone_program__program_asset = standalone_program.create_program_asset
    standalone_program__program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    standalone_program__program_asset.save!
    standalone_organization__program_asset = standalone_organization.create_program_asset
    standalone_organization__program_asset.logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    standalone_organization__program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    standalone_organization__program_asset.save!
    assert_difference "ProgramAsset.count", -1 do
      standalone_program.reload.handle_program_asset_of_standalone_program
    end
    assert_raise ActiveRecord::RecordNotFound do
      standalone_program__program_asset.reload
    end
    standalone_organization__program_asset.reload
    assert_equal "test_pic.png", standalone_organization__program_asset.logo_file_name
    assert_equal "test_pic.png", standalone_organization__program_asset.banner_file_name
  end

  def test_handle_organization_features_of_standalone_program
    standalone_program = programs(:foster)
    standalone_organization = standalone_program.organization
    assert_no_difference "OrganizationFeature.count" do
      standalone_program.handle_organization_features_of_standalone_program
    end

    feature1_id = Feature.find_by(name: FeatureName::USER_CSV_IMPORT).id
    feature2_id = Feature.find_by(name: FeatureName::MENTOR_RECOMMENDATION).id
    feature3_id = Feature.find_by(name: FeatureName::MODERATE_FORUMS).id
    program_level_only_feature_id = Feature.find_by(name: FeatureName::CALENDAR).id
    OrganizationFeature.create!(organization_id: standalone_organization.id, feature_id: feature1_id, enabled: true)
    OrganizationFeature.create!(organization_id: standalone_program.id, feature_id: feature1_id, enabled: false)
    OrganizationFeature.create!(organization_id: standalone_program.id, feature_id: feature2_id, enabled: true)
    OrganizationFeature.create!(organization_id: standalone_organization.id, feature_id: feature3_id, enabled: true)
    OrganizationFeature.create!(organization_id: standalone_program.id, feature_id: program_level_only_feature_id, enabled: true)
    assert_difference "OrganizationFeature.count", -1 do
      standalone_program.handle_organization_features_of_standalone_program
    end
    assert_equal [program_level_only_feature_id], standalone_program.reload.organization_features.pluck(:feature_id)
    assert_false standalone_organization.reload.organization_features.find_by(feature_id: feature1_id).enabled
    assert_equal true, standalone_organization.reload.organization_features.find_by(feature_id: feature2_id).enabled
    assert_equal true, standalone_organization.reload.organization_features.find_by(feature_id: feature3_id).enabled
  end

  def test_handle_pages_of_standalone_program
    standalone_program = programs(:foster)
    standalone_organization = standalone_program.organization
    pages = standalone_organization.pages
    assert_equal 3, pages.size
    assert_empty standalone_program.pages
    pages.first(2).each { |page| page.update_attribute(:program_id, standalone_program.id) }
    pages[-1].update_attribute(:position, 50)

    assert_no_difference "Page.count" do
      standalone_program.handle_pages_of_standalone_program
    end
    assert_equal [50, 51, 52], standalone_organization.reload.pages.pluck(:position)
    assert_empty standalone_program.reload.pages
  end

  def test_community_features_enabled
    program = programs(:pbe)
    program.enable_feature(FeatureName::RESOURCES, false)
    program.enable_feature(FeatureName::ARTICLES, false)
    program.enable_feature(FeatureName::FORUMS, false)
    program.enable_feature(FeatureName::ANSWERS, false)
    assert_false program.community_features_enabled?

    program.enable_feature(FeatureName::RESOURCES)
    assert program.community_features_enabled?

    program.enable_feature(FeatureName::ARTICLES)
    assert program.community_features_enabled?

    program.enable_feature(FeatureName::FORUMS)
    assert program.community_features_enabled?

    program.enable_feature(FeatureName::ANSWERS)
    assert program.community_features_enabled?
  end

  def test_get_groups_report_view_columns
    program = programs(:albers)
    update_groups_report_view!(program, ReportViewColumn::GroupsReport.all.keys)

    ReportViewColumn.expects(:get_applicable_groups_report_columns).with(program).once.returns([])
    assert_empty program.get_groups_report_view_columns

    ReportViewColumn.expects(:get_applicable_groups_report_columns).with(program).once.returns(ReportViewColumn::GroupsReport.message_columns)
    assert_equal_unordered ReportViewColumn::GroupsReport.message_columns, program.get_groups_report_view_columns.collect(&:column_key)
  end

  def test_group_messaging_enabled
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    assert program.group_messaging_enabled?

    program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    assert program.group_messaging_enabled?

    mentoring_model.update_column(:allow_messaging, false)
    assert_false program.reload.group_forum_enabled?
  end

  def test_group_forum_enabled
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    assert_false program.group_forum_enabled?

    mentoring_model.update_column(:allow_forum, true)
    assert_false program.reload.group_forum_enabled?

    program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    assert program.group_forum_enabled?
  end

  def test_show_groups_report
    program = programs(:albers)
    ReportViewColumn.expects(:get_applicable_groups_report_columns).with(program, ReportViewColumn::GroupsReport.activity_columns).once.returns([])
    assert_false program.show_groups_report?

    ReportViewColumn.expects(:get_applicable_groups_report_columns).once.returns(ReportViewColumn::GroupsReport.message_columns)
    assert program.show_groups_report?

    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_false program.show_groups_report?
  end

  def test_has_many_user_activities
    assert 0, programs(:albers).user_activities.count
    UserActivity.create!(program_id: programs(:albers))
    assert 1, programs(:albers).user_activities.count
  end

  def test_permitted_closure_reasons
    program = programs(:albers)
    closure_reason = program.group_closure_reasons.create!(reason: "eng reason")
    GlobalizationUtils.run_in_locale(:"fr-CA") do
      closure_reason.update_attributes({reason: ""})
      assert_equal "eng reason", closure_reason.reason
    end
    assert_equal "eng reason", closure_reason.reason
    assert program.permitted_closure_reasons.include?(closure_reason)
  end

  def test_create_organization_admins_sub_program_admins
    program = programs(:albers)
    organization = program.organization

    program.all_users.delete_all
    non_suspended_admin = organization.members.admins.non_suspended.first
    non_suspended_admin.update_column(:state, Member::Status::SUSPENDED)

    non_suspended_admins = organization.members.admins.non_suspended
    program.create_organization_admins_sub_program_admins
    program.reload

    assert_equal non_suspended_admins.count, program.all_users.count
  end

  def test_create_program_languages
    program = programs(:albers)
    organization = program.organization

    program.program_languages.delete_all
    assert_difference "ProgramLanguage.count", organization.organization_languages.size do
      program.create_program_languages
    end
  end

  def test_can_show_apply_to_join_mailer_templates
    program = programs(:albers)
    organization = program.organization
    program.stubs(:allows_apply_to_join_for_a_role?).returns(true)
    assert program.can_show_apply_to_join_mailer_templates?
    program.stubs(:allows_apply_to_join_for_a_role?).returns(false)
    assert_false program.can_show_apply_to_join_mailer_templates?
    program.stubs(:allows_apply_to_join_for_a_role?).returns(true)
    organization.stubs(:chronus_auth).returns([])
    assert_false program.can_show_apply_to_join_mailer_templates?
  end

  def test_get_positive_outcomes_questions_array
    program = programs(:albers)
    program.surveys.of_engagement_type.destroy_all
    program.stubs(:ongoing_mentoring_enabled?).returns(true)
    survey = create_engagement_survey
    q1 = create_survey_question(
      {question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "get,set,go", survey: survey})
    choices_hash = q1.question_choices.index_by(&:text)
    q1.update_attributes!(positive_outcome_options: choices_hash["get"].id.to_s)
    assert_equal [{:text=>"Some survey", :children=>[{:id=>q1.id, :text=>"Whats your age?", :choices=>[{:id=>choices_hash["get"].id, :text=>"get"}, {:id=>choices_hash["set"].id, :text=>"set"}, {:id=>choices_hash["go"].id, :text=>"go"}], :selected=>[choices_hash["get"].id.to_s]}]}],  program.reload.get_positive_outcomes_questions_array
    survey.destroy!

    survey1 = create_engagement_survey
    create_survey_question({:survey => survey1})
    assert_equal [{:text=>"Some survey", :children=>[]}], program.reload.get_positive_outcomes_questions_array
    survey1.destroy!

    survey = create_engagement_survey
    q2 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})
    choices_hash = q2.question_choices.index_by(&:text)
    q2.update_attributes!(positive_outcome_options_management_report: choices_hash["get"].id.to_s)
    assert_equal [{:text=>"Some survey", :children=>[{:id=>q2.id, :text=>"Whats your age?", :choices=>[{:id=>choices_hash["get"].id, :text=>"get"}, {:id=>choices_hash["set"].id, :text=>"set"}, {:id=>choices_hash["go"].id, :text=>"go"}], :selected=>[choices_hash["get"].id.to_s]}]}],  program.reload.get_positive_outcomes_questions_array(true)
  end

  def test_meeting_or_engagement_surveys_scope
    program = programs(:albers)
    program.stubs(:ongoing_mentoring_enabled?).returns(true)
    assert_equal 5, program.meeting_or_engagement_surveys_scope.count
    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_equal 2, program.meeting_or_engagement_surveys_scope.count
  end

  def test_update_positive_outcomes_options
    program = programs(:albers)
    survey = create_engagement_survey
    q1 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})
    choices_hash = q1.question_choices.index_by(&:text)
    page_data = {q1.id => choices_hash["get"].id}
    program.update_positive_outcomes_options!(page_data)
    assert_equal choices_hash["get"].id.to_s, q1.reload.positive_outcome_options

    page_data = {}
    program.update_positive_outcomes_options!(page_data)
    assert_nil q1.reload.positive_outcome_options

    page_data = {q1.id => choices_hash["get"].id}
    program.update_positive_outcomes_options!(page_data, true)
    assert_equal choices_hash["get"].id.to_s, q1.reload.positive_outcome_options_management_report
  end

  def test_published_groups_in_date_range
    program = programs(:albers)
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    members(:f_admin).update_attribute(:time_zone, "Asia/Kolkata")

    start_time = (Time.now.utc-10.days).to_time
    end_time = (Time.now.utc + 10.days).to_time

    assert_equal_unordered groups(:mygroup, :group_5, :group_inactive, :group_4, :old_group, :group_2, :group_3).collect { |grp| grp.id }, program.published_groups_in_date_range(start_time, end_time).pluck(:id)

    g = groups(:mygroup)
    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    g.update_attributes!(closed_at: Time.now.utc + 2.day)

    g = groups(:group_2)
    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    g.update_attributes!(closed_at: Time.now.utc-12.days)

    g = groups(:group_3)
    g.update_attributes!(published_at: Time.now.utc + 12.days)
    assert_equal_unordered groups(:mygroup, :group_5, :group_inactive, :group_4, :old_group).collect { |grp| grp.id }, program.published_groups_in_date_range(start_time, end_time).pluck(:id)
  end

  def test_roles_applicable_for_auto_approval
    program = programs(:albers)
    assert_equal ["mentor", "student"], program.roles_applicable_for_auto_approval.pluck(:name)
  end

  def test_can_end_users_see_match_scores
    program = programs(:albers)
    program.stubs(:allow_end_users_to_see_match_scores?).returns(true)
    program.stubs(:explicit_user_preferences_enabled?).returns(true)
    assert_false program.can_end_users_see_match_scores?

    program.stubs(:explicit_user_preferences_enabled?).returns(false)
    assert program.can_end_users_see_match_scores?

    program.stubs(:allow_end_users_to_see_match_scores?).returns(false)
    assert_false program.can_end_users_see_match_scores?
  end

  def test_ignored_survey_satisfaction_configuration
    program = programs(:albers)

    program.stubs(:include_surveys_for_satisfaction_rate).returns(true)
    assert_false program.ignored_survey_satisfaction_configuration?

    program.stubs(:include_surveys_for_satisfaction_rate).returns(nil)
    assert_false program.ignored_survey_satisfaction_configuration?

    program.stubs(:include_surveys_for_satisfaction_rate).returns(false)
    assert program.ignored_survey_satisfaction_configuration?
  end

  def test_get_positive_outcome_surveys
    program = programs(:albers)

    assert_equal [], program.get_positive_outcome_surveys

    scoped_survey_ids = program.meeting_or_engagement_surveys_scope.pluck(:id)
    survey_question = SurveyQuestion.where(program_id: program.id, survey_id: scoped_survey_ids).first
    survey_question.update_attribute(:positive_outcome_options, "hello")
    assert_equal survey_question.survey, program.get_positive_outcome_surveys.first
  end

  def test_allow_user_to_see_match_score
    program = programs(:albers)
    user = users(:f_student)

    program.stubs(:allow_end_users_to_see_match_scores?).returns(true)
    user.stubs(:explicit_preferences_configured?).returns(true)
    assert_false program.allow_user_to_see_match_score?(user)

    user.stubs(:explicit_preferences_configured?).returns(false)
    assert program.allow_user_to_see_match_score?(user)

    program.stubs(:allow_end_users_to_see_match_scores?).returns(false)
    assert_false program.allow_user_to_see_match_score?(user)
  end

  def test_get_match_report_admin_view
    program = programs(:albers)
    section_type = MatchReport::Sections::MentorDistribution
    role_type = RoleConstants::MENTOR_NAME
    assert_equal program.match_report_admin_views.find_by(admin_view: AbstractView.find_by(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS, program_id: program.id)), program.get_match_report_admin_view(section_type, role_type)
    role_type = RoleConstants::STUDENT_NAME
    assert_equal program.match_report_admin_views.find_by(admin_view: AbstractView.find_by(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, program_id: program.id)),program.get_match_report_admin_view(section_type, role_type)
    section_type = MatchReport::Sections::MenteeActions
    assert_equal program.match_report_admin_views.find_by(admin_view: AbstractView.find_by(default_view: AbstractView::DefaultType::MENTEES, program_id: program.id)),program.get_match_report_admin_view(section_type, role_type)
  end

  def test_is_ongoing_carrer_based_matching_by_admin_alone
    program = programs(:albers)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:matching_by_admin_alone?).returns(true)
    assert program.is_ongoing_carrer_based_matching_by_admin_alone?

    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:matching_by_admin_alone?).returns(false)
    assert_false program.is_ongoing_carrer_based_matching_by_admin_alone?

    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_admin_alone?).returns(true)
    assert_false program.is_ongoing_carrer_based_matching_by_admin_alone?

    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_admin_alone?).returns(false)
    assert_false program.is_ongoing_carrer_based_matching_by_admin_alone?
  end

  def test_preferece_based_mentor_lists_enabled
    program = programs(:albers)
    program.stubs(:career_based_self_match_or_flash?).returns(false)
    program.stubs(:has_feature?).with(FeatureName::POPULAR_CATEGORIES).returns(false)
    Role.any_instance.stubs(:has_permission_name?).with('view_mentors').returns(true)
    assert_false program.preferece_based_mentor_lists_enabled?

    program.stubs(:has_feature?).with(FeatureName::POPULAR_CATEGORIES).returns(true)
    program.stubs(:career_based_self_match_or_flash?).returns(true)
    assert program.preferece_based_mentor_lists_enabled?

    Role.any_instance.stubs(:has_permission_name?).with('view_mentors').returns(false)
    assert_false program.preferece_based_mentor_lists_enabled?

    program.stubs(:has_feature?).with(FeatureName::POPULAR_CATEGORIES).returns(false)
    Role.any_instance.stubs(:has_permission_name?).with('view_mentors').returns(true)
    assert_false program.preferece_based_mentor_lists_enabled?
  end

  private

  def reset_match_setting(program)
    match_setting = program.match_setting
    match_setting.update_attributes!(min_match_score: 0.0, max_match_score: 0.0)
  end
end
