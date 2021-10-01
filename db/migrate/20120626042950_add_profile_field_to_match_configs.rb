class AddProfileFieldToMatchConfigs< ActiveRecord::Migration[4.2]
  def change
  	add_column :match_configs, :is_profile_field, :boolean, :default => true
  end
end
