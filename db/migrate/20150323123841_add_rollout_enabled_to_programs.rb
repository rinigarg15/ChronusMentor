class AddRolloutEnabledToPrograms< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :rollout_enabled, :boolean, default: false
    Program.update_all(rollout_enabled: true)
    Organization.update_all(rollout_enabled: true)
  end

  def down
    remove_column :programs, :rollout_enabled
  end
end
