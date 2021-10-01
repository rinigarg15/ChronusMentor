require_relative './../test_helper.rb'

class SurveyResponseColumnTest < ActiveSupport::TestCase
  def test_validations
    survey = surveys(:progress_report)
    survey.survey_response_columns.destroy_all

    survey_response_column = SurveyResponseColumn.new
    assert_false survey_response_column.valid?
    assert_equal(["can't be blank"], survey_response_column.errors[:survey])
    assert_equal(["column object type and question type id/key combination is not valid"], survey_response_column.errors[:base])

    survey_response_column = SurveyResponseColumn.new(:survey => survey, :column_key => "name123", :ref_obj_type => SurveyResponseColumn::ColumnType::DEFAULT)
    assert_false survey_response_column.valid?
    assert_equal(["column object type and question type id/key combination is not valid"], survey_response_column.errors[:base])

    survey_response_column = SurveyResponseColumn.new(:survey => survey, :column_key => "name", :ref_obj_type => SurveyResponseColumn::ColumnType::DEFAULT)
    assert survey_response_column.valid?

    survey_response_column = SurveyResponseColumn.create!(:survey => survey, :profile_question_id => 1, :position => 9, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)
    assert survey_response_column.valid?

    survey_response_column = SurveyResponseColumn.new(:survey => survey, :profile_question_id => 1, :ref_obj_type => SurveyResponseColumn::ColumnType::SURVEY)
    assert_false survey_response_column.valid?
    assert_equal(["column object type and question type id/key combination is not valid"], survey_response_column.errors[:base]) 

    survey_response_column = SurveyResponseColumn.create!(:survey => survey, :survey_question_id => 1, :position => 10, :ref_obj_type => SurveyResponseColumn::ColumnType::SURVEY)
    assert survey_response_column.valid?
  end

  def test_associations
    survey = surveys(:progress_report)
    survey.survey_response_columns.destroy_all

    survey_question = survey.survey_questions.first
    survey_response_column = SurveyResponseColumn.create!(:survey => survey, :survey_question => survey_question, :position => 0, :ref_obj_type => SurveyResponseColumn::ColumnType::SURVEY)

    assert_equal survey, survey_response_column.survey
    assert_equal survey_question, survey_response_column.survey_question

    profile_question = profile_questions(:profile_questions_3)
    survey_response_column = SurveyResponseColumn.create!(:survey => survey, :profile_question => profile_question, :position => 1, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)
    assert_equal profile_question, survey_response_column.profile_question
  end

  def test_scopes
    survey = surveys(:progress_report)

    survey.survey_response_columns.destroy_all

    default_column = SurveyResponseColumn.create!(:survey => survey, :column_key => "name", :position => 1, :ref_obj_type => SurveyResponseColumn::ColumnType::DEFAULT) 
    survey_question = survey.survey_questions.first
    survey_question_column = SurveyResponseColumn.create!(:survey => survey, :survey_question => survey_question, :position => 2, :ref_obj_type => SurveyResponseColumn::ColumnType::SURVEY) 

    profile_question = profile_questions(:profile_questions_3)
    profile_question_column = SurveyResponseColumn.create!(:survey => survey, :profile_question => profile_question, :position => 3, :ref_obj_type => SurveyResponseColumn::ColumnType::USER) 

    assert_equal [default_column], survey.survey_response_columns.of_default_columns
    assert_equal [survey_question_column], survey.survey_response_columns.of_survey_questions
    assert_equal [profile_question_column], survey.survey_response_columns.of_profile_questions
  end

  def test_key
    survey = surveys(:progress_report)

    profile_question = programs(:org_primary).profile_questions.select{|q| q.default_choices.present?}.first
    profile_question_column = survey.survey_response_columns.create!(:survey_id => survey.id, :position => survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)
    assert_equal profile_question.id.to_s, profile_question_column.key

    default_column = survey.survey_response_columns.first
    assert_equal "name", default_column.key

    survey_question = survey.survey_questions.first
    survey_question_column = survey.survey_response_columns.of_survey_questions.select{|col| col.survey_question_id == survey_question.id}.first
    assert_equal survey_question.id.to_s, survey_question_column.key
  end

  def test_kendo_column_field
    survey = surveys(:progress_report)
    profile_question = programs(:org_primary).profile_questions.select{|q| q.default_choices.present?}.first

    survey.survey_response_columns.create!(:survey_id => survey.id, :position => survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)

    default_column = survey.survey_response_columns.of_default_columns.first
    survey_question_column = survey.survey_response_columns.of_survey_questions.first
    profile_question_column = survey.survey_response_columns.of_profile_questions.first

    assert_equal default_column.kendo_column_field, default_column.column_key
    assert_equal survey_question_column.kendo_column_field, "answers#{survey_question_column.survey_question.id}"
    assert_equal profile_question_column.kendo_column_field, "column#{profile_question_column.profile_question.id}"
  end

  def test_kendo_field_header
    survey = surveys(:progress_report)

    default_column_1 = survey.survey_response_columns.of_default_columns.where(:column_key => "name").first
    default_column_2 = survey.survey_response_columns.of_default_columns.where(:column_key => "date").first
    default_column_3 = survey.survey_response_columns.of_default_columns.where(:column_key => "surveySpecific").first

    assert_equal default_column_1.kendo_field_header, "feature.survey.responses.fields.name".translate
    assert_equal default_column_2.kendo_field_header, "feature.survey.responses.fields.date".translate
    assert_equal survey.survey_response_columns.of_default_columns.where(column_key: "roles").first.kendo_field_header, "feature.survey.survey_report.filters.header.user_role".translate
    assert_equal default_column_3.kendo_field_header, "Mentoring Connection"
  end

  def test_get_default_title
    survey = surveys(:progress_report)

    assert_equal SurveyResponseColumn.get_default_title("name", survey), "feature.survey.responses.fields.name".translate
    assert_equal SurveyResponseColumn.get_default_title("date", survey), "feature.survey.responses.fields.date".translate
    assert_equal SurveyResponseColumn.get_default_title("roles", survey), "feature.survey.survey_report.filters.header.user_role".translate
    assert_equal SurveyResponseColumn.get_default_title("surveySpecific", survey), "Mentoring Connection"

    survey.stubs(:engagement_survey?).returns(false)
    survey.stubs(:meeting_feedback_survey?).returns(true)
    assert_equal SurveyResponseColumn.get_default_title("surveySpecific", survey), "Meeting"
  end

  def test_date_range_columns
    survey = surveys(:progress_report)
    date_question = profile_questions(:date_question)

    assert_equal ["date"], SurveyResponseColumn.date_range_columns(survey)
    assert_equal ["date"], SurveyResponseColumn.date_range_columns(nil)

    survey.survey_response_columns.create!(:survey_id => survey.id, :position => survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => date_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)
    assert_equal ["date", "column#{date_question.id}"], SurveyResponseColumn.date_range_columns(survey.reload)
  end

  def test_find_object
    survey = surveys(:progress_report)

    profile_question = programs(:org_primary).profile_questions.select{|q| q.default_choices.present?}.first

    survey.survey_response_columns.create!(:survey_id => survey.id, :position => survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)

    column_object_array = survey.survey_response_columns

    default_column = survey.survey_response_columns.of_default_columns.first
    survey_question_column = survey.survey_response_columns.of_survey_questions.first
    profile_question_column = survey.survey_response_columns.of_profile_questions.first

    assert_equal SurveyResponseColumn.find_object(column_object_array, default_column.column_key, SurveyResponseColumn::ColumnType::DEFAULT), default_column
    assert_equal SurveyResponseColumn.find_object(column_object_array, profile_question_column.profile_question.id.to_s, SurveyResponseColumn::ColumnType::USER), profile_question_column
    assert_equal SurveyResponseColumn.find_object(column_object_array, survey_question_column.survey_question.id.to_s, SurveyResponseColumn::ColumnType::SURVEY), survey_question_column
  end
end