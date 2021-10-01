class AddMobileLogoToProgramAssets< ActiveRecord::Migration[4.2]
  def up
    add_column :program_assets, :mobile_logo_file_name, :string
    add_column :program_assets, :mobile_logo_content_type, :string
    add_column :program_assets, :mobile_logo_file_size, :string
    add_column :program_assets, :mobile_logo_updated_at, :string
  end

  def down
    remove_column :program_assets, :mobile_logo_file_name, :string
    remove_column :program_assets, :mobile_logo_content_type, :string
    remove_column :program_assets, :mobile_logo_file_size, :string
    remove_column :program_assets, :mobile_logo_updated_at, :string
  end
end
