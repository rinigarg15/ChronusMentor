class AddDescriptionAndLogoToAuthConfigs< ActiveRecord::Migration[4.2]
  def up
    add_column :auth_configs, :description, :text
    add_column :auth_configs, :logo_file_name, :string
    add_column :auth_configs, :logo_content_type, :string
    add_column :auth_configs, :logo_file_size, :integer
    add_column :auth_configs, :logo_updated_at, :datetime
  end

  def down
    remove_column :auth_configs, :description
    remove_column :auth_configs, :logo_file_name
    remove_column :auth_configs, :logo_content_type
    remove_column :auth_configs, :logo_file_size
    remove_column :auth_configs, :logo_updated_at
  end
end