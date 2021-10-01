class CreateProgramAssets< ActiveRecord::Migration[4.2]
  def change
    create_table :program_assets do |t|
      t.integer :program_id
      t.string "logo_file_name"
  	  t.string "logo_content_type"
  	  t.integer "logo_file_size"
  	  t.datetime "logo_updated_at"
  	  t.string "banner_file_name"
  	  t.string "banner_content_type"
  	  t.integer "banner_file_size"
  	  t.datetime "banner_updated_at"
      t.timestamps null: false
    end
  end
end
