require_relative './../test_helper.rb'

class SurveyAnswerTest < ActiveSupport::TestCase

  def test_validation_of_user
    question = create_survey_question(:survey => surveys(:one))
    assert_difference('SurveyAnswer.count') do
      SurveyAnswer.create!({:answer_text => "My answer", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => question})
    end

    assert !SurveyAnswer.new({:answer_text => "My answer", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => question}).valid?
    assert SurveyAnswer.new({:answer_text => "My answer", :user => users(:f_student), :response_id => 2, last_answered_at: Time.now.utc, :survey_question => question}).valid?
    assert SurveyAnswer.new({:answer_text => "My answer", :user => users(:student_1), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => question}).valid?
  end

  def test_survey_question_is_required
    assert_no_difference 'SurveyAnswer.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :survey_question) do
        SurveyAnswer.create!(:answer_text => "My answer", :user => users(:ram), last_answered_at: Time.now.utc)
      end
    end
  end

  def test_profile_question_is_not_valid_for_survey_question
    assert_no_difference 'SurveyAnswer.count' do
      assert_raise ActiveRecord::AssociationTypeMismatch do
        SurveyAnswer.create!(
          {:answer_text => "My answer", :user => users(:ram), last_answered_at: Time.now.utc, :survey_question => create_question}
        )
      end
    end
  end

  def test_user_can_be_any_non_admin
    question = create_survey_question
    assert_difference 'SurveyAnswer.count', 3 do
      assert_nothing_raised do
        # Student answers
        SurveyAnswer.create!(
          {:answer_text => "My answer",
            :user => users(:f_student), last_answered_at: Time.now.utc, :survey_question => question}
        )

        # Mentor answers
        SurveyAnswer.create!(
          {:answer_text => "My answer",
            :user => users(:f_mentor), last_answered_at: Time.now.utc, :survey_question => question}
        )

        # Admin-Mentor answers
        SurveyAnswer.create!(
          {:answer_text => "My answer",
            :user => users(:ram), last_answered_at: Time.now.utc, :survey_question => question}
        )
      end
    end

    # Only-admin cannot answer
    assert_no_difference 'SurveyAnswer.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :user,
        "cannot participate in the survey") do
        SurveyAnswer.create!(
          {:answer_text => "My answer",
            :user => users(:f_admin), last_answered_at: Time.now.utc, :survey_question => question}
        )
      end
    end
  end

  def test_with_response_ids_in_scope
    assert SurveyAnswer.all.present?
    assert_equal SurveyAnswer.all, SurveyAnswer.with_response_ids_in(nil).all

    response_id = SurveyAnswer.first.response_id
    assert_equal [response_id], SurveyAnswer.with_response_ids_in([response_id]).pluck(:response_id).uniq
  end

  def test_for_user_scope
    user = users(:f_admin)
    sa = create_survey_answer
    assert_equal [], SurveyAnswer.for_user(user)

    sa.update_attribute(:user_id, user.id)
    assert_equal [sa], SurveyAnswer.for_user(user)
  end

  def test_last_answered_in_date_range
    assert_equal 4, SurveyAnswer.last_answered_in_date_range(1.day.ago..7.days.from_now).count
    assert_equal 2, SurveyAnswer.last_answered_in_date_range(Time.now.utc..7.days.from_now).count
  end

  def test_cannot_answer_an_overdue_survey
    question = create_survey_question({:survey => surveys(:one)})
    survey = question.survey

    # update_attribute so as to skip validations
    survey.update_attribute :due_date, 2.days.ago
    assert survey.reload.overdue?

    assert_no_difference 'SurveyAnswer.count' do
      @answer = SurveyAnswer.create(
        {:answer_text => "My answer",
          :user => users(:f_student), last_answered_at: Time.now.utc, :survey_question => question}
      )
    end

    assert_equal ["Sorry. The survey has passed it's due date."], @answer.errors[:base]
  end

  def test_survey_assign
    question = create_survey_question
    survey = question.survey

    answer_params = { answer_text: "My answer", user: users(:f_student), last_answered_at: Time.now.utc }
    answer = question.survey_answers.create(answer_params)

    assert_not_nil answer.survey_id
    assert_equal survey.id, answer.survey_id
  end

  def test_survey_on_question_change
    question = create_survey_question
    survey = question.survey

    answer_params = { answer_text: "My answer", user: users(:f_student), last_answered_at: Time.now.utc }
    answer = question.survey_answers.create(answer_params)

    new_survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    assert_not_equal new_survey, survey
    question.update_attributes(survey_id: new_survey.id)

    assert_equal new_survey.id, answer.reload.survey_id
  end

  def test_member_meeting_association
    survey = programs(:albers).get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME)
    time = 2.days.ago
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :members => [members(:f_admin), members(:mkr_student)], :owner_id => members(:mkr_student).id, :program_id => programs(:albers).id, :repeats_end_date => time + 4.days, :start_time => time, :end_time => time + 5.hours)
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student))
    survey.survey_questions.each do |sq|
      sq.update_attribute(:condition, SurveyQuestion::Condition::ALWAYS)
    end
    question_id = survey.survey_questions.pluck(:id)
    assert_equal [], meeting.survey_answers
    survey.update_user_answers({question_id[0] => "Very useful", question_id[1] => "Knowledge sharing"}, {user_id: users(:mkr_student).id, :meeting_occurrence_time => meeting.occurrences.first.start_time, member_meeting_id: member_meeting.id})
    assert_equal SurveyAnswer.last(2), meeting.reload.survey_answers
    assert_equal 6, SurveyAnswer.count
    assert_equal member_meeting, SurveyAnswer.last.member_meeting
    assert_equal member_meeting, SurveyAnswer.last(2).first.member_meeting
  end

  def test_scope_last_answered
    Timecop.travel(10.days.from_now) do
      assert_equal [], SurveyAnswer.last_answered(1.day.ago)
      create_survey_answer
      sa = SurveyAnswer.last
      assert_equal [sa], SurveyAnswer.last_answered(1.day.ago)
      sa.update_attribute(:last_answered_at, (sa.last_answered_at - 25.hours))
      assert_equal [], SurveyAnswer.last_answered(1.day.ago)
    end
  end

  def test_default_scope
    sa = create_survey_answer
    assert SurveyAnswer.pluck(:id).include?(sa.id)

    sa.update_attribute(:is_draft, true)
    assert_false SurveyAnswer.pluck(:id).include?(sa.id)
  end

  def test_es_reindex
    survey_answer = create_survey_answer(group: groups(:mygroup))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [survey_answer.group_id])
    SurveyAnswer.es_reindex(survey_answer)
  end

  def test_reindex_group
    survey_answer = create_survey_answer(group: groups(:mygroup))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [survey_answer.group_id])
    SurveyAnswer.send(:reindex_group, [survey_answer.group_id])
  end

  def test_draft_scope
    sa = common_answers(:q3_from_answer_draft)
    assert_equal [sa.id] ,SurveyAnswer.drafted.pluck(:id)
    sa.update_attribute(:is_draft, false)
    assert_equal [], SurveyAnswer.drafted.pluck(:id)
  end
end
