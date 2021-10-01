class AddDescriptionToAdminViews< ActiveRecord::Migration[4.2]
	def change
  	add_column :admin_views, :description, :text
  end
end
