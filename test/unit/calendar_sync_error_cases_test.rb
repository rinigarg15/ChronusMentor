require_relative './../test_helper.rb'

class CalendarSyncErrorCasesTest < ActiveSupport::TestCase
  
  def test_validations
    error_case = CalendarSyncErrorCases.new

    assert_false error_case.valid?
    assert_equal ["is not included in the list"], error_case.errors[:scenario]
    assert_equal ["can't be blank"], error_case.errors[:details]

    error_case.scenario = "scenario"
    error_case.details = "details"

    assert_false error_case.valid?
    assert_equal ["is not included in the list"], error_case.errors[:scenario]

    error_case.scenario = CalendarSyncErrorCases::ScenarioType::EVENT_CREATE

    assert error_case.valid?
  end

  def test_create_error_case
    scenario_type = CalendarSyncErrorCases::ScenarioType::EVENT_CREATE
    options = {meeting_id: 24, user_id: 24}

    assert_difference "CalendarSyncErrorCases.count", 1 do
      CalendarSyncErrorCases.create_error_case(scenario_type, options)
    end

    error_case = CalendarSyncErrorCases.last

    assert_equal CalendarSyncErrorCases::ScenarioType::EVENT_CREATE, error_case.scenario
    assert_equal options, error_case.details
  end
end