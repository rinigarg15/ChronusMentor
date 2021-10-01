class AddTemplateVersionToMentoringModelObjects< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_milestones, :template_version, :integer
    add_column :mentoring_model_goals, :template_version, :integer
    add_column :mentoring_model_tasks, :template_version, :integer

    [MentoringModel::Milestone, MentoringModel::Goal, MentoringModel::Task].each do |klass|
      klass.reset_column_information
      klass.from_template.update_all(template_version: 1)
    end
  end
end