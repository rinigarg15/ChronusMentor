class CreateTranslationTablesForProgramAssetLogo< ActiveRecord::Migration[4.2]
  def up
    ProgramAsset.create_translation_table!({
      :logo_file_name => :string,
      :logo_content_type => :string,
      :logo_file_size => :integer,
      :banner_file_name => :string,
      :banner_content_type => :string,
      :banner_file_size => :integer,
    },
    {
      :migrate_data => true
    })
  end

  def down
    ProgramAsset.drop_translation_table! :migrate_data => true
  end
end
