require_relative './../../test_helper.rb'

class Survey::CloneFactoryTest < ActiveSupport::TestCase
  def test_clone_should_success
    program    = programs(:nwen)
    src_survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    questions  = [
      :common_questions_1, :common_questions_2, :common_questions_3
    ].map { |id| common_questions(id) }

    assert_difference "Survey.count", 1 do
      assert_difference "SurveyQuestion.count", 3 do
        assert_difference "program.surveys.count", 1 do
          cloner = Survey::CloneFactory.new(src_survey, program)
          new_survey = cloner.clone
          assert_instance_of EngagementSurvey, new_survey
          new_survey.save!
          #assert_equal src_survey.recipient_roles, new_survey.recipient_roles
          assert_equal program, new_survey.program
        end
      end
    end
  end

  def test_clone_should_success_without_program_given
    program    = programs(:albers)
    src_survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    questions  = [
      :common_questions_1, :common_questions_2, :common_questions_3
    ].map { |id| common_questions(id) }

    assert_difference "Survey.count", 1 do
      assert_difference "SurveyQuestion.count", 3 do
        assert_difference "program.surveys.count", 1 do
          cloner = Survey::CloneFactory.new(src_survey, program)
          new_survey = cloner.clone
          #assert new_survey.new_record?, "expected clone to be new record"
          assert_instance_of EngagementSurvey, new_survey
          new_survey.save!
          #assert_equal src_survey.recipient_roles, new_survey.recipient_roles
          assert_equal program, new_survey.program
        end
      end
    end
  end

  def test_cloning_should_ignore_form_type
    program = programs(:albers)
    survey = program.feedback_survey

    assert_difference "Survey.count", 1 do
      cloner = Survey::CloneFactory.new(survey, program)
      new_survey = cloner.clone
      new_survey.save!
    end

    program.reload
    assert_equal survey, program.feedback_survey
    assert_equal 1, program.surveys.where(form_type: Survey::FormType::FEEDBACK).size
  end

  def test_clone_for_matrix_questions
    survey = surveys(:one)
    assert_equal 0, survey.survey_questions.count

    sq = create_survey_question
    mq = create_matrix_survey_question

    assert_equal 2, survey.survey_questions.count
    assert_equal 5, survey.survey_questions_with_matrix_rating_questions.count

    assert_difference "Survey.count", 1 do
      assert_difference "SurveyQuestion.count", 5 do
        cloner = Survey::CloneFactory.new(survey, nil)
        @new_survey = cloner.clone
        @new_survey.save!
      end
    end

    assert_equal 2, @new_survey.survey_questions.count
    assert_equal [sq.question_text, mq.question_text], @new_survey.survey_questions.pluck(:question_text)
    new_mq = @new_survey.survey_questions.last
    assert_equal 3, new_mq.rating_questions.count
    assert_equal 5, @new_survey.survey_questions_with_matrix_rating_questions.count
  end
end