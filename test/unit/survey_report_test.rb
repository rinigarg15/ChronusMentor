require_relative './../test_helper.rb'

class SurveyReportTest < ActiveSupport::TestCase
  def setup
    super
    @survey = surveys(:one)

    @questions = []
    @questions << create_survey_question({survey: @survey})
    @questions << create_survey_question({survey: @survey})
    @questions << create_survey_question({
        question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "get,set,go", survey: @survey})

    @questions << create_survey_question({
        question_type: CommonQuestion::Type::RATING_SCALE,
        question_choices: "bad,good,better,best", survey: @survey})
  end

  def test_add_question_and_check_response
    report = Survey::Report.new(@survey)
    assert_nil report.get_response(@questions[0])
    assert_nil report.get_response(@questions[1])

    report.add_question(@questions[0])
    resp = report.get_response(@questions[0])
    assert_not_nil resp
    assert_equal [], resp.data # String question will have array.

    assert_nil report.get_response(@questions[1])

    report.add_question(@questions[2])
    resp = report.get_response(@questions[2])
    choices_hash = @questions[2].question_choices.index_by(&:text)
    assert_equal({choices_hash["get"].id => 0, choices_hash["set"].id => 0, choices_hash["go"].id => 0}, resp.data)
  end

  def test_empty
    report = Survey::Report.new(@survey)
    assert report.empty?

    report.add_question(@questions[0])
    report.add_question(@questions[1])
    assert report.empty?
    assert report.get_response(@questions[0]).empty?
    assert report.get_response(@questions[1]).empty?

    report.question_responses[@questions[0]].data = ["Hello", "World"]
    report.question_responses[@questions[0]].count = 5
    q_0_response = report.get_response(@questions[0])
    assert_equal 5, q_0_response.count
    assert_equal ["Hello", "World"], q_0_response.data
    
    assert_false report.empty?
    assert_false report.get_response(@questions[0]).empty?
    assert report.get_response(@questions[1]).empty?
  end

  def test_csv_line
    resp = Survey::Report::QuestionResponse.new(@questions[0])
    resp.count = 4
    resp.data = ["hello", "world", "success"]
    assert_equal ['4', "hello\nworld\nsuccess"], resp.csv_line
    resp.data = ["hello", "world, flat", "success"]
    assert_equal ['4', "hello\nworld, flat\nsuccess"], resp.csv_line

    resp = Survey::Report::QuestionResponse.new(@questions[2])
    resp.count = 3
    choices_hash = @questions[2].question_choices.index_by(&:text)

    resp.data = {choices_hash['get'].id => 2, choices_hash['set'].id => 1, choices_hash['go'].id => 0}
    assert_equal ['3', "get => 2%\nset => 1%\ngo => 0%"], resp.csv_line
  end
end
