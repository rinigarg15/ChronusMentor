require_relative './../../test_helper.rb'

class Feedback::AnswerTest < ActiveSupport::TestCase

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

  def test_belongs_to_question_association
    assert_equal @answer.question, @question
  end

  def test_belongs_to_response_association
    assert_equal @answer.response, @response
  end

  def test_validation_for_response
    answer = Feedback::Answer.new(:question => @question, :answer_text => "Good.")

    assert_false answer.valid?
    assert answer.errors[:response].include?("can't be blank")
  end

  def test_set_user_from_response
    answer = Feedback::Answer.create!(:question => @question, :answer_text => "Bad.", :response => @response)
    assert_equal answer.user, @response.rating_giver
  end
end