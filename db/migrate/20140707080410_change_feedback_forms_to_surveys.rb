class ChangeFeedbackFormsToSurveys< ActiveRecord::Migration[4.2]

  QUESTIONS_TEXT_MATCHES = {
    "How do you communicate with your mentee?" => "How do you communicate with your mentor?",
    "How effective is this mentoring connection?" => "How helpful is this mentoring connection?"
  }
  QUESTIONS_TEXTS = {
    "How do you communicate with your mentor?" => "How do you communicate with the members of this mentoring connection?",
    "How do you communicate with your mentee?" => "How do you communicate with the members of this mentoring connection?",
    "How helpful is this mentoring connection?" => "How effective is this mentoring connection?"
  }
  QUESTION_MODES = {
    "How effective is this mentoring connection?" => CommonQuestion::Mode::EFFECTIVENESS,
    "How do you communicate with the members of this mentoring connection?" => CommonQuestion::Mode::CONNECTIVITY
  }

  def change
    SurveyAnswer.unscoped do
      response_id = SurveyAnswer.maximum(:response_id).to_i + 1
      ActiveRecord::Base.transaction do
        feeedback_response_ids = Feedback::Response.pluck(:id)
        initial_survey_answers_count = SurveyAnswer.count
        feedback_answers_count = Feedback::Answer.where("feedback_response_id IN (?)", feeedback_response_ids).count

        Feedback::Form.includes(:questions, :responses => :answers).each do |feedback_form|
          program = feedback_form.program
          feedback_questions = feedback_form.questions
          feedback_responses = feedback_form.responses
          convertible_questions = []

          survey_name = "#{program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term} Activity Feedback"
          survey = program.surveys.build(name: survey_name)
          survey.type = EngagementSurvey.name
          survey.form_type = Survey::FormType::FEEDBACK
          survey.save!

          comment_questions = feedback_questions.where(question_text: "Additional feedback (optional)").to_a
          convertible_questions << comment_questions.first
          questions_map = {comment_questions.second.try(:id) => comment_questions.first}
          QUESTIONS_TEXT_MATCHES.each do |k, v|
            question_for_key = feedback_questions.find_by(question_text: k)
            question_for_value = feedback_questions.find_by(question_text: v)
            if question_for_key.present?
              convertible_questions << question_for_key
              questions_map[question_for_value.try(:id)] = question_for_key
            elsif question_for_value.present?
              convertible_questions << question_for_value
            end
          end

          convertible_questions.each do |feedback_question|
            feedback_question.type = SurveyQuestion.name
            feedback_question.save!
            survey_question = SurveyQuestion.find(feedback_question.id)
            survey_question.question_text = QUESTIONS_TEXTS[feedback_question.question_text] || feedback_question.question_text
            survey_question.survey_id = survey.id
            survey_question.question_mode = QUESTION_MODES[survey_question.question_text]
            survey_question.save!
          end

          convertible_questions_ids = convertible_questions.collect(&:id)
          feedback_responses.each do |feedback_response|
            if feedback_response.user && !feedback_response.user.is_admin_only?
              answers_converted_for_question_ids = []
              feedback_answers = feedback_response.answers
              question_id_answers_map = feedback_answers.index_by(&:common_question_id)
              feedback_answers.each do |feedback_answer|
                question_id = feedback_answer.common_question_id
                question_id = questions_map[question_id].id unless convertible_questions_ids.include?(question_id)
                if !answers_converted_for_question_ids.include?(question_id)
                  feedback_answer.type = SurveyAnswer.name
                  feedback_answer.save(validate: false)
                  survey_answer = SurveyAnswer.find(feedback_answer.id)
                  unless survey_answer.answer_text.present?
                    survey_answer.answer_text = question_id_answers_map[questions_map[question_id].try(:id)].try(:answer_text)
                  end
                  survey_answer.common_question_id = question_id
                  survey_answer.group_id = feedback_response.group_id
                  survey_answer.survey_id = survey.id
                  survey_answer.response_id = response_id
                  survey_answer.save!
                  answers_converted_for_question_ids << survey_answer.common_question_id
                end
              end
              response_id += 1 if feedback_answers.present?
            end
          end

          survey.total_responses = survey.survey_answers.pluck(:response_id).uniq.count
          survey.save!
        end
        #raise "Count Mismatch!" if SurveyAnswer.count != (initial_survey_answers_count + feedback_answers_count)
      end
    end
  end
end