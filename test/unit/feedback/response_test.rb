require_relative './../../test_helper.rb'

class Feedback::ResponseTest < ActiveSupport::TestCase

  def setup
    super
    @program = programs(:albers)
    @group = groups(:mygroup)
    @mentee = @group.students.first
    @mentor = @group.mentors.first
    @feedback_form = @program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first

    @response = Feedback::Response.create_from_answers(@mentee, @mentor, 4, @group, @feedback_form, {})
  end

  def test_create_from_answers
    assert_false @response.errors.present?
    assert @response.id.present?
  end

  def test_check_for_unpublished_group
    unpublished_group = groups(:drafted_group_1)
    response = Feedback::Response.create_from_answers(unpublished_group.students.first, unpublished_group.mentors.first, 4, unpublished_group, @feedback_form, {})
    assert response.errors[:base].present?
    assert response.errors[:base].include?("mentoring connection is not yet published.")
  end

  def test_check_mentor_belongs_to_group
    mentor_outside_group = users(:mentor_1)
    response = Feedback::Response.create_from_answers(@mentee, mentor_outside_group, 4, @group, @feedback_form, {})
    assert response.errors[:base].present?
    assert response.errors[:base].include?("mentor_b chronus is not a part of this mentoring connection as a mentor.")
  end

  def test_check_mentee_belongs_to_group
    mentee_outside_group = users(:f_student)
    response = Feedback::Response.create_from_answers(mentee_outside_group, @mentor, 4, @group, @feedback_form, {})
    assert response.errors[:base].present?
    assert response.errors[:base].include?("student example is not a part of this mentoring connection as a student.")
  end

  def test_check_group_and_response_belongs_to_same_program
    feedback_form = programs(:ceg).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    response = Feedback::Response.create_from_answers(@mentee, @mentor, 4, @group, feedback_form, {})
    assert response.errors[:base].include?("mentoring connection and feedback form belongs to different programs")
  end

  def test_dependent_destroys
    question = @feedback_form.questions.where(:program_id => @program.id).first
    answer = Feedback::Answer.create!(:question => question, :answer_text => "Good.", :response => @response)
    assert_equal 1, Feedback::Answer.count

    #destroying response
    @response.destroy
    assert_equal 0, Feedback::Answer.count
  end

  def test_rating_receiver_association
    assert_equal @response.rating_receiver, @mentor
  end

  def test_rating_giver_association
    assert_equal @response.rating_giver, @mentee
  end

  def test_validation_for_feedback_form
    response = Feedback::Response.new(:rating_giver => @mentee, :rating_receiver => @mentor, :rating => 4, :group => @group)
    assert_false response.valid?
    assert response.errors[:feedback_form].include?("can't be blank")
  end

  def test_validation_for_rating_receiver
    response = Feedback::Response.new(:rating_giver => @mentee, :rating => 4, :group => @group, :feedback_form => @feedback_form)
    assert_false response.valid?
    assert response.errors[:rating_receiver].include?("can't be blank")
  end

  def test_validation_for_rating
    # rating is not present but we are setting default value
    response = Feedback::Response.new(:rating_giver => @mentee, :rating_receiver => @mentor, :group => @group, :feedback_form => @feedback_form)
    assert response.valid?

    # rating is less than zero
    response = Feedback::Response.new(:rating_giver => @mentee, :rating_receiver => @mentor, :group => @group, :feedback_form => @feedback_form, :rating => -1)
    assert_false response.valid?
    assert response.errors[:rating].include?("must be greater than or equal to 0.5")

    # rating is greater than 5
    response = Feedback::Response.new(:rating_giver => @mentee, :rating_receiver => @mentor, :group => @group, :feedback_form => @feedback_form, :rating => 6)
    assert_false response.valid?
    assert response.errors[:rating].include?("must be less than or equal to 5")
  end

  def test_notify_admins
    response = Feedback::Response.create!(:rating_giver => @mentee, :rating_receiver => @mentor, :group => @group, :feedback_form => @feedback_form, :rating => 4)

    assert response.valid?

    num_admin = @program.admin_users.active.count
    assert_difference "JobLog.count", num_admin do
      assert_emails num_admin do
        response.notify_admins
      end
    end
  end

private

  def _mentoring_connection
    "mentoring connection"
  end

  def _mentor
    "mentor"
  end

  def _mentee
    "student"
  end
end