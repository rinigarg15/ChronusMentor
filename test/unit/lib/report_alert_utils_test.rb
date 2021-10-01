require_relative './../../test_helper.rb'

class ReportAlertUtilsTest < ActiveSupport::TestCase
  def test_affiliation_map
    program = programs(:albers)
    alert_scope = ReportAlertUtils::DefaultAlerts
    metric_scope = Report::Metric::DefaultMetrics
    map = ReportAlertUtils::DefaultAlerts.affiliation_map
    assert_equal_unordered [
      alert_scope::APPLICATION_AWAITING_ACCEPTANCE,
      alert_scope::INVITATIONS_AWAITING_ACCEPTANCE,
      alert_scope::MENTORING_REQUEST_RECEIVED_BUT_NOT_ANSWERED,
      alert_scope::MEETING_REQUEST_RECEIVED_BUT_NOT_ANSWERED,
      alert_scope::MENTEES_JOINED_BUT_NEVER_CONNECTED,
      alert_scope::MENTORS_JOINED_BUT_NEVER_CONNECTED
    ], map.keys
    new_map = {}
    map.each { |k, v| new_map[k] = v.call(program) }

    expected_filter_hash = {cjs_alert_filter_params_0: {name: FilterUtils::MembershipRequestViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 15}}
    assert_equal metric_scope::PENDING_REQUESTS, new_map[alert_scope::APPLICATION_AWAITING_ACCEPTANCE][:metric].call
    assert_equal expected_filter_hash, new_map[alert_scope::APPLICATION_AWAITING_ACCEPTANCE][:filter_params].call

    expected_filter_hash = {cjs_alert_filter_params_0: {name: FilterUtils::ProgramInvitationViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 15}}
    assert_equal metric_scope::PENDING_INVITES, new_map[alert_scope::INVITATIONS_AWAITING_ACCEPTANCE][:metric].call
    assert_equal expected_filter_hash, new_map[alert_scope::INVITATIONS_AWAITING_ACCEPTANCE][:filter_params].call

    expected_filter_hash = {cjs_alert_filter_params_0: {name: FilterUtils::MentorRequestViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 15}}
    assert_equal metric_scope::PENDING_CONNECTION_REQUESTS, new_map[alert_scope::MENTORING_REQUEST_RECEIVED_BUT_NOT_ANSWERED][:metric].call
    assert_equal expected_filter_hash, new_map[alert_scope::MENTORING_REQUEST_RECEIVED_BUT_NOT_ANSWERED][:filter_params].call

    expected_filter_hash = {cjs_alert_filter_params_0: {name: FilterUtils::MeetingRequestViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 7}}
    assert_equal metric_scope::PENDING_MEETING_REQUESTS, new_map[alert_scope::MEETING_REQUEST_RECEIVED_BUT_NOT_ANSWERED][:metric].call
    assert_equal expected_filter_hash, new_map[alert_scope::MEETING_REQUEST_RECEIVED_BUT_NOT_ANSWERED][:filter_params].call

    expected_filter_hash = {cjs_alert_filter_params_0: {name: FilterUtils::AdminViewFilters::SIGNED_UP_ON, operator: FilterUtils::DateRange::BEFORE_LAST, value: 30}, cjs_alert_filter_params_1: {name: FilterUtils::AdminViewFilters::CONNECTION_STATUS, operator: FilterUtils::Equals::EQUALS, value: UsersIndexFilters::Values::NEVERCONNECTED}}
    assert_equal metric_scope::NEVER_CONNECTED_MENTEES, new_map[alert_scope::MENTEES_JOINED_BUT_NEVER_CONNECTED][:metric].call
    assert_equal expected_filter_hash, new_map[alert_scope::MENTEES_JOINED_BUT_NEVER_CONNECTED][:filter_params].call
  end
end
