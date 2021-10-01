class AddSpecificDateToMentoringModelTaskTemplate< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_task_templates, :specific_date, :datetime
  end
end
