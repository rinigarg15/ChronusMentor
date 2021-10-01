class AddActionItemIdToMentoringModelTask< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_tasks, :action_item_id, :integer
    add_column :mentoring_model_task_templates, :action_item_id, :integer

    # Create newly added 'manage_mm_enagement_surveys' permission & enable it for existing mm
    ObjectPermission.create_default_permissions
    Program.includes(:mentoring_models).find_each do |program|
      admin_roles = program.roles.for_mentoring_models.administrative
      program.mentoring_models.each do |mentoring_model|
        mentoring_model.send("allow_#{ObjectPermission::MentoringModel::ENGAGEMENT_SURVEY}!", admin_roles)
      end
    end
  end
end
