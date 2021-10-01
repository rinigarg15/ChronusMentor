require_relative './../../test_helper.rb'

class SurveyQuestionFilterServiceForAdminViewsTest < ActiveSupport::TestCase

  def setup
    super
    @survey = surveys(:progress_report)
    @question1 = common_questions(:q3_name)
    @question2 = common_questions(:q3_from)
  end

  def test_filtered_user_ids
    sqfs = SurveyQuestionFilterServiceForAdminViews.new("anything", [1,2,3,4,5])
    sqfs.stubs(:apply_survey_question_filters).with("anything").returns("something")
    assert_equal "something", sqfs.filtered_user_ids
  end

  def test_apply_survey_question_filters
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, [1,2,3,4,5])
    filter1 = {:questions_1=>{:survey_id => @survey.id, :question => "answers#{@question1.id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "mentor", :choice => ""}}
    filter2 = {:questions_2=>{:survey_id => @survey.id,:question => "answers#{@question2.id}", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value => "", :choice => question_choices(:q3_from_3).id.to_s}}
    survey_filters = filter1.merge(filter2)
    sqfs.stubs(:users_with_answer_that_contains).returns([1,2,3,4])
    sqfs.stubs(:users_with_answer_that_does_not_contain).returns([3,4,5])
    assert_equal_unordered [3,4], sqfs.send(:apply_survey_question_filters, survey_filters)
  end

  def test_get_question_operator_and_value_from_filter
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, "Anything")
    filter = {:survey_id => @survey.id, :question => "answers#{@question1.id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "mentor", :choice => ""}
    returned_array = Array.new([@survey, @question1, AdminViewsHelper::QuestionType::WITH_VALUE.to_s, "mentor"])
    assert_equal returned_array, sqfs.send(:get_question_operator_and_value_from_filter, filter)
  end

  def test_user_that_match_filter
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, "Anything")

    sqfs.stubs(:users_with_answer_that_contains).with(@survey, @question1, "value").returns(1)
    assert_equal 1, sqfs.send(:user_that_match_filter, @survey, AdminViewsHelper::QuestionType::WITH_VALUE.to_s, "value", @question1)

    sqfs.stubs(:users_with_answer_filled).with(@survey, @question1).returns(3)
    assert_equal 3, sqfs.send(:user_that_match_filter, @survey, AdminViewsHelper::QuestionType::ANSWERED.to_s, "value", @question1)

    sqfs.stubs(:users_with_answer_not_filled).with(@survey, @question1).returns(4)
    assert_equal 4, sqfs.send(:user_that_match_filter, @survey, AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s, "value", @question1)
  end

  def test_get_filtered_user_ids_for_choice_based_with_values
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, "Anything")
    a1 = common_answers(:q3_from_answer_2)
    a2 = common_answers(:q3_from_answer_1)
    assert_equal [a1.user_id], sqfs.send(:get_filtered_user_ids_for_choice_based_with_values, @survey, @question2.id, [question_choices(:q3_from_3).id])
    assert_equal [a2.user_id], sqfs.send(:get_filtered_user_ids_for_choice_based_with_values, @survey,  @question2.id, [question_choices(:q3_from_1).id])
    assert_equal_unordered [a2.user_id, a1.user_id], sqfs.send(:get_filtered_user_ids_for_choice_based_with_values, @survey, @question2.id, question_choices(:q3_from_1, :q3_from_3).collect(&:id))
    assert_equal [], sqfs.send(:get_filtered_user_ids_for_choice_based_with_values, @survey, @question2.id, [question_choices(:q3_from_2).id])
  end

  def test_users_with_answer_that_contains
    SurveyAnswer.expects(:get_es_survey_answers).with({:match_query=>{'answer_text.language_*'=>"remove"}, :filter=>{:common_question_id=>@question1.id, :survey_id=>@survey.id, :is_draft=>false}, :source_columns=>["user_id"]}).returns([Elasticsearch::Model::HashWrapper.new(user_id: 69), Elasticsearch::Model::HashWrapper.new(user_id: 68)])

    SurveyAnswer.expects(:get_es_survey_answers).with({:match_query=>{'answer_text.language_*'=>"Something that doesnt exist"}, :filter=>{:common_question_id=>@question1.id, :survey_id=>@survey.id, :is_draft=>false}, :source_columns=>["user_id"]}).returns([])
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, "Anything")
    assert_false CommonQuestion::Type.checkbox_filterable.include?(@question1.question_type)
    user_ids = @question1.common_answers.pluck(:user_id).uniq
    assert_equal_unordered user_ids, sqfs.send(:users_with_answer_that_contains, @survey, @question1, "remove")
    assert_equal [], sqfs.send(:users_with_answer_that_contains, @survey, @question1, "Something that doesnt exist")

    assert CommonQuestion::Type.checkbox_filterable.include?(@question2.question_type)
    sqfs.stubs(:get_filtered_user_ids_for_choice_based_with_values).with(@survey, @question2.id,  [998, 999]).returns([1,5])
    assert_equal [1,5], sqfs.send(:users_with_answer_that_contains, @survey, @question2, "998,999")
  end

  def test_users_with_answer_that_does_not_contain
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, [1,2,3,4,5])
    SurveyQuestionFilterServiceForAdminViews.any_instance.stubs(:users_with_answer_that_contains).with(@survey, @question1, "something").returns([3,4])
    assert_equal [1,2,5], sqfs.send(:users_with_answer_that_does_not_contain, @survey, @question1, "something")
  end

  def test_users_with_answer_filled
    user_ids = @question1.common_answers.pluck(:user_id).uniq
    assert user_ids.present?
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, "Anything")
    assert_equal user_ids, sqfs.send(:users_with_answer_filled, @survey, @question1)
  end

  def test_users_with_answer_not_filled
    sqfs = SurveyQuestionFilterServiceForAdminViews.new({}, [1,2,3,4,5])
    SurveyQuestionFilterServiceForAdminViews.any_instance.stubs(:users_with_answer_filled).with(@survey, @question1).returns([3,4])
    assert_equal [1,2,5], sqfs.send(:users_with_answer_not_filled, @survey, @question1)
  end

end