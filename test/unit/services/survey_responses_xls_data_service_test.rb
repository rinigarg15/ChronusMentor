require_relative './../../test_helper.rb'

class SurveyResponsesXlsDataServiceTest < ActiveSupport::TestCase

  def test_survey_response_xls_data_service
    survey = surveys(:progress_report)
    program = survey.program
    book = Spreadsheet::Workbook.new
    SurveyResponsesXlsDataService.new(survey, program, program.organization, I18n.default_locale, survey.responses.keys, additional_column_keys: [SurveyResponseColumn::Columns::Program]).build_xls_data_for_survey(book: book)
    assert_equal ["Name", "Email", "Date of response", "Mentoring Connection", "Task", "User Role", "Program", "What is your name?", "Where are you from?"], book.worksheets.first.rows.first.to_a
  end

end