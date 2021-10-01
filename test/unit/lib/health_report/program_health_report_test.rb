require_relative './../../../test_helper'

class HealthReport::ProgramHealthReportTest < ActiveSupport::TestCase

  def setup
    super
    @mentor_role = [RoleConstants::MENTOR_NAME]
    @mentee_role = [RoleConstants::STUDENT_NAME]
    @mentor_mentee_roles = @mentor_role + @mentee_role
  end

  def test_registered_users_series
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    mentor_student = users(:f_mentor_student)

    program.update_attribute(:created_at, 1.week.since.beginning_of_week)

    health = HealthReport::ProgramHealthReport.new(program)

    student.update_attribute(:created_at, 2.weeks.since.beginning_of_week)
    mentor.update_attribute(:created_at, 3.weeks.since.beginning_of_week)
    mentor_student.update_attribute(:created_at, 4.weeks.since.beginning_of_week)

    # test single day report range
    health.compute(1.week.since.beginning_of_week, 1.week.since.beginning_of_week, @mentee_role)
    assert_equal 19, health.registered_users_summary_count
    assert_equal [19], health.registered_users_series

    # Current set of mentees
    health.compute(1.week.since.beginning_of_week, 1.week.since.end_of_week, @mentee_role)
    assert_equal 19, health.registered_users_summary_count
    assert_equal [19] * 7, health.registered_users_series

    # Current set of mentors
    health.compute(1.week.since.beginning_of_week, 1.week.since.end_of_week, @mentor_role)
    assert_equal 20, health.registered_users_summary_count
    assert_equal [20] * 7, health.registered_users_series

    # Current set of mentors and mentees
    health.compute(1.week.since.beginning_of_week, 1.week.since.end_of_week, @mentor_mentee_roles)
    assert_equal 39, health.registered_users_summary_count
    assert_equal [39] * 7, health.registered_users_series

    # test for mentee creation during report interval period
    health.compute(2.week.since.beginning_of_week, 2.week.since.end_of_week, @mentee_role)
    assert_equal 20, health.registered_users_summary_count
    assert_equal [20] * 7, health.registered_users_series

    health.compute(2.week.since.beginning_of_week, 2.week.since.end_of_week, @mentor_role)
    assert_equal 20, health.registered_users_summary_count
    assert_equal [20] * 7, health.registered_users_series

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentor_mentee_roles)
    assert_equal 40, health.registered_users_summary_count
    assert_equal [40] * 7, health.registered_users_series

    # test for mentor creation during report interval period
    health.compute(3.week.since.beginning_of_week, 3.week.since.end_of_week, @mentee_role)
    assert_equal 20, health.registered_users_summary_count
    assert_equal [20] * 7, health.registered_users_series

    health.compute(3.week.since.beginning_of_week, 3.week.since.end_of_week, @mentor_role)
    assert_equal 21, health.registered_users_summary_count
    assert_equal [21] * 7, health.registered_users_series

    health.compute(3.weeks.since.beginning_of_week, 3.weeks.since.end_of_week, @mentor_mentee_roles)
    assert_equal 41, health.registered_users_summary_count
    assert_equal [41] * 7, health.registered_users_series

    # test for user creation with mentor and mentee role during report interval period
    health.compute(4.week.since.beginning_of_week, 4.week.since.end_of_week, @mentee_role)
    assert_equal 21, health.registered_users_summary_count
    assert_equal [21] * 7, health.registered_users_series

    health.compute(4.week.since.beginning_of_week, 4.week.since.end_of_week, @mentor_role)
    assert_equal 22, health.registered_users_summary_count
    assert_equal [22] * 7, health.registered_users_series

    health.compute(4.weeks.since.beginning_of_week, 4.weeks.since.end_of_week, @mentor_mentee_roles)
    assert_equal 42, health.registered_users_summary_count
    assert_equal [42] * 7, health.registered_users_series

    suspend_user_at(student, 4.weeks.since.beginning_of_week + 2.days + 5.minutes)
    health.compute(4.weeks.since.beginning_of_week, 4.weeks.since.end_of_week, @mentor_mentee_roles)
    assert_equal 41, health.registered_users_summary_count
    assert_equal [41] * 7, health.registered_users_series

  end

  def test_registered_users_series_with_mentor_admin_role
    program = programs(:albers)
    mentor = users(:f_mentor)
    mentor_admin = users(:ram)
    program.update_attribute(:created_at, 1.week.since.beginning_of_week)
    health = HealthReport::ProgramHealthReport.new(program)
    mentor_admin.update_attribute(:created_at, 1.week.since.beginning_of_week)
    mentor.update_attribute(:created_at, 1.week.since.beginning_of_week)
    health.compute(1.week.since.beginning_of_week, 1.week.since.beginning_of_week, @mentee_role)
    assert_equal 21, health.registered_users_summary_count
  end

  def test_active_users_series
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    mentor_student = users(:f_mentor_student)
    clear_program_visit_activities

    health = HealthReport::ProgramHealthReport.new(program)
    health.active_user_interval_in_days = 7.days

    # visit outside report range
    log_program_visit_at(student, 3.weeks.ago.beginning_of_week)
    health.compute(1.week.ago.beginning_of_week, 1.week.ago.end_of_week, @mentor_mentee_roles)
    assert_equal 0, health.active_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.active_users_series

    # visit by mentee inside report range
    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,1,1,1,1,1,1], health.active_users_series
    assert_equal 1, health.active_users_summary_count

    health.compute(2.weeks.ago.beginning_of_week, 2.weeks.ago.end_of_week, @mentor_role)
    assert_equal 0, health.active_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.active_users_series

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [1,1,1,1,1,1,1], health.active_users_series
    assert_equal 1, health.active_users_summary_count

    # visit by mentee during interval period
    health.compute(3.weeks.ago.beginning_of_week + 3.days, 3.weeks.ago.end_of_week + 3.days, @mentee_role)
    assert_equal [1,1,1,1,1,0,0], health.active_users_series
    assert_equal 1, health.active_users_summary_count

    health.compute(2.weeks.ago.beginning_of_week + 3.days, 2.weeks.ago.end_of_week + 3.days, @mentor_role)
    assert_equal 0, health.active_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.active_users_series

    health.compute(3.weeks.ago.beginning_of_week + 3.days, 3.weeks.ago.end_of_week + 3.days, @mentor_mentee_roles)
    assert_equal [1,1,1,1,1,0,0], health.active_users_series
    assert_equal 1, health.active_users_summary_count

#    # visit by mentor (a diff user) on a diff day
    log_program_visit_at(mentor, 3.weeks.ago.beginning_of_week + 2.days + 5.minutes)

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,1,1,1,1,1,1], health.active_users_series
    assert_equal 1, health.active_users_summary_count

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentor_role)
    assert_equal [0,0,1,1,1,1,1], health.active_users_series
    assert_equal 1, health.active_users_summary_count

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [1,1,2,2,2,2,2], health.active_users_series
    assert_equal 2, health.active_users_summary_count

    # visit by the same mentee and mentee on a diff day within the report range

    log_program_visit_at(mentor, 3.weeks.ago.end_of_week - 5.minutes)
    log_program_visit_at(student, 3.weeks.ago.beginning_of_week + 1.day + 5.minutes)

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,1,1,1,1,1,1], health.active_users_series
    assert_equal 1, health.active_users_summary_count

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentor_role)
    assert_equal [0,0,1,1,1,1,1], health.active_users_series
    assert_equal 1, health.active_users_summary_count

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [1,1,2,2,2,2,2], health.active_users_series
    assert_equal 2, health.active_users_summary_count

    # visit by a user who is both mentor and mentee
    log_program_visit_at(mentor_student, 3.weeks.ago.beginning_of_week + 3.days + 5.minutes)

    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,1,1,2,2,2,2], health.active_users_series
    assert_equal 2, health.active_users_summary_count

    suspend_user_at(mentor_student, 3.weeks.since.end_of_week - 5.minutes)
    health.compute(3.weeks.ago.beginning_of_week, 3.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,1,1,1,1,1,1], health.active_users_series
    assert_equal 1, health.active_users_summary_count
  end

  def test_ongoing_mentoring_activity_users_series
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)

    program.update_attribute(:created_at, 1.year.ago)

    health = HealthReport::ProgramHealthReport.new(program)

    group_before_start_time = create_group_at(users(:f_mentor), users(:f_student), 8.weeks.ago.beginning_of_week)
    close_group_at(group_before_start_time, 8.weeks.ago.end_of_week - 5.minutes)

    group_after_start_time = create_group_at(users(:f_mentor), users(:f_student), 2.weeks.ago.beginning_of_week)
    close_group_at(group_after_start_time, 2.weeks.ago.end_of_week - 5.minutes)

    draft_group_after_start_time = create_group_at(users(:f_mentor), users(:f_student), 6.weeks.ago.beginning_of_week, Group::Status::DRAFTED)

    health.compute(7.weeks.ago.beginning_of_week, 7.weeks.ago.end_of_week, @mentee_role)
    assert_equal [0,0,0,0,0,0,0], health.ongoing_mentoring_activity_users_series
    assert_equal 0, health.ongoing_mentoring_activity_users_summary_count

    health.compute(7.weeks.ago.beginning_of_week, 7.weeks.ago.end_of_week, @mentor_role)
    assert_equal [0,0,0,0,0,0,0], health.ongoing_mentoring_activity_users_series
    assert_equal 0, health.ongoing_mentoring_activity_users_summary_count

    health.compute(7.weeks.ago.beginning_of_week, 7.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [0,0,0,0,0,0,0], health.ongoing_mentoring_activity_users_series
    assert_equal 0, health.ongoing_mentoring_activity_users_summary_count

    open_group_across_time_range = create_group_at(users(:mentor_2), users(:student_2), 6.weeks.ago.beginning_of_week)
    close_group_at(open_group_across_time_range, 2.weeks.ago.end_of_week - 5.minutes)

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,1,1,1,1,1,1], health.ongoing_mentoring_activity_users_series
    assert_equal 1, health.ongoing_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentor_role)
    assert_equal [1,1,1,1,1,1,1], health.ongoing_mentoring_activity_users_series
    assert_equal 1, health.ongoing_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [2,2,2,2,2,2,2], health.ongoing_mentoring_activity_users_series
    assert_equal 2, health.ongoing_mentoring_activity_users_summary_count

    group_within_time_range = create_group_at(users(:mentor_3), users(:student_3), 6.weeks.ago.beginning_of_week + 1.day )
    close_group_at(group_within_time_range, (6.weeks.ago.end_of_week - 1.day) - 5.minutes)

    health.compute(6.weeks.ago.beginning_of_week, 6.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,2,2,2,2,2,1], health.ongoing_mentoring_activity_users_series
    assert_equal 2, health.ongoing_mentoring_activity_users_summary_count

    health.compute(6.weeks.ago.beginning_of_week, 6.weeks.ago.end_of_week, @mentor_role)
    assert_equal [1,2,2,2,2,2,1], health.ongoing_mentoring_activity_users_series
    assert_equal 2, health.ongoing_mentoring_activity_users_summary_count

    health.compute(6.weeks.ago.beginning_of_week, 6.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [2,4,4,4,4,4,2], health.ongoing_mentoring_activity_users_series
    assert_equal 4, health.ongoing_mentoring_activity_users_summary_count

    group_across_start_time = create_group_at(users(:mentor_4), users(:student_4), 5.weeks.ago.beginning_of_week )
    close_group_at(group_across_start_time, 5.weeks.ago.end_of_week - 5.minutes)

    health.compute(5.weeks.ago.beginning_of_week + 2.days , 5.weeks.ago.end_of_week + 2.days, @mentee_role)
    assert_equal [2,2,2,2,2,1,1], health.ongoing_mentoring_activity_users_series
    assert_equal 2, health.ongoing_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week + 2.days , 5.weeks.ago.end_of_week + 2.days, @mentor_role)
    assert_equal [2,2,2,2,2,1,1], health.ongoing_mentoring_activity_users_series
    assert_equal 2, health.ongoing_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week + 2.days , 5.weeks.ago.end_of_week + 2.days, @mentor_mentee_roles)
    assert_equal [4,4,4,4,4,2,2], health.ongoing_mentoring_activity_users_series
    assert_equal 4, health.ongoing_mentoring_activity_users_summary_count

    group_across_end_time = create_group_at(users(:f_mentor_student), users(:student_0), 3.weeks.ago.beginning_of_week )
    close_group_at(group_across_end_time, 3.weeks.ago.end_of_week - 5.minutes)

    health.compute(3.weeks.ago.beginning_of_week - 2.days , 3.weeks.ago.end_of_week - 2.days, @mentee_role)
    assert_equal [1,1,2,2,2,2,2], health.ongoing_mentoring_activity_users_series
    assert_equal 2, health.ongoing_mentoring_activity_users_summary_count

    health.compute(3.weeks.ago.beginning_of_week - 2.days , 3.weeks.ago.end_of_week - 2.days, @mentor_role)
    assert_equal [1,1,2,2,2,2,2], health.ongoing_mentoring_activity_users_series
    assert_equal 2, health.ongoing_mentoring_activity_users_summary_count

    health.compute(3.weeks.ago.beginning_of_week - 2.days , 3.weeks.ago.end_of_week - 2.days, @mentor_mentee_roles)
    assert_equal [2,2,4,4,4,4,4], health.ongoing_mentoring_activity_users_series
    assert_equal 4, health.ongoing_mentoring_activity_users_summary_count
  end

  def test_active_mentoring_users_series
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)

    health = HealthReport::ProgramHealthReport.new(program)
    health.active_user_interval_in_days = 7.days

    group_before_start_time = create_group_at(users(:f_mentor), users(:f_student), 8.weeks.ago.beginning_of_week)
    mark_group_visit_at(group_before_start_time, users(:f_mentor), 8.weeks.ago.beginning_of_week + 1.day)
    close_group_at(group_before_start_time, 8.weeks.ago.end_of_week - 5.minutes)

    group_after_start_time = create_group_at(users(:f_mentor), users(:f_student), 2.weeks.ago.beginning_of_week)
    mark_group_visit_at(group_after_start_time, users(:f_mentor), 2.weeks.ago.beginning_of_week + 1.day)
    close_group_at(group_after_start_time, 2.weeks.ago.end_of_week - 5.minutes)

    # visit outside report range
    health.compute(6.weeks.ago.beginning_of_week, 6.weeks.ago.end_of_week, @mentee_role)
    assert_equal [0,0,0,0,0,0,0], health.active_mentoring_activity_users_series
    assert_equal 0, health.active_mentoring_activity_users_summary_count

    health.compute(6.weeks.ago.beginning_of_week, 6.weeks.ago.end_of_week, @mentor_role)
    assert_equal [0,0,0,0,0,0,0], health.active_mentoring_activity_users_series
    assert_equal 0, health.active_mentoring_activity_users_summary_count

    health.compute(6.weeks.ago.beginning_of_week, 6.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [0,0,0,0,0,0,0], health.active_mentoring_activity_users_series
    assert_equal 0, health.active_mentoring_activity_users_summary_count

    # visit inside report range
    health.compute(8.weeks.ago.beginning_of_week, 8.weeks.ago.end_of_week, @mentor_role)
    assert_equal [0,1,1,1,1,1,1], health.active_mentoring_activity_users_series
    assert_equal 1, health.active_mentoring_activity_users_summary_count

    health.compute(8.weeks.ago.beginning_of_week, 8.weeks.ago.end_of_week, @mentee_role)
    assert_equal [0,0,0,0,0,0,0], health.active_mentoring_activity_users_series
    assert_equal 0, health.active_mentoring_activity_users_summary_count

    health.compute(8.weeks.ago.beginning_of_week, 8.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [0,1,1,1,1,1,1], health.active_mentoring_activity_users_series
    assert_equal 1, health.active_mentoring_activity_users_summary_count

    open_group_across_time_range = create_group_at(users(:mentor_2), users(:student_2), 6.weeks.ago.beginning_of_week)

    mark_group_visit_at(open_group_across_time_range, users(:mentor_2), 5.weeks.ago.beginning_of_week + 5.minutes)

    # Visit by same user on same day (1st)
    mark_group_visit_at(open_group_across_time_range, users(:mentor_2), 5.weeks.ago.beginning_of_week + 12.hours)
    # Visit by same user on different day (6th)
    mark_group_visit_at(open_group_across_time_range, users(:mentor_2), 5.weeks.ago.beginning_of_week + 5.days + 10.minutes)
    # Visit by a different user on different day (2nd)
    mark_group_visit_at(open_group_across_time_range, users(:student_2), 5.weeks.ago.beginning_of_week + 1.day + 5.minutes)
    # Visit by a different user on same day (6th)
    mark_group_visit_at(open_group_across_time_range, users(:student_2), 5.weeks.ago.beginning_of_week + 5.days + 5.minutes)

    create_scrap_at(open_group_across_time_range, users(:student_2), 5.weeks.ago.end_of_week - 5.minutes)

    close_group_at(open_group_across_time_range, 2.weeks.ago.end_of_week - 5.minutes)

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentor_role)
    assert_equal [1,1,1,1,1,1,1], health.active_mentoring_activity_users_series
    assert_equal 1, health.active_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentee_role)
    assert_equal [0,1,1,1,1,1,1], health.active_mentoring_activity_users_series
    assert_equal 1, health.active_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [1,2,2,2,2,2,2], health.active_mentoring_activity_users_series
    assert_equal 2, health.active_mentoring_activity_users_summary_count

    group_within_time_range = create_group_at(users(:mentor_2), users(:student_3), 5.weeks.ago.beginning_of_week)

    # Diff conn: same user on same day (1st)
    mark_group_visit_at(group_within_time_range, users(:mentor_2), 5.weeks.ago.beginning_of_week + 1.hour )
    # Diff conn: same user on diff day (3rd)
    mark_group_visit_at(group_within_time_range, users(:mentor_2), 5.weeks.ago.beginning_of_week + 2.days )
    # Diff conn: diff user on same day (1st)
    mark_group_visit_at(group_within_time_range, users(:student_3), 5.weeks.ago.beginning_of_week + 3.hours )
    # Diff conn: diff user on diff day (4th)
    mark_group_visit_at(group_within_time_range, users(:student_3), 5.weeks.ago.beginning_of_week + 3.days )

    create_scrap_at(group_within_time_range, users(:mentor_2), 5.weeks.ago.beginning_of_week + 4.days + 15.minutes )
    create_scrap_at(group_within_time_range, users(:student_3), 5.weeks.ago.end_of_week - 15.minutes )

    close_group_at(group_within_time_range, 5.weeks.ago.end_of_week - 5.minutes)

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentor_role)
    assert_equal [1,1,1,1,1,1,1], health.active_mentoring_activity_users_series
    assert_equal 1, health.active_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentee_role)
    assert_equal [1,2,2,2,2,2,2], health.active_mentoring_activity_users_series
    assert_equal 2, health.active_mentoring_activity_users_summary_count

    health.compute(5.weeks.ago.beginning_of_week, 5.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [2,3,3,3,3,3,3], health.active_mentoring_activity_users_series
    assert_equal 3, health.active_mentoring_activity_users_summary_count
  end

  def test_active_mentoring_users_series_for_mentoring_interval
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)

    health = HealthReport::ProgramHealthReport.new(program)
    health.active_user_interval_in_days = 5.days

    group_before_start_time = create_group_at(users(:f_mentor), users(:f_student), 8.weeks.ago.beginning_of_week)
    mark_group_visit_at(group_before_start_time, users(:f_mentor), 8.weeks.ago.beginning_of_week + 1.day)
    close_group_at(group_before_start_time, 8.weeks.ago.end_of_week - 5.minutes)

    # visit during active mentoring interval period but outside report range
    health.compute(8.weeks.ago.beginning_of_week + 2.days, 8.weeks.ago.end_of_week + 2.days, @mentor_role)
    assert_equal [1,1,1,1,1,0,0], health.active_mentoring_activity_users_series
    assert_equal 1, health.active_mentoring_activity_users_summary_count

    health.compute(8.weeks.ago.beginning_of_week + 2.days, 8.weeks.ago.end_of_week + 2.days, @mentee_role)
    assert_equal [0,0,0,0,0,0,0], health.active_mentoring_activity_users_series
    assert_equal 0, health.active_mentoring_activity_users_summary_count

    health.compute(8.weeks.ago.beginning_of_week + 2.days, 8.weeks.ago.end_of_week + 2.days, @mentor_mentee_roles)
    assert_equal [1,1,1,1,1,0,0], health.active_mentoring_activity_users_series
    assert_equal 1, health.active_mentoring_activity_users_summary_count
  end

  def test_active_mentoring_users_series_with_group_member_removal
    program = programs(:psg)
    student_1 = users(:psg_student1)
    student_2 = users(:psg_student2)
    mentor = users(:psg_mentor3)
    admin = users(:psg_admin)

    health = HealthReport::ProgramHealthReport.new(program)
    health.active_user_interval_in_days = 7.days

    groups(:multi_group).terminate!(admin, "Closed by test in program health report", groups(:multi_group).program.permitted_closure_reasons.first.id)

    group = create_group_with_multiple_mentees_at(mentor, [student_1, student_2], 8.weeks.ago.beginning_of_week)
    mark_group_visit_at(group, mentor, 8.weeks.ago.beginning_of_week + 1.day)
    mark_group_visit_at(group, student_1, 8.weeks.ago.beginning_of_week + 1.day)
    mark_group_visit_at(group, student_2, 8.weeks.ago.beginning_of_week + 1.day)
    update_group_mentees_at(group, [student_1], 8.weeks.ago.beginning_of_week + 4.days, admin)
    close_group_at(group, 8.weeks.ago.end_of_week - 5.minutes, admin)

    health.compute(8.weeks.ago.beginning_of_week, 8.weeks.ago.end_of_week, @mentor_mentee_roles)
    assert_equal [0,2,2,2,2,2,2], health.active_mentoring_activity_users_series
    assert_equal 2, health.active_mentoring_activity_users_summary_count
  end

  def test_community_users_series
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    mentor_student = users(:f_mentor_student)

    health = HealthReport::ProgramHealthReport.new(program)

    # visit outside report range
    log_resource_visit_at(student, 2.weeks.since.beginning_of_week)
    log_article_visit_at(student, 2.weeks.since.beginning_of_week)
    log_forum_visit_at(student, 2.weeks.since.beginning_of_week + 1.day + 5.minutes)
    log_qa_visit_at(student, 2.weeks.since.beginning_of_week + 2.days + 5.minutes)

    health.compute(1.week.since.beginning_of_week, 1.week.since.end_of_week, @mentee_role)
    assert_equal 0, health.article_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.article_activity_users_series
    assert_equal 0, health.resource_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal 0, health.forum_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.forum_activity_users_series
    assert_equal 0, health.qa_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.qa_activity_users_series
    assert_equal [0,0,0,0,0,0,0], health.community_activity_users_series
    assert_equal 0, health.community_activity_users_summary_count

    health.compute(1.week.since.beginning_of_week, 1.week.since.end_of_week, @mentor_role)
    assert_equal 0, health.article_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.article_activity_users_series
    assert_equal 0, health.resource_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal 0, health.forum_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.forum_activity_users_series
    assert_equal 0, health.qa_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.qa_activity_users_series
    assert_equal [0,0,0,0,0,0,0], health.community_activity_users_series
    assert_equal 0, health.community_activity_users_summary_count

    health.compute(1.week.since.beginning_of_week, 1.week.since.end_of_week, @mentor_mentee_roles)
    assert_equal 0, health.article_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.article_activity_users_series
    assert_equal 0, health.resource_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal 0, health.forum_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.forum_activity_users_series
    assert_equal 0, health.qa_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.qa_activity_users_series
    assert_equal [0,0,0,0,0,0,0], health.community_activity_users_series
    assert_equal 0, health.community_activity_users_summary_count

    # visit inside report range
    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentee_role)
    assert_equal [1,0,0,0,0,0,0], health.article_activity_users_series
    assert_equal 1, health.article_activity_users_summary_count
    assert_equal [1,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal 1, health.resource_activity_users_summary_count
    assert_equal [0,1,0,0,0,0,0], health.forum_activity_users_series
    assert_equal 1, health.forum_activity_users_summary_count
    assert_equal [0,0,1,0,0,0,0], health.qa_activity_users_series
    assert_equal 1, health.qa_activity_users_summary_count
    assert_equal [1,1,1,0,0,0,0], health.community_activity_users_series
    assert_equal 1, health.community_activity_users_summary_count

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentor_role)
    assert_equal [0,0,0,0,0,0,0], health.article_activity_users_series
    assert_equal 0, health.article_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal 0, health.resource_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.forum_activity_users_series
    assert_equal 0, health.forum_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.qa_activity_users_series
    assert_equal 0, health.qa_activity_users_summary_count
    assert_equal [0,0,0,0,0,0,0], health.community_activity_users_series
    assert_equal 0, health.community_activity_users_summary_count

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentor_mentee_roles)
    assert_equal [1,0,0,0,0,0,0], health.article_activity_users_series
    assert_equal 1, health.article_activity_users_summary_count
    assert_equal [1,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal 1, health.resource_activity_users_summary_count
    assert_equal [0,1,0,0,0,0,0], health.forum_activity_users_series
    assert_equal 1, health.forum_activity_users_summary_count
    assert_equal [0,0,1,0,0,0,0], health.qa_activity_users_series
    assert_equal 1, health.qa_activity_users_summary_count
    assert_equal [1,1,1,0,0,0,0], health.community_activity_users_series
    assert_equal 1, health.community_activity_users_summary_count

    # visit by a diff user on a diff day
    log_resource_visit_at(mentor, 2.weeks.since.beginning_of_week + 3.days + 5.minutes)
    log_article_visit_at(mentor, 2.weeks.since.beginning_of_week + 3.days + 5.minutes)
    log_forum_visit_at(mentor, 2.weeks.since.beginning_of_week + 4.day + 5.minutes)
    log_qa_visit_at(mentor, 2.weeks.since.beginning_of_week + 5.days + 5.minutes)

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentee_role)
    assert_equal [1,0,0,0,0,0,0], health.article_activity_users_series
    assert_equal 1, health.article_activity_users_summary_count
    assert_equal [1,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal 1, health.resource_activity_users_summary_count
    assert_equal [1,0,0,0,0,0,0], health.resource_activity_users_series
    assert_equal [0,1,0,0,0,0,0], health.forum_activity_users_series
    assert_equal 1, health.forum_activity_users_summary_count
    assert_equal [0,0,1,0,0,0,0], health.qa_activity_users_series
    assert_equal 1, health.qa_activity_users_summary_count
    assert_equal [1,1,1,0,0,0,0], health.community_activity_users_series
    assert_equal 1, health.community_activity_users_summary_count

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentor_role)
    assert_equal [0,0,0,1,0,0,0], health.article_activity_users_series
    assert_equal 1, health.article_activity_users_summary_count
    assert_equal [0,0,0,1,0,0,0], health.resource_activity_users_series
    assert_equal 1, health.resource_activity_users_summary_count
    assert_equal [0,0,0,0,1,0,0], health.forum_activity_users_series
    assert_equal 1, health.forum_activity_users_summary_count
    assert_equal [0,0,0,0,0,1,0], health.qa_activity_users_series
    assert_equal 1, health.qa_activity_users_summary_count
    assert_equal [0,0,0,1,1,1,0], health.community_activity_users_series
    assert_equal 1, health.community_activity_users_summary_count

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentor_mentee_roles)
    assert_equal [1,0,0,1,0,0,0], health.article_activity_users_series
    assert_equal 2, health.article_activity_users_summary_count
    assert_equal [1,0,0,1,0,0,0], health.resource_activity_users_series
    assert_equal 2, health.resource_activity_users_summary_count
    assert_equal [0,1,0,0,1,0,0], health.forum_activity_users_series
    assert_equal 2, health.forum_activity_users_summary_count
    assert_equal [0,0,1,0,0,1,0], health.qa_activity_users_series
    assert_equal 2, health.qa_activity_users_summary_count
    assert_equal [1,1,1,1,1,1,0], health.community_activity_users_series
    assert_equal 2, health.community_activity_users_summary_count

    # visit by the user with diff role on a diff day

    log_article_visit_at(mentor_student, 2.weeks.since.end_of_week - 5.minutes)

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentee_role)
    assert_equal [1,0,0,0,0,0,1], health.article_activity_users_series
    assert_equal 2, health.article_activity_users_summary_count
    assert_equal [1,1,1,0,0,0,1], health.community_activity_users_series
    assert_equal 2, health.community_activity_users_summary_count

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentor_role)
    assert_equal [0,0,0,1,0,0,1], health.article_activity_users_series
    assert_equal 2, health.article_activity_users_summary_count
    assert_equal [0,0,0,1,1,1,1], health.community_activity_users_series
    assert_equal 2, health.community_activity_users_summary_count

    health.compute(2.weeks.since.beginning_of_week, 2.weeks.since.end_of_week, @mentor_mentee_roles)
    assert_equal [1,0,0,1,0,0,1], health.article_activity_users_series
    assert_equal 3, health.article_activity_users_summary_count
    assert_equal [1,1,1,1,1,1,1], health.community_activity_users_series
    assert_equal 3, health.community_activity_users_summary_count

  end

  def test_active_user_interval_in_days_with_inactivity_tracking_period
    program = programs(:albers)
    program.inactivity_tracking_period_in_days = 15
    program.save!

    health = HealthReport::ProgramHealthReport.new(program)
    assert_equal 15, health.active_user_interval_in_days
  end

  def test_active_user_interval_in_days_with_no_inactivity_tracking_period
    program = programs(:albers)
    program.inactivity_tracking_period = nil
    program.save!

    health = HealthReport::ProgramHealthReport.new(program)
    assert_equal HealthReport::ProgramHealthReport::DEFAULT_ACTIVE_USER_INTERVAL, health.active_user_interval_in_days
  end

  def test_generate_daterange_map
    program = programs(:albers)
    program.inactivity_tracking_period = nil
    program.save!
    health = HealthReport::ProgramHealthReport.new(program)
    start_time = Date.strptime("5/7/1993", "%m/%d/%Y").to_datetime.change(offset: "JST")
    end_time = Date.strptime("5/8/1993", "%m/%d/%Y").to_datetime.change(offset: "JST")
    health.instance_variable_set(:@start_time, start_time)
    health.instance_variable_set(:@end_time, end_time)
    health.instance_eval{ generate_daterange_map! }
    assert health.instance_eval { @daterange_map }.include?(start_time.beginning_of_day.utc.to_date - HealthReport::ProgramHealthReport::DEFAULT_ACTIVE_USER_INTERVAL)
    assert health.instance_eval { @daterange_map }.include?(end_time.end_of_day.utc.to_date)
    assert_nil program.reload.inactivity_tracking_period
  end

  private

  def log_activity_at(user, activity_type, visit_time)
    Timecop.travel(visit_time)
    begin
      ActivityLog.log_activity(user, activity_type)
    ensure
      Timecop.return
    end
  end

  def log_program_visit_at(user, visit_time)
    log_activity_at(user, ActivityLog::Activity::PROGRAM_VISIT, visit_time)
  end

  def log_resource_visit_at(user, visit_time)
    log_activity_at(user, ActivityLog::Activity::RESOURCE_VISIT, visit_time)
  end

  def log_article_visit_at(user, visit_time)
    log_activity_at(user, ActivityLog::Activity::ARTICLE_VISIT, visit_time)
  end

  def log_forum_visit_at(user, visit_time)
    log_activity_at(user, ActivityLog::Activity::FORUM_VISIT, visit_time)
  end

  def log_qa_visit_at(user, visit_time)
    log_activity_at(user, ActivityLog::Activity::QA_VISIT, visit_time)
  end

  def create_group_at(mentor, mentee, time, status = nil)
    Timecop.travel(time)
    begin
      g = create_group(:mentor => mentor, :students => [mentee], :status => status, :creator_id => users(:f_admin).id)
    ensure
      Timecop.return
    end
    return g
  end

  def create_group_with_multiple_mentees_at(mentor, mentees, time)
    Timecop.travel(time)
    begin
      g = create_group(:mentor => mentor, :students => mentees)
    ensure
      Timecop.return
    end
    return g
  end

  def update_group_mentees_at(group, new_mentees, time, admin = users(:f_admin))
    Timecop.travel(time)
    begin
      status = group.update_members(group.mentors, new_mentees, admin)
    ensure
      Timecop.return
    end
    return status
  end

  def close_group_at(group, time, admin = users(:f_admin))
    Timecop.travel(time)
    begin
      group.terminate!(admin, "Program health report test reason", group.program.permitted_closure_reasons.first.id)
    ensure
      Timecop.return
    end
  end

  def mark_group_visit_at(group, user, time)
    Timecop.travel(time)
    begin
      group.mark_visit(user)
    ensure
      Timecop.return
    end
  end

  def create_scrap_at(group, user, time)
    Timecop.travel(time)
    begin
      create_scrap(:group => group, :sender => user.member)
    ensure
      Timecop.return
    end
  end

  def suspend_user_at(user, time)
    Timecop.travel(time)
    begin
      user.suspend_from_program!(users(:f_admin), "Program health report test reason")
    ensure
      Timecop.return
    end
  end

  def clear_program_visit_activities
    ActivityLog.where(activity: ActivityLog::Activity::PROGRAM_VISIT).delete_all
  end
end