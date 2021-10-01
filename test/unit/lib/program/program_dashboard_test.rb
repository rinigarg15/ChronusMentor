require_relative './../../../test_helper'

class ProgramDashboardTest < ActiveSupport::TestCase
  # Testing methods on program class directly

  def test_current_status
    program = programs(:albers)
    program.stubs(:user_status).returns("users")
    program.stubs(:connections_status).returns("connections")
    program.stubs(:connected_users_status).returns("connected_users")
    assert_equal_hash({users: "users", connections: "connections", connected_users: "connected_users"}, program.current_status)
  end

  def test_get_metrics
    program = programs(:albers)
    view = program.abstract_views.first
    section = program.report_sections.find_by(default_section: Report::Section::DefaultSections::RECRUITMENT)
    metric = section.metrics.create(title: "pending users", description: "see pending users counts", abstract_view_id: view.id)

    assert program.get_metrics(Report::Section::DefaultSections::RECRUITMENT).pluck(:id).include?(metric.id)
    assert_false program.get_metrics(Report::Section::DefaultSections::CONNECTION).pluck(:id).include?(metric.id)
  end

  def test_get_data_for
    program = programs(:albers)
    program.stubs(:get_invitation_acceptance_rate_data).returns('inv')
    assert_equal 'inv', program.get_data_for(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)

    program.stubs(:get_applications_status_data).returns('app')
    assert_equal 'app', program.get_data_for(DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS)

    program.stubs(:get_published_profiles_data).returns('pub')
    assert_equal 'pub', program.get_data_for(DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES)

    program.stubs(:get_announcements_and_events_data).returns('ann')
    assert_equal 'ann', program.get_data_for(DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS)

    program.stubs(:get_resources_data).returns('res')
    assert_equal 'res', program.get_data_for(DashboardReportSubSection::Type::CommunityResources::RESOURCES)
  end

  def test_get_data_in_date_range_for
    program = programs(:albers)
    start_date = Time.now-2.day
    end_date = Time.now-1.day
    date_range = start_date..end_date
    program.stubs(:get_forums_and_articles).with(date_range).returns('for')
    assert_equal 'for', program.get_data_in_date_range_for(DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES, date_range)
  end

  def test_get_percentage_and_object_counts
    program = programs(:albers)

    Timecop.freeze do
      Article.update_all(created_at: Time.now)
      objects = Article.all
      start_date = Time.now - 2.days
      end_date = Time.now - 1.day
      date_range = start_date..end_date
      assert_equal [0, 0, 0], program.get_percentage_and_object_counts(date_range, objects)

      start_date = Time.now - 1.day
      end_date = Time.now + 1.day
      date_range = start_date..end_date
      program.update_attributes!(created_at: Time.now - 10.days)
      assert_equal [100, 0, 9], program.get_percentage_and_object_counts(date_range, objects)

      start_date = Time.now + 1.day
      end_date = Time.now + 2.days
      date_range = start_date..end_date
      assert_equal [-100, 9, 0], program.get_percentage_and_object_counts(date_range, objects)
    end
  end

  def test_user_status
    program = programs(:albers)
    assert_equal_hash({total: 42, "mentor" => 22, "student" => 21}, program.send(:user_status))

    program = programs(:albers)
    assert_equal_hash({total: 44, "mentor" => 22, "student" => 21}, program.send(:user_status, false))
  end

  def test_connections_status
    program = programs(:albers)
    assert_false program.only_one_time_mentoring_enabled?
    assert_false program.project_based?
    assert_equal_hash({total: program.groups.active.count+program.groups.closed.count, ongoing: program.groups.active.count, closed: program.groups.closed.count}, program.send(:connections_status))

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    program.stubs(:get_attended_meeting_ids).returns(program.meetings.non_group_meetings.pluck(:id))
    program.stubs(:created_at).returns(2.months.ago)
    assert_equal_hash({total: 4, upcoming: 1, past: 3, completed: 1}, program.send(:connections_status))

    program = programs(:pbe)
    assert_equal_hash({total: program.groups.active.count+program.groups.closed.count+program.groups.pending.count, ongoing: program.groups.active.count, closed: program.groups.closed.count, available: program.groups.pending.count}, program.send(:connections_status))
  end

  def test_get_meeting_status
    program = programs(:albers)
    program.stubs(:get_attended_meeting_ids).returns(program.meetings.non_group_meetings.pluck(:id))
    program.stubs(:created_at).returns(2.months.ago)
    assert_equal_hash({total: 4, upcoming: 1, past: 3, completed: 1}, program.send(:get_meeting_status))    
  end

  def test_connected_users_status
    program = programs(:albers)
    groups = program.groups.active
    total = groups.collect(&:members).flatten.collect(&:id).uniq.size
    mentors = (groups.collect(&:members).flatten.collect(&:id) & program.mentor_users.active.pluck(:id)).size
    students = (groups.collect(&:members).flatten.collect(&:id) & program.student_users.active.pluck(:id)).size
    assert_equal_hash({total: total, "mentor" => mentors, "student" => students}, program.send(:connected_users_status))

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    meetings = [meetings(:upcoming_calendar_meeting), meetings(:past_calendar_meeting)]
    program.stubs(:get_attended_meeting_ids).returns(meetings.collect(&:id))
    total = meetings.collect(&:member_meetings).flatten.collect(&:member_id).uniq.size
    mentors = meetings.collect{|m| m.get_member_for_role(RoleConstants::MENTOR_NAME)}.flatten.collect(&:id).uniq.size
    students = meetings.collect{|m| m.get_member_for_role(RoleConstants::STUDENT_NAME)}.flatten.collect(&:id).uniq.size
    assert_equal_hash({total: total, "mentor" => mentors, "student" => students}, program.send(:connected_users_status))
  end

  def test_get_users_connected_via_meeting_status
    program = programs(:albers)
    meetings = [meetings(:upcoming_calendar_meeting), meetings(:past_calendar_meeting)]
    program.stubs(:get_attended_meeting_ids).returns(meetings.collect(&:id))
    total = meetings.collect(&:member_meetings).flatten.collect(&:member_id).uniq.size
    mentors = meetings.collect{|m| m.get_member_for_role(RoleConstants::MENTOR_NAME)}.flatten.collect(&:id).uniq.size
    students = meetings.collect{|m| m.get_member_for_role(RoleConstants::STUDENT_NAME)}.flatten.collect(&:id).uniq.size
    assert_equal_hash({total: total, "mentor" => mentors, "student" => students}, program.send(:get_users_connected_via_meeting_status))
  end

  def test_get_users_connected_via_groups_status
    program = programs(:albers)
    groups = program.groups.active
    total = groups.collect(&:members).flatten.collect(&:id).uniq.size
    mentors = groups.collect(&:mentors).flatten.collect(&:id).uniq.size
    students = groups.collect(&:students).flatten.collect(&:id).uniq.size
    assert_equal_hash({total: total, "mentor" => mentors, "student" => students}, program.send(:get_users_connected_via_groups_status))

    groups = program.groups.active_or_closed
    total = groups.collect(&:members).flatten.collect(&:id).uniq.size
    mentors = groups.collect(&:mentors).flatten.collect(&:id).uniq.size
    students = groups.collect(&:students).flatten.collect(&:id).uniq.size
    assert_equal_hash({total: total, "mentor" => mentors, "student" => students}, program.send(:get_users_connected_via_groups_status, :active_or_closed))
  end

  def test_get_attended_meeting_ids
    program = programs(:albers)
    assert_equal_unordered [meetings(:upcoming_calendar_meeting), meetings(:past_calendar_meeting), meetings(:completed_calendar_meeting), meetings(:cancelled_calendar_meeting)].collect(&:id), program.send(:get_attended_meeting_ids)
  end

  def test_rounded_percentage
    program = programs(:albers)
    assert_equal 100.0, program.send(:rounded_percentage, 1, 1, 2)
    assert_equal 33, program.send(:rounded_percentage, 1, 3)
    assert_equal 33.33333, program.send(:rounded_percentage, 1, 3, 5)
    assert_equal 100, program.send(:rounded_percentage, 1, 0)
    assert_equal 0, program.send(:rounded_percentage, 0, 0)
    assert_equal 0, program.send(:rounded_percentage, 0, 1)
  end
end