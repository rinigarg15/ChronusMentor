require_relative './../../test_helper.rb'

class QuestionChoiceObserverTest < ActiveSupport::TestCase

  def test_update_or_destroy_answer_text_for_multi_choice
    # Multi Choice
    qc = question_choices(:multi_choice_q_1)
    profile_answer = qc.profile_answers.first
    assert_equal "Stand, Run", profile_answer.answer_text
    ProfileAnswer.expects(:es_reindex).with([profile_answer]).once
    assert_no_difference "AnswerChoice.count" do
      qc.update_attributes!(text: "New multi choice")
    end
    assert_equal "New multi choice, Run", profile_answer.reload.answer_text

    # destroy question choice
    ProfileAnswer.expects(:es_reindex).with([profile_answer]).once
    assert_difference "AnswerChoice.count", -1 do
      assert_difference "QuestionChoice.count", -1 do
        qc.destroy
      end
    end
    assert_equal "Run", profile_answer.reload.answer_text
  end

  def test_update_or_destroy_answer_text_for_ordered_options
    # Ordered Options
    @program = programs(:albers)
    o = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :role_names => [RoleConstants::MENTOR_NAME], :question_choices => ["A","B","C","D"], options_count: 2)
    profile_answer = ProfileAnswer.new(:profile_question => o, ref_obj: members(:f_student))
    profile_answer.answer_value = {answer_text: ["B", "C"], question: o}
    profile_answer.save!
    @mentor_question = o.role_questions.reload.first
    @student_question = o.role_questions.new
    @student_question.role = @program.get_role(RoleConstants::STUDENT_NAME)
    @student_question.save!
    MatchConfig.create!(:program => @program, :mentor_question => @mentor_question, :student_question => @student_question)

    qc = o.question_choices.find_by(text: "B")
    assert_equal "B | C", profile_answer.answer_text
    ProfileAnswer.expects(:es_reindex).with([profile_answer]).once
    MatchConfig.any_instance.expects(:refresh_match_config_discrepancy_cache).times(4)
    assert_no_difference "AnswerChoice.count" do
      qc.update_attributes!(text: "New B")
    end
    assert_equal "New B | C", profile_answer.reload.answer_text

    # destroy question choice
    ProfileAnswer.expects(:es_reindex).with([profile_answer]).once
    assert_difference "AnswerChoice.count", -1 do
      assert_difference "QuestionChoice.count", -1 do
        qc.destroy
      end
    end
    assert_equal "C", profile_answer.reload.answer_text
  end

  def test_update_or_destroy_answer_text_for_single_choice
    # Single Choice
    qc = question_choices(:single_choice_q_1)
    profile_answer = qc.profile_answers.first
    assert_equal "opt_1", profile_answer.answer_text
    ProfileAnswer.expects(:es_reindex).with([profile_answer]).once
    assert_no_difference "AnswerChoice.count" do
      qc.update_attributes!(text: "New opt_1")
    end
    assert_equal "New opt_1", profile_answer.reload.answer_text

    # destroy question choice
    ProfileAnswer.expects(:es_reindex).once
    assert_difference "AnswerChoice.count", -1 do
      assert_difference "QuestionChoice.count", -1 do
        assert_difference "ProfileAnswer.count", -1 do
          qc.destroy
        end
      end
    end
    assert_raise(ActiveRecord::RecordNotFound) { profile_answer.reload}
  end

end