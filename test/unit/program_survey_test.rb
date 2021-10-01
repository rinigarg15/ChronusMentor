require_relative './../test_helper.rb'

class ProgramSurveyTest < ActiveSupport::TestCase

  def test_required_fields
    assert_multiple_errors([{:field => :program}, {:field => :name}, {:field => :recipient_roles}]) do
      ProgramSurvey.create!
    end
  end

  def test_recipient_role_assignment
    survey = create_program_survey(:recipient_role_names => [RoleConstants::MENTOR_NAME])
    assert_equal [RoleConstants::MENTOR_NAME], survey.recipient_role_names

    survey.recipient_role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].join(",")
    survey.save!
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
        survey.recipient_role_names
  end

  def test_allowed_to_attend
    survey = create_program_survey

    assert survey.allowed_to_attend?(users(:f_student))
    assert survey.allowed_to_attend?(users(:f_mentor))
    assert survey.allowed_to_attend?(users(:f_mentor_student))
    assert !survey.allowed_to_attend?(users(:ceg_admin))
    assert !survey.allowed_to_attend?(users(:psg_mentor))

    survey.recipient_role_names = [RoleConstants::STUDENT_NAME]
    survey.save!
    assert survey.allowed_to_attend?(users(:f_student))
    assert !survey.allowed_to_attend?(users(:f_mentor))
    assert survey.allowed_to_attend?(users(:f_mentor_student))
    assert !survey.allowed_to_attend?(users(:ceg_admin))
    assert !survey.allowed_to_attend?(users(:psg_mentor))
  end

  def test_allowed_to_attend_survey
    survey = create_program_survey({:recipient_role_names => [RoleConstants::STUDENT_NAME]})
    assert_equal [RoleConstants::STUDENT_NAME], survey.recipient_role_names
    assert survey.allowed_to_attend?(users(:f_student))
    assert_false survey.allowed_to_attend?(users(:f_mentor))
    assert_false survey.allowed_to_attend?(users(:f_admin))
  end

  def test_due_date_should_occur_in_future
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :due_date, "date occurs in the past" do
      ProgramSurvey.create!(
        :program => programs(:albers),
        :name => "First Survey",
        :due_date => 2.days.ago.to_date)
    end
  end

  def test_create_success_and_associations
    due_date = 3.days.from_now.to_date
    assert_difference 'Survey.count' do
      @survey = ProgramSurvey.new(
        :program => programs(:albers),
        :name => "First Survey",
        :due_date => due_date)
      @survey.recipient_role_names = [RoleConstants::STUDENT_NAME]
      @survey.save!
    end

    assert_equal programs(:albers), @survey.program
    assert_equal "First Survey", @survey.name
    assert_equal due_date, @survey.due_date
  end

  def test_overdue
    # No due date
    assert_nil surveys(:one).due_date
    assert_false surveys(:one).overdue?

    # Due date has not come yet.
    surveys(:one).update_attribute :due_date, 2.days.from_now
    assert_false surveys(:one).reload.overdue?

    Survey.skip_timestamping do
      old_date = 3.days.ago.to_date
      surveys(:one).update_attribute :due_date, old_date
      assert_equal old_date.to_date, surveys(:one).reload.due_date.to_date
    end

    # This one is overdue.
    assert surveys(:one).reload.overdue?
  end

  def test_formatted_due_date
    assert_nil surveys(:one).due_date
    assert_nil surveys(:one).formatted_due_date

    due_date = 2.days.from_now.to_date
    surveys(:one).update_attribute :due_date, due_date
    surveys(:one).reload
    assert_equal due_date.strftime("%B %d, %Y"), surveys(:one).formatted_due_date

    new_due_date = 1.month.from_now.to_date
    surveys(:one).update_attribute :formatted_due_date, new_due_date.strftime("%B %d, %Y")
    surveys(:one).reload
    assert_equal new_due_date.strftime("%B %d, %Y"), surveys(:one).formatted_due_date

    assert_nothing_raised do
      surveys(:one).update_attribute :formatted_due_date, ''
    end
    assert_equal new_due_date, surveys(:one).reload.due_date

    assert_nothing_raised do
      surveys(:one).update_attribute :formatted_due_date, 'some text'
    end
    assert_equal new_due_date, surveys(:one).reload.due_date
  end

  def test_not_expired_scope
    assert_nil surveys(:one).due_date
    assert ProgramSurvey.not_expired.pluck(:id).include?(surveys(:one).id)

    surveys(:one).update_attribute :due_date, 2.days.from_now
    assert ProgramSurvey.not_expired.pluck(:id).include?(surveys(:one).id)

    Survey.skip_timestamping do
      old_date = 3.days.ago.to_date
      surveys(:one).update_attribute :due_date, old_date
      assert surveys(:one).overdue?
    end
    assert_false ProgramSurvey.not_expired.pluck(:id).include?(surveys(:one).id)
  end

  def test_expired_scope
    assert_nil surveys(:one).due_date
    assert_false ProgramSurvey.expired.pluck(:id).include?(surveys(:one).id)
    surveys(:one).update_attribute :due_date, 2.days.ago
    assert ProgramSurvey.expired.pluck(:id).include?(surveys(:one).id)
  end
end