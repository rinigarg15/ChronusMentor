require_relative './../../test_helper.rb'

class Feedback::FormTest < ActiveSupport::TestCase

  def setup
    super
    @program = programs(:albers)
    @feedback_form = Feedback::Form.where(program_id: @program.id, form_type: Feedback::Form::Type::COACH_RATING).first
  end

  def test_program_association
    assert @program.feedback_forms.include?(@feedback_form)
  end

  def test_hash_many_questions_association
    question = Feedback::Question.where(program_id: @program.id, type: "Feedback::Question").first
    assert @feedback_form.questions.include?(question)

    #destroying form
    assert_difference "Feedback::Question.count", -@feedback_form.questions.count do
      @feedback_form.destroy
    end
  end

  def test_has_many_responses_association
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first

    response = Feedback::Response.create_from_answers(mentee, mentor, 4, group, @feedback_form, {})
    assert @feedback_form.responses.include?(response)

    #destroying feedback form, testing dependent destroy
    assert_difference "Feedback::Response.count", -@feedback_form.responses.count do
      @feedback_form.destroy
    end
  end

  def test_hash_many_answers_association
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first

    response = Feedback::Response.create_from_answers(mentee, mentor, 4, group, @feedback_form, {})
    question = @feedback_form.questions.where(:program_id => @program.id).first
    answer = Feedback::Answer.create!(:question => question, :answer_text => "Good.", :response => response)

    assert @feedback_form.answers.include?(answer)

    #destroying feedback form, testing dependent destroy
    assert_difference "Feedback::Answer.count", -@feedback_form.answers.count do
      @feedback_form.destroy
    end
  end

  def test_validation_for_program
    feedback_form = Feedback::Form.new(form_type: Feedback::Form::Type::COACH_RATING)

    assert_false feedback_form.valid?

    assert feedback_form.errors[:program].include?("can't be blank")
  end

  def test_validation_for_form_type
    # form type is not present
    feedback_form = Feedback::Form.new(program: @program)

    assert_false feedback_form.valid?
    assert feedback_form.errors[:form_type].include?("can't be blank")

    # form type should be included in the list
    feedback_form = Feedback::Form.new(program: @program, form_type: 0)

    assert_false feedback_form.valid?
    assert feedback_form.errors[:form_type].include?("is not included in the list")
  end

  def test_scope_of_type
    Feedback::Form.of_type(Feedback::Form::Type::COACH_RATING).each do |feedback_form|
      assert_equal feedback_form.form_type, Feedback::Form::Type::COACH_RATING
    end
  end
end