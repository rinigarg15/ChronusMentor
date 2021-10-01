class AddDefaultFeedbackRatingQuestions< ActiveRecord::Migration[4.2]
  def up
    Program.find_each do |program|
      program.create_default_feedback_rating_questions
    end
  end

  def down
    Feedback::Form.of_type(Feedback::Form::Type::COACH_RATING).destroy_all
  end
end
