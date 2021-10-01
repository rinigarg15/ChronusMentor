class AddMatchConfigType< ActiveRecord::Migration[4.2]
  def change
  	add_column :match_configs, :matching_type, :integer, default: 0
  	add_column :match_configs, :matching_details, :text
  end
end
