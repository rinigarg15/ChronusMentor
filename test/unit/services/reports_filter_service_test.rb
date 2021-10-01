require_relative "./../../test_helper.rb"

class ReportsFilterServiceTest < ActiveSupport::TestCase

  def test_get_report_date_range
    Timecop.freeze do
      assert_equal [MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago.to_date, Time.current.to_date], ReportsFilterService.get_report_date_range(nil, MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
      assert_equal [MeetingsController::MentoringSessionConstants::DEFAULT_LIMIT.ago.to_date, Time.current.to_date], ReportsFilterService.get_report_date_range(nil, MeetingsController::MentoringSessionConstants::DEFAULT_LIMIT.ago)
      assert_equal [MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago.to_date, Time.current.to_date], ReportsFilterService.get_report_date_range({}, MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
      assert_equal [MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago.to_date, Time.current.to_date], ReportsFilterService.get_report_date_range({date_range: ""}, MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    end

    assert_equal ["Thu, 10 Jan 2017".to_date, "Thu, 16 Mar 2017".to_date], ReportsFilterService.get_report_date_range({date_range: "01/10/2017 - 03/16/2017"}, MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    assert_equal ["Thu, 16 Mar 2017".to_date, "Thu, 16 Mar 2017".to_date], ReportsFilterService.get_report_date_range({date_range: "03/16/2017"}, MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
  end

  def test_date_to_string
    assert_equal "01/10/2017 - 03/16/2017", ReportsFilterService.date_to_string("10 Jan 2017".to_date, "16 Mar 2017".to_date)
  end

  def test_get_previous_time_period
    program = programs(:albers)
    program.stubs(:created_at).returns("10 Jan 2017".to_date.to_time)
    assert_equal [nil, nil], ReportsFilterService.get_previous_time_period("10 Jan 2017".to_date, "20 Jan 2017".to_date, program)
    assert_equal [nil, nil], ReportsFilterService.get_previous_time_period("20 Jan 2017".to_date, "30 Jan 2017".to_date, program)
    assert_equal ["10 Jan 2017".to_date, "20 Jan 2017".to_date], ReportsFilterService.get_previous_time_period("21 Jan 2017".to_date, "31 Jan 2017".to_date, program)
  end

  def test_dynamic_profile_filter_params
    profile_filter_params = {"6ae3c7"=>{"field"=>"column15", "operator"=>SurveyResponsesDataService::Operators::CONTAINS, "value"=>"", "choice"=>"6-10 years"}}
    assert_equal [{"field"=>"column15", "operator"=>"eq", "value"=>"", "choice"=>"6-10 years"}], ReportsFilterService.dynamic_profile_filter_params(profile_filter_params)

    profile_filter_params = {"6ae3c7"=>{"field"=>"column15", "operator"=>SurveyResponsesDataService::Operators::CONTAINS, "value"=>"", "choice"=>"6-10 years"}, "58305"=>{"field"=>"column17", "operator"=>"answered", "value"=>"", "choice"=>""}}
    assert_equal [{"field"=>"column15", "operator"=>"eq", "value"=>"", "choice"=>"6-10 years"}, {"field"=>"column17", "operator"=>"answered", "value"=>"", "choice"=>""}], ReportsFilterService.dynamic_profile_filter_params(profile_filter_params)
  end

  def test_get_percentage_change
    prev_period_meetings = []
    current_period_meetings = [1,2]
    assert_equal ReportsFilterService.get_percentage_change(prev_period_meetings.count, current_period_meetings.count), 100

    prev_period_meetings = []
    current_period_meetings = []
    assert_equal ReportsFilterService.get_percentage_change(prev_period_meetings.count, current_period_meetings.count),0

    prev_period_meetings = [2,3]
    current_period_meetings = []
    assert_equal ReportsFilterService.get_percentage_change(prev_period_meetings.count, current_period_meetings.count), -100

    prev_period_meetings = [1,2]
    current_period_meetings = [3,4]
    assert_equal ReportsFilterService.get_percentage_change(prev_period_meetings.count, current_period_meetings.count), 0

    prev_period_meetings = [1,2,3,4]
    current_period_meetings = [5,6,7]
    assert_equal ReportsFilterService.get_percentage_change(prev_period_meetings.count, current_period_meetings.count), -25

    prev_period_meetings = [5,6,7]
    current_period_meetings = [1,2,3,4]
    assert_equal ReportsFilterService.get_percentage_change(prev_period_meetings.count, current_period_meetings.count), 33

    prev_period_meetings = nil
    current_period_meetings = [1,2,3,4]
    assert_nil ReportsFilterService.get_percentage_change(nil,  current_period_meetings.count)
  end

  def test_set_percentage_from_ids
    prev_period_meetings = []
    current_period_meetings = [1,2]
    assert_equal ReportsFilterService.set_percentage_from_ids(prev_period_meetings, current_period_meetings), [100,0]

    prev_period_meetings = []
    current_period_meetings = []
    assert_equal ReportsFilterService.set_percentage_from_ids(prev_period_meetings, current_period_meetings),[0,0]

    prev_period_meetings = [2,3]
    current_period_meetings = []
    assert_equal ReportsFilterService.set_percentage_from_ids(prev_period_meetings, current_period_meetings), [-100,2]

    prev_period_meetings = [1,2]
    current_period_meetings = [3,4]
    assert_equal ReportsFilterService.set_percentage_from_ids(prev_period_meetings, current_period_meetings), [0,2]

    prev_period_meetings = [1,2,3,4]
    current_period_meetings = [5,6,7]
    assert_equal ReportsFilterService.set_percentage_from_ids(prev_period_meetings, current_period_meetings), [-25, 4]

    prev_period_meetings = [5,6,7]
    current_period_meetings = [1,2,3,4]
    assert_equal ReportsFilterService.set_percentage_from_ids(prev_period_meetings, current_period_meetings), [33, 3]

    current_period_meetings = [1,2,3,4]
    assert_equal ReportsFilterService.set_percentage_from_ids(nil,  current_period_meetings), [nil, nil]
  end

  def test_program_created_date
    assert_equal programs(:albers).created_at.to_date, ReportsFilterService.program_created_date(programs(:albers))
  end

  def test_dashboard_past_meetings_date
    Timecop.freeze(Time.current) do
      assert_equal Time.current.to_date, ReportsFilterService.dashboard_past_meetings_date
    end
  end

  def test_dashboard_upcoming_end_date
    Timecop.freeze(Time.current) do
      assert_equal (Time.current + 1.year).to_date, ReportsFilterService.dashboard_upcoming_end_date
    end
  end

  def test_dashboard_upcoming_start_date
    Timecop.freeze(Time.current) do
      assert_equal (Time.current + 1.day).to_date, ReportsFilterService.dashboard_upcoming_start_date
    end
  end
end