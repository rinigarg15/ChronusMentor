class AddShowTextTypeAnswersPerReviewerCategoryToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :show_text_type_answers_per_reviewer_category, :boolean, :default => true
  end
end
