require_relative './../../../test_helper'

class OutcomesReportUtilsTest < ActiveSupport::TestCase
  include OutcomesReportUtils

  def test_remove_invalid_meetings
    assert_equal [], remove_invalid_meetings([])

    meetings = [{"meeting_id"=>1, "meeting_start_time"=>DateTime.parse("2014-09-30 02:13:40 UTC"), "member_meeting_id"=>1, "member_id"=>3, "meeting_owner_id"=>3}, {"meeting_id"=>1, "meeting_start_time"=>DateTime.parse("2014-09-30 02:13:40 UTC"), "member_meeting_id"=>1, "member_id"=>3, "meeting_owner_id"=>3}, {"meeting_id"=>1, "meeting_start_time"=>DateTime.parse("2014-09-30 02:13:40 UTC"), "member_meeting_id"=>2, "member_id"=>9, "meeting_owner_id"=>3}, {"meeting_id"=>2, "meeting_start_time"=>DateTime.parse("2014-09-30 01:53:40 UTC"), "member_meeting_id"=>3, "member_id"=>12, "meeting_owner_id"=>12}, {"meeting_id"=>2, "meeting_start_time"=>DateTime.parse("2014-09-30 01:53:40 UTC"), "member_meeting_id"=>4, "member_id"=>42, "meeting_owner_id"=>12}]
    assert_equal_unordered meetings, remove_invalid_meetings(meetings)

    meetings = [{"meeting_id"=>1, "meeting_start_time"=>DateTime.parse("2014-09-30 02:13:40 UTC"), "member_meeting_id"=>2, "member_id"=>9, "meeting_owner_id"=>3}, {"meeting_id"=>2, "meeting_start_time"=>DateTime.parse("2014-09-30 01:53:40 UTC"), "member_meeting_id"=>3, "member_id"=>12, "meeting_owner_id"=>12}, {"meeting_id"=>2, "meeting_start_time"=>DateTime.parse("2014-09-30 01:53:40 UTC"), "member_meeting_id"=>4, "member_id"=>42, "meeting_owner_id"=>12}]

    filtered_meetings = [{"meeting_id"=>2, "meeting_start_time"=>DateTime.parse("2014-09-30 01:53:40 UTC"), "member_meeting_id"=>3, "member_id"=>12, "meeting_owner_id"=>12}, {"meeting_id"=>2, "meeting_start_time"=>DateTime.parse("2014-09-30 01:53:40 UTC"), "member_meeting_id"=>4, "member_id"=>42, "meeting_owner_id"=>12}]
    assert_equal_unordered filtered_meetings, remove_invalid_meetings(meetings)
  end

  def test_get_diff_in_percentage
    assert_nil get_diff_in_percentage(0, 1)
    assert_nil get_diff_in_percentage(nil, 1)

    assert_equal 0.00, get_diff_in_percentage(1, 1)
    assert_equal 50.00, get_diff_in_percentage(2, 3)
    assert_equal -50.00, get_diff_in_percentage(2, 1)
  end

  def test_get_profile_filters_for_outcomes_report
    program = programs(:albers)
    profile_questions = OutcomesReportUtils.get_profile_filters_for_outcomes_report(program)

    assert_equal [], profile_questions.select{|pq| pq.default_type? }
    assert_equal [], profile_questions.select{|pq| pq.skype_id_type? }
    assert_equal [], profile_questions.select{|pq| pq.email_type? }

    role_ids = program.mentoring_role_ids

    assert_equal_unordered profile_questions.collect(&:id), program.role_questions.select{|rq| role_ids.include?(rq.role_id)}.collect(&:profile_question).flatten.select { |pq| pq.non_default_type? && !pq.skype_id_type? && !pq.file_type? }.collect(&:id).uniq
  end
end