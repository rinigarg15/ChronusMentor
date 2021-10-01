class ChangeMobileLogoToProgramAssets< ActiveRecord::Migration[4.2]
  def change
  	change_column :program_assets, :mobile_logo_file_size, :integer
    change_column :program_assets, :mobile_logo_updated_at, :datetime
  end
end
