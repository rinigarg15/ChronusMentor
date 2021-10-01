class AddVersionAndShouldSyncToMentoringModels< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_models, :version, :integer, default: 1
    add_column :mentoring_models, :should_sync, :boolean
  end
end
