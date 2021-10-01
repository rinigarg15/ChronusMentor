class AddPublishingToMentoringTemplateMilestones< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_template_milestones, :publishing, :boolean, default: false, null: false
  end
end
