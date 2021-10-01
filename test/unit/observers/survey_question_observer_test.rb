require_relative './../../test_helper.rb'

class SurveyQuestionObserverTest < ActiveSupport::TestCase

  def test_after_create
    survey = surveys(:progress_report)
    assert_difference "SurveyResponseColumn.count", +1 do
      create_survey_question({:program => programs(:no_mentor_request_program), allow_other_option: true, :question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => "get,set,go", :survey => survey})
    end
  end

  def test_after_update
    mq = surveys(:progress_report).survey_questions.new(:question_type => CommonQuestion::Type::MATRIX_RATING, :matrix_setting => CommonQuestion::MatrixSetting::FORCED_RANKING, :program_id => programs(:no_mentor_request_program).id, :question_text => "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, pos| mq.question_choices.build(text: text, position: pos + 1, ref_obj: mq) }
    mq.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    mq.create_survey_question
    mq.save

    rq = mq.rating_questions.first

    assert_equal "Bad,Average,Good", mq.default_choices.join(",")
    assert_equal "Bad,Average,Good", rq.default_choices.join(",")

    mq.question_choices.last.update_attributes!(text: "Very Good")

    assert_equal "Bad,Average,Very Good", rq.reload.default_choices.join(",")
  end

  def test_after_save
    ChronusElasticsearch.skip_es_index = false
    survey = surveys(:progress_report)
    program = survey.program
    survey_question = create_survey_question(program: program, allow_other_option: true, question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: "get,set,go", survey: survey)
    survey_answer = SurveyAnswer.create!(answer_value: { answer_text: "My answer", question: survey_question }, user: users(:no_mreq_student), response_id: 1, last_answered_at: Time.current, survey_question: survey_question)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [survey_answer.group_id].reject(&:nil?))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(SurveyAnswer, [survey_answer.id])
    survey_question.reload.update_attributes(survey_id: program.surveys.where.not(id: survey.id).first.id)
    ChronusElasticsearch.skip_es_index = true
  end
end