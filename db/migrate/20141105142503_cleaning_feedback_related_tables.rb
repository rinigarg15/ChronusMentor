class CleaningFeedbackRelatedTables< ActiveRecord::Migration[4.2]
  def up
    Feedback::Form.find_each do |feedback_form|
      feedback_form.destroy
    end
  end

  def down
  end
end
