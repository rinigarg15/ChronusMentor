class AddDeletedToMentoringTemplateMilestones< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_template_milestones, :deleted, :boolean, default: false, null: false
  end
end
