require_relative './../test_helper.rb'

class SurveyQuestionTest < ActiveSupport::TestCase
  def test_role_is_not_required
    assert_nothing_raised do
      assert_difference 'SurveyQuestion.count' do
        SurveyQuestion.create!(
          {:program => programs(:albers),
            :question_text => "How are you?",
            :question_type => CommonQuestion::Type::STRING,
            :survey => surveys(:one)})
      end
    end
  end

  def test_survey_is_required
    assert_no_difference 'SurveyQuestion.count' do
      assert_raise(NoMethodError) do
        SurveyQuestion.create!(
          :program => programs(:albers),
          :question_text => "How are you?",
          :question_type => CommonQuestion::Type::STRING)
      end
    end
  end

  def test_positive_choices
    survey = programs(:albers).surveys.where(name: "Introduce yourself")[0]
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    choices_hash = survey_question.question_choices.index_by(&:text)
    survey_question.update_attribute(:positive_outcome_options, choices_hash["Earth"].id.to_s)
    assert_equal ["Smallville", "Krypton", "Earth"], survey_question.default_choices
    assert_equal [choices_hash["Earth"].id.to_s], survey_question.positive_choices
    survey_question.update_attribute(:positive_outcome_options, "#{choices_hash["Earth"].id},#{choices_hash["Krypton"].id}")
    assert_equal [choices_hash["Earth"].id.to_s, choices_hash["Krypton"].id.to_s], survey_question.positive_choices

    survey_question.update_attribute(:positive_outcome_options_management_report , choices_hash["Earth"].id.to_s)
    assert_equal [choices_hash["Earth"].id.to_s], survey_question.positive_choices(true)
  end

  def test_rating_type_is_supported
    assert_nothing_raised do
      assert_difference 'SurveyQuestion.count' do
        sq = SurveyQuestion.create!(
          {program: programs(:albers),
            question_text: "How are you?",
            question_type: CommonQuestion::Type::RATING_SCALE,
            survey: surveys(:one)})
        ["good", "best"].each_with_index {|text, pos| sq.question_choices.create!(text: text, position: pos + 1)}
      end
    end
  end

  def test_survey_belongs_to_program
    assert_no_difference 'SurveyQuestion.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :survey,
        "does not belong to the program") do

        # surveys(:one) belongs to albers program. Expect an error
        SurveyQuestion.create!(
          {:program => programs(:ceg),
            :question_text => "How are you?",
            :question_type => CommonQuestion::Type::STRING,
            :survey => surveys(:one)})
      end
    end
  end

  def test_associations
    assert_difference 'SurveyQuestion.count' do
      @survey_question = SurveyQuestion.create!(
        {:program => programs(:albers),
          :question_text => "How are you?",
          :question_type => CommonQuestion::Type::STRING,
          :survey => surveys(:one)})
    end

    assert_equal surveys(:one), @survey_question.survey
    assert_equal programs(:albers), @survey_question.program
  end

  def test_has_many_answers
    assert_difference 'SurveyQuestion.count' do
      @survey_question = SurveyQuestion.create!(
        {:program => programs(:albers),
          :question_text => "How are you?",
          :question_type => CommonQuestion::Type::STRING,
          :survey => surveys(:one)})
    end

    assert @survey_question.survey_answers.empty?
    answer_1 = SurveyAnswer.create!(
      {:answer_text => "My answer", :user => users(:robert), :last_answered_at => Time.now.utc, :survey_question => @survey_question})
    answer_2 = SurveyAnswer.create!(
      {:answer_text => "My answer", :user => users(:rahim), :last_answered_at => Time.now.utc, :survey_question => @survey_question})
    answer_3 = SurveyAnswer.create!(
      {:answer_text => "My answer", :user => users(:f_student), :last_answered_at => Time.now.utc, :survey_question => @survey_question})

    assert_equal [answer_1, answer_2, answer_3], @survey_question.survey_answers.reload
  end

  def test_choice_based
    rating_q = create_survey_question({
        question_type: CommonQuestion::Type::RATING_SCALE,
        question_choices: "1,2,3"})
    assert rating_q.choice_based?

    text_q = create_survey_question({
        question_type: CommonQuestion::Type::STRING})
    assert !text_q.choice_based?

    choice_q = create_survey_question({
        question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "red,blue,green"})
    assert choice_q.choice_based?
  end

  def test_change_of_question_info_should_destroy_all_answers
    question = create_survey_question({
        question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "yes,no"})
    create_survey_answer({answer_value: {answer_text: 'yes', question: question},
        survey_question: question, user: users(:f_student)})

    create_survey_answer({answer_value: {answer_text: 'yes', question: question},
        survey_question: question, user: users(:f_mentor)})

    assert_difference 'SurveyAnswer.count', -2 do
      question.question_choices.destroy_all
      ["Abc", "Cde"].each_with_index{|text, pos| question.question_choices.create!(text: text, position: pos + 1)}
    end
  end

  def test_delete_of_question_should_destroy_all_answers
    question = create_survey_question({
        question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "yes,no"})
    create_survey_answer({answer_value: {answer_text: 'yes', question: question},
        survey_question: question, user: users(:f_student)})

    create_survey_answer({answer_value: {answer_text: 'yes', question: question},
        survey_question: question, user: users(:f_mentor)})

    assert_difference 'SurveyQuestion.count', -1 do
      assert_difference 'SurveyAnswer.count', -2 do
        assert_difference 'AnswerChoice.count', -2 do
          assert_difference 'QuestionChoice.count', -2 do
            question.destroy
          end
        end
      end
    end
  end

  def test_no_notify_chronus_on_question_create_or_update
    assert_difference 'SurveyQuestion.count' do
      assert_no_emails do
        @question = create_survey_question({
            question_type: CommonQuestion::Type::SINGLE_CHOICE,
            question_choices: "yes,no"})
      end
    end

    assert_no_emails do
      @question.update_attribute :question_text, "New question"
    end
  end

  def test_create_survey_response_column_and_association
    survey = surveys(:progress_report)
    survey_question = survey.survey_questions.first

    assert_difference "SurveyResponseColumn.count", -1 do
      survey_question.survey_response_columns.destroy_all
    end

    survey_question.stubs(:is_part_of_matrix_question?).returns(true)
    assert_no_difference "SurveyResponseColumn.count" do
      survey_question.create_survey_response_column
    end

    survey_question.stubs(:is_part_of_matrix_question?).returns(false)
    assert_difference "SurveyResponseColumn.count", 1 do
      survey_question.create_survey_response_column
    end
  end

  def test_create_survey_question
    survey = surveys(:progress_report)
    q = survey.survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, matrix_setting: CommonQuestion::MatrixSetting::FORCED_RANKING, program_id: programs(:no_mentor_request_program).id, question_text: "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, pos| q.question_choices.build(text: text, position: pos + 1, ref_obj: q) }
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question

    assert_equal 3, q.rating_questions.count
    assert_equal "Ability,Confidence,Talent", q.matrix_rating_question_texts.join(",")
    assert_equal ["Ability","Confidence","Talent"], q.new_matrix_rating_questions_texts
  end

  def test_matrix_rating_associations
    q = surveys(:progress_report).survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, matrix_setting: CommonQuestion::MatrixSetting::FORCED_RANKING, program_id: programs(:no_mentor_request_program).id, question_text: "Matrix Question")
    ["Bad","Average","Good"].each_with_index {|text, pos| q.question_choices.build(text: text, position: pos + 1, ref_obj: q)}
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question

    survey = q.survey

    rating_questions = SurveyQuestion.where(:survey_id => survey.id, :matrix_question_id => q.id)

    assert_equal_unordered q.rating_questions, rating_questions

    assert_equal q, q.rating_questions.last.matrix_question
  end

  def test_build_or_update_matrix_rating_questions
    q = surveys(:progress_report).survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, matrix_setting: CommonQuestion::MatrixSetting::FORCED_RANKING, program_id: programs(:no_mentor_request_program).id, question_text: "Matrix Question", condition: SurveyQuestion::Condition::CANCELLED)

    question_choice_params = {existing_question_choices_attributes: [{"101"=>{"text" => "Bad"}, "102"=>{"text" =>"Average"}, "103"=>{"text" => "Good"}}], question_choices: {new_order: "101,102,103"}}
    matrix_question_params = {existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Confidence"}, "103"=>{"text" => "Talent"}}], rows: {new_order: "101,102,103"} }
    assert_difference "SurveyQuestion.count", 4 do
      q.create_survey_question(question_choice_params, matrix_question_params)
    end
    assert_equal 3, q.rating_questions.count
    assert_equal [SurveyQuestion::Condition::CANCELLED], q.rating_questions.pluck(:condition).uniq
    q.rating_questions.destroy_all
    assert_equal 0, q.rating_questions.count

    q.build_or_update_matrix_rating_questions(matrix_question_params)
    q.save!
    mq_ids = q.rating_questions.pluck(:id)
    assert_equal 3, q.rating_questions.count
    assert_equal ["Ability","Confidence","Talent"], q.matrix_rating_question_texts

    matrix_question_params = {existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Confidence"}, "103"=>{"text" => "Talent"}}], rows: {new_order: "101,103,102"} }
    q.build_or_update_matrix_rating_questions(matrix_question_params)
    q.save!
    assert_equal ["Ability","Talent","Confidence"], q.matrix_rating_question_texts
    assert_equal_unordered mq_ids, q.rating_questions.pluck(:id)
    assert_equal 3, q.rating_questions.count

    matrix_question_params = {existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Talent"}, "103"=>{"text" => "Attitude"}}], rows: {new_order: "101,102,103"} }
    q.build_or_update_matrix_rating_questions(matrix_question_params)
    q.save!

    assert_equal ["Ability","Talent","Attitude"], q.matrix_rating_question_texts
    assert_not_equal mq_ids, q.rating_questions.pluck(:id)
    assert_equal 3, q.rating_questions.count

    q.reload
    matrix_question_params = {existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Talent"}}], rows: {new_order: "101,102"} }

    assert_difference "SurveyQuestion.count", -1 do
      q.build_or_update_matrix_rating_questions(matrix_question_params)
      q.save!
    end
    assert_equal 2, q.rating_questions.count

    q.reload
    matrix_question_params = {existing_rows_attributes: [{"101"=>{"text" => "Ability-fr"}, "102"=>{"text" => "Talent-fr"}, "103"=>{"text" => "New"}}], rows: {new_order: "101,102,103"} }
    run_in_another_locale(:'fr-CA') do
      assert_difference "SurveyQuestion.count", 1 do
        q.build_or_update_matrix_rating_questions(matrix_question_params)
        q.save!
      end
      assert_equal 3, q.reload.rating_questions.count
      assert_equal "Ability-fr", q.rating_questions.first.question_text
      assert_equal "New", q.rating_questions.last.question_text
    end

    assert_equal "Ability", q.rating_questions.first.question_text
    assert_equal "New", q.rating_questions.last.question_text

    matrix_question_params = {existing_rows_attributes: [{"101"=>{"text" => "New"}, "102"=>{"text" => "Ability"}}], rows: {new_order: "101,102"} }
    assert_difference "SurveyQuestion.count", -1 do
      q.build_or_update_matrix_rating_questions(matrix_question_params)
      q.save!
    end
    assert_equal 2, q.reload.rating_questions.count
    assert_equal "Ability", q.rating_questions.last.question_text
    assert_equal "New", q.rating_questions.first.question_text

    run_in_another_locale(:'fr-CA') do
      assert_equal "Ability-fr", q.rating_questions.last.question_text
      assert_equal "New", q.rating_questions.first.question_text
    end
  end

  def test_associated_answers
    mq = create_matrix_survey_question
    assert_equal [], mq.associated_answers

    SurveyAnswer.create!({answer_value: {answer_text: "Good", question: mq}, user: users(:f_student), last_answered_at: Time.now.utc, survey_question: mq})
    assert_equal [], mq.reload.associated_answers

    a = SurveyAnswer.create!({answer_value: {answer_text: "Good", question: mq}, user: users(:f_student), last_answered_at: Time.now.utc, survey_question: mq.rating_questions.first})
    assert_equal [a], mq.reload.associated_answers
  end

  def test_question_text_for_display
    mq = create_matrix_survey_question
    assert_equal mq.question_text, mq.question_text_for_display
    assert_equal common_questions(:common_questions_1).question_text, common_questions(:common_questions_1).question_text_for_display
    rq = mq.rating_questions.first
    assert_equal "#{mq.question_text} - #{rq.question_text}", rq.question_text_for_display
  end

  def test_kendo_column_field
    q = common_questions(:common_questions_1)
    assert_equal "answers#{q.id}", q.kendo_column_field
  end

  def test_matrix_rating_validations_and_utility_functions
    survey = surveys(:progress_report)
    q = survey.survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, matrix_setting: CommonQuestion::MatrixSetting::FORCED_RANKING, program_id: programs(:no_mentor_request_program).id, question_text: "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, pos| q.question_choices.build(text: text, position: pos + 1, ref_obj: q) }
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question

    assert_false q.is_part_of_matrix_question?

    mq = q.rating_questions.last

    assert_equal "", mq.matrix_rating_question_texts.join(",")

    assert mq.is_part_of_matrix_question?

    mq.matrix_position = nil

    assert_false mq.valid?
    assert_equal ["can't be blank"], mq.errors[:matrix_position]

    q.matrix_setting = 2

    assert_false q.valid?
    assert_equal ["is not included in the list"], q.errors[:matrix_setting]

    assert_equal "Ability,Confidence,Talent", q.matrix_rating_question_texts.join(",")

    q.update_attribute(:matrix_setting, CommonQuestion::MatrixSetting::FORCED_RANKING)
    q.build_or_update_matrix_rating_questions({existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Confidence"}, "103"=>{"text" => "Talent"}, "104"=>{"text" => "Attitude"}}], rows: {new_order: "101,102,103,104"} })
    q.save
    assert_raise ActiveRecord::RecordInvalid, :matrix_setting, "number of rows cannot be more than number of choices in case of forced ranking" do
      q.send(:forced_ranking_validness)
    end

    q.rating_questions.destroy_all
    assert_false q.valid?
    assert_equal ["Matrix question needs to have at least one rating question."], q.errors[:rating_questions]
  end

  def test_make_condition_and_required_consistant
    mq = create_matrix_survey_question
    assert_false mq.required
    assert_equal "Very Good,Good,Average,Poor", mq.default_choices.join(",")

    mq.rating_questions.each do |rq|
      assert_equal "Very Good,Good,Average,Poor", rq.default_choices.join(",")
      assert_false rq.required
    end

    mq.required = true
    mq.condition = SurveyQuestion::Condition::CANCELLED
    mq.save!
    mq.rating_questions.each do |rq|
      assert rq.required
      assert_equal SurveyQuestion::Condition::CANCELLED, rq.condition
    end

    rq = mq.rating_questions.first
    rq.question_text = "Something"
    rq.required = false
    rq.condition = SurveyQuestion::Condition::COMPLETED
    mq.save!
    assert_equal "Something", rq.question_text
    assert rq.required
    assert_equal SurveyQuestion::Condition::CANCELLED, rq.condition
  end

  def test_remove_matrix_rating_questions_marked_for_destroy
    mq = create_matrix_survey_question
    assert_equal 3, mq.rating_questions.count

    rq = mq.rating_questions.first
    assert_equal "Leadership", rq.question_text
    rq._marked_for_destroy_ = true
    assert_difference "SurveyQuestion.count", -1 do
      mq.save!
    end
    assert_equal 2, mq.rating_questions.count
    assert_false mq.rating_questions.pluck(:question_text).include?("Leadership")
  end

  def test_remove_matrix_rating_questions_unless_is_a_matrix_question
    mq = create_matrix_survey_question
    assert_equal 3, mq.rating_questions.count
    assert_difference "SurveyQuestion.count", -3 do
      mq.update_attributes(question_type: CommonQuestion::Type::STRING)
    end
    assert_equal 0, mq.rating_questions.count
  end

  def test_update_survey_question
    survey = programs(:albers).surveys.find_by(name: "Meeting Feedback Survey For Mentees")
    q = survey.survey_questions.first
    assert_equal CommonQuestion::Type::SINGLE_CHOICE, q.question_type
    assert_equal "How was your overall meeting experience?", q.question_text

    q.update_survey_question({question_type: CommonQuestion::Type::STRING, question_text: "String type"})
    assert q.valid?
    assert_equal CommonQuestion::Type::STRING, q.question_type
    assert_equal "String type", q.question_text

    assert_raise(ActiveRecord::RecordInvalid, :question_text, "can't be blank") do
      q.update_survey_question({question_type: CommonQuestion::Type::STRING, question_text: nil})
    end
    assert_difference "SurveyQuestion.count", 3 do
      qc_params = {existing_question_choices_attributes: [{"101"=>{"text" => "a"}, "102"=>{"text" => "b"}, "103"=>{"text" => "c"}, "104"=>{"text" => "d"}}], question_choices: {new_order: "101,102,103,104"}}
      matrix_params = {existing_rows_attributes: [{"101"=>{"text" => "x"}, "102"=>{"text" => "y"}, "103"=>{"text" => "z"}}], rows: {new_order: "101,102,103"} }
      q.update_survey_question({question_type: CommonQuestion::Type::MATRIX_RATING, question_text: "matrix"}, matrix_params, qc_params)
    end
    assert q.valid?
    assert_equal CommonQuestion::Type::MATRIX_RATING, q.question_type
    assert_equal 3, q.rating_questions.count

    assert_difference "SurveyQuestion.count", -3 do
      q.update_survey_question({question_type: CommonQuestion::Type::STRING})
    end
    assert_equal 0, q.reload.rating_questions.count
  end

  def test_presence_of_condition
    ms = MeetingFeedbackSurvey.first
    sq = ms.survey_questions.new(question_type: CommonQuestion::Type::STRING, question_text: "someting", program: programs(:albers), condition: nil)
    assert_false sq.valid?
    assert_equal ["can't be blank", "is not included in the list"], sq.errors[:condition]
    sq.condition = 777
    assert_false sq.valid?
    assert_equal ["is not included in the list"], sq.errors[:condition]
  end

  def test_show_always
    sq = SurveyQuestion.last
    sq.condition = SurveyQuestion::Condition::ALWAYS
    assert sq.send(:show_always?)
    sq.condition = SurveyQuestion::Condition::COMPLETED
    assert_false sq.send(:show_always?)
  end

  def test_show_only_if_meeting_completed
    sq = SurveyQuestion.last
    sq.condition = SurveyQuestion::Condition::COMPLETED
    assert sq.send(:show_only_if_meeting_completed?)
    sq.condition = SurveyQuestion::Condition::CANCELLED
    assert_false sq.send(:show_only_if_meeting_completed?)
  end

  def test_show_only_if_meeting_cancelled
    sq = SurveyQuestion.last
    sq.condition = SurveyQuestion::Condition::CANCELLED
    assert sq.send(:show_only_if_meeting_cancelled?)
    sq.condition = SurveyQuestion::Condition::ALWAYS
    assert_false sq.send(:show_only_if_meeting_cancelled?)
  end

  def test_for_completed
    sq = SurveyQuestion.last
    sq.condition = SurveyQuestion::Condition::ALWAYS
    assert sq.for_completed?
    sq.condition = SurveyQuestion::Condition::COMPLETED
    assert sq.for_completed?
    sq.condition = SurveyQuestion::Condition::CANCELLED
    assert_false sq.for_completed?
  end

  def test_for_cancelled
    sq = SurveyQuestion.last
    sq.condition = SurveyQuestion::Condition::ALWAYS
    assert sq.for_cancelled?
    sq.condition = SurveyQuestion::Condition::COMPLETED
    assert_false sq.for_cancelled?
    sq.condition = SurveyQuestion::Condition::CANCELLED
    assert sq.for_cancelled?
  end

  def test_can_be_shown
    sq = SurveyQuestion.last
    meeting = Meeting.first
    meeting.update_attribute(:state, Meeting::State::COMPLETED.to_s)
    mm = meeting.member_meetings.first
    sq.stubs(:show_always?).returns(false)
    sq.stubs(:show_only_if_meeting_completed?).returns(false)
    sq.stubs(:show_only_if_meeting_cancelled?).returns(false)
    Survey.any_instance.stubs(:meeting_feedback_survey?).returns(false)
    assert sq.can_be_shown? mm.id
    Survey.any_instance.stubs(:meeting_feedback_survey?).returns(true)
    assert_false sq.can_be_shown? mm.id
    sq.stubs(:show_always?).returns(true)
    assert sq.can_be_shown? mm.id
    sq.stubs(:show_always?).returns(false)
    sq.stubs(:show_only_if_meeting_completed?).returns(true)
    assert sq.can_be_shown? mm.id
    sq.stubs(:show_only_if_meeting_completed?).returns(false)
    sq.stubs(:show_only_if_meeting_cancelled?).returns(true)
    assert_false sq.can_be_shown? mm.id
    meeting.update_attribute(:state, Meeting::State::CANCELLED.to_s)
    assert sq.can_be_shown? mm.id

    mq = surveys(:progress_report).survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, matrix_setting: CommonQuestion::MatrixSetting::FORCED_RANKING, program_id: programs(:no_mentor_request_program).id, question_text: "Matrix Question", condition: SurveyQuestion::Condition::COMPLETED)
    ["Bad","Average","Good"].each_with_index{|text, pos| mq.question_choices.build(text: text, position: pos + 1, ref_obj: mq) }
    mq.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    mq.create_survey_question

    assert_equal [SurveyQuestion::Condition::COMPLETED], mq.rating_questions.collect(&:condition).uniq

    assert_false mq.can_be_shown?(mm.id)
    assert_false mq.rating_questions.first.can_be_shown?(mm.id)

    meeting.update_attribute(:state, Meeting::State::COMPLETED.to_s)

    assert mq.can_be_shown?(mm.id)
    assert mq.rating_questions.first.can_be_shown?(mm.id)
  end

  def test_positioning
    survey_1 = surveys(:one)
    survey_2 = surveys(:two)
    question_1 = create_survey_question(survey: survey_1)
    assert_equal 1, question_1.position
    question_2 = create_survey_question(survey: survey_1, position: 1)
    assert_equal 2, question_1.reload.position
    assert_equal 1, question_2.position

    question_3 = create_survey_question(survey: survey_2, position: 1)
    assert_equal 1, question_3.position
    assert_equal 1, question_2.reload.position
    assert_equal 2, question_1.reload.position
  end

  def test_positive_outcome_configured
    assert_equal [], SurveyQuestion.positive_outcome_configured.all
    sq1 = SurveyQuestion.first
    sq2 = SurveyQuestion.last
    sq1.update_attribute(:positive_outcome_options, "something")
    sq2.update_attribute(:positive_outcome_options, "something else")
    assert_equal [sq1.id, sq2.id], SurveyQuestion.positive_outcome_configured.all.collect(&:id)
  end

  def test_tied_to_dashboard
    survey_question = SurveyQuestion.find_by(positive_outcome_options_management_report: nil)
    assert_false survey_question.tied_to_dashboard?
    survey_question.update_attribute(:positive_outcome_options_management_report, "something")
    assert survey_question.tied_to_dashboard?
  end

  def test_tied_to_positive_outcomes_report
    survey_question = SurveyQuestion.find_by(positive_outcome_options: nil)
    assert_false survey_question.tied_to_positive_outcomes_report?
    survey_question.update_attribute(:positive_outcome_options, "something")
    assert survey_question.tied_to_positive_outcomes_report?
  end
end