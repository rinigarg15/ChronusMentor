require_relative "./../../test_helper.rb"

class MeetingRequestsFilterServiceTest < ActiveSupport::TestCase

  def test_get_filtered_meeting_request_ids
    program = programs(:albers)

    program.update_attributes!(:created_at => "2016-01-09 11:30:20")

    assert_equal [program.meeting_requests.pluck(:id), nil], MeetingRequestsFilterService.new(program, {}).get_filtered_meeting_request_ids

    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 11 Jan 2017".to_date, "Thu, 11 Jan 2017".to_date], program.created_at)
    assert_equal [[],[]], MeetingRequestsFilterService.new(program, {}).get_filtered_meeting_request_ids

    program.meeting_requests.first.update_attributes!(created_at: "Thu, 2 Jan 2017".to_datetime.utc)

    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 1 Jan 2017".to_date, "Thu, 20 Jan 2017".to_date], program.created_at)
    assert_equal [[32],[]], MeetingRequestsFilterService.new(program, {}).get_filtered_meeting_request_ids

    program.meeting_requests.second.update_attributes!(created_at: "Thu, 30 Dec 2016".to_datetime.utc)

    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 1 Jan 2017".to_date, "Thu, 20 Jan 2017".to_date], program.created_at)
    assert_equal [[32],[33]], MeetingRequestsFilterService.new(program, {"date_range"=>"01/1/2017 - 01/20/2017"}).get_filtered_meeting_request_ids


    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 10 Jan 2017".to_date, "Thu, 20 Jan 2017".to_date], program.created_at)
    assert_equal [[],[32,33]], MeetingRequestsFilterService.new(program, {}).get_filtered_meeting_request_ids
  end

  def test_get_meeting_request_ids
    program = programs(:albers)
  
    start_date = "Thu, 9 Jan 2017".to_date
    end_date = "Thu, 9 Jan 2017".to_date
    assert_equal MeetingRequestsFilterService.new(program, {}).get_meeting_request_ids(start_date, end_date), []

    program.meeting_requests.first.update_attributes!(created_at: "Thu, 10 Jan 2017".to_datetime.utc)
    end_date = "Thu, 11 Jan 2017".to_date
    assert_equal MeetingRequestsFilterService.new(program, {}).get_meeting_request_ids(start_date, end_date), [32]

    program.meeting_requests.second.update_attributes!(created_at: "Thu, 9 Jan 2017".to_datetime.utc)
    assert_equal MeetingRequestsFilterService.new(program, {}).get_meeting_request_ids(start_date, end_date), [32, 33]
  end

end