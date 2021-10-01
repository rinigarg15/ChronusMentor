require_relative './../../test_helper.rb'

class Feedback::QuestionTest < ActiveSupport::TestCase

  def setup
    super
    @program = programs(:albers)
    @group = groups(:mygroup)
    @mentee = @group.students.first
    @mentor = @group.mentors.first
    @feedback_form = @program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    @response = Feedback::Response.create!(:rating_giver => @mentee, :rating_receiver => @mentor, :rating => 4, :group => @group, :feedback_form => @feedback_form)
    @question = @feedback_form.questions.where(:program_id => @program.id).first
    @answer = Feedback::Answer.create!(:question => @question, :answer_text => "Good.", :response => @response)
  end

  def test_dependent_destroys
    #destroying the question
    assert_difference "Feedback::Answer.count", -@question.answers.count do
      @question.destroy
    end
  end

  def test_belongs_to_feedback_form_association
    assert_equal @question.feedback_form, @feedback_form
  end

  def test_has_many_answers_association
    assert @question.answers.include?(@answer)
  end

  def test_validation_for_feedback_form
    question = Feedback::Question.new()

    assert_false question.valid?
    assert question.errors[:feedback_form].include?("can't be blank")
  end

  def test_save_user_answer
    response = Feedback::Response.create!(:rating_giver => @mentee, :rating_receiver => @mentor, :rating => 4, :group => @group, :feedback_form => @feedback_form)
    assert_difference "Feedback::Answer.count", 1 do
      @question.save_user_answer(@mentee, "Good", response)
    end
  end

  def test_positioning
    assert_equal 1, @question.position
    new_question = @feedback_form.questions.create!(program_id: @program.id, question_text: "Albers New Question!?", question_type: CommonQuestion::Type::STRING, position: 1)
    assert_equal 1, new_question.position
    assert_equal 2, @question.reload.position

    program_2 = programs(:nwen)
    feedback_form_2 = program_2.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    new_question_2 = feedback_form_2.questions.create!(program_id: program_2.id, question_text: "Nwen New Question!?", question_type: CommonQuestion::Type::STRING)
    assert_equal 2, new_question_2.position
  end
end