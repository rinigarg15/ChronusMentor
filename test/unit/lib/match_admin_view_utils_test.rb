require_relative './../../test_helper.rb'

class MatchAdminViewUtilsTest < ActiveSupport::TestCase
  include MatchAdminViewUtils

  def setup
    super
    @current_program = programs(:albers)
  end

  def test_fetch_admin_views_for_matching
    program = programs(:albers)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])
    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])
    fetch_admin_views_for_matching
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], @admin_view_role_hash.keys
    assert_equal mentor_views, @admin_view_role_hash[RoleConstants::MENTOR_NAME]
    assert_equal student_views, @admin_view_role_hash[RoleConstants::STUDENT_NAME]
  end

  def test_fetch_mentee_and_mentor_views
    self.instance_variable_set(:@bulk_match, bulk_matches(:bulk_match_1))
    AdminView.any_instance.expects(:generate_view).with("", "", false).twice.returns([])
    fetch_mentee_and_mentor_views(bulk_matches(:bulk_match_1).mentee_view, bulk_matches(:bulk_match_1).mentor_view, nil)
    mentor_view_filters = {"Roles"=>"Mentor"}
    mentee_view_filters = {"Roles"=>"Student"}
    assert_equal mentor_view_filters, @mentor_view_filters
    assert_equal mentee_view_filters, @mentee_view_filters
    assert_equal @bulk_match.mentor_view, @mentor_view
    assert_equal @bulk_match.mentee_view, @mentee_view
    assert_equal [], @mentor_view_users
    assert_equal [], @mentee_view_users

    admin_view = @current_program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES)
    self.instance_variable_set(:@mentor_view, nil)
    self.instance_variable_set(:@mentee_view, nil)
    AdminView.any_instance.expects(:generate_view).with("", "", false).twice.returns([])
    fetch_mentee_and_mentor_views(bulk_matches(:bulk_match_1).mentee_view, bulk_matches(:bulk_match_1).mentor_view, admin_view.id)
    assert_equal admin_view, @mentor_view
    assert_equal @bulk_match.mentee_view, @mentee_view

    admin_view = @current_program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES)
    self.instance_variable_set(:@mentor_view, nil)
    self.instance_variable_set(:@mentee_view, nil)
    AdminView.any_instance.expects(:generate_view).with("", "", false).twice.returns([])
    fetch_mentee_and_mentor_views(bulk_matches(:bulk_match_1).mentee_view, bulk_matches(:bulk_match_1).mentor_view, admin_view.id)
    assert_equal @bulk_match.mentor_view, @mentor_view
    assert_equal admin_view, @mentee_view
  end

  def test_fetch_mentee_and_mentor_views_match_report
    self.instance_variable_set(:@bulk_match, bulk_matches(:bulk_match_1))
    @bulk_match.mentor_view.expects(:get_user_ids_for_match_report).once
    @bulk_match.mentee_view.expects(:get_user_ids_for_match_report).once
    fetch_mentee_and_mentor_views(bulk_matches(:bulk_match_1).mentee_view, bulk_matches(:bulk_match_1).mentor_view, nil, {src: MatchReport::SettingsSrc::MATCH_REPORT})
    mentor_view_filters = {"Roles"=>"Mentor"}
    mentee_view_filters = {"Roles"=>"Student"}
    assert_equal mentor_view_filters, @mentor_view_filters
    assert_equal mentee_view_filters, @mentee_view_filters
    assert_equal @bulk_match.mentor_view, @mentor_view
    assert_equal @bulk_match.mentee_view, @mentee_view
    assert_equal programs(:albers).mentor_users.pluck(:id), @mentor_view_users
    assert_equal programs(:albers).student_users.pluck(:id), @mentee_view_users
  end
end