class AddAllowDueDateEditToMentoringModel< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_models, :allow_due_date_edit, :boolean, :default => false
  end
end
