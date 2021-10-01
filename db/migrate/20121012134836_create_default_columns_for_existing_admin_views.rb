class CreateDefaultColumnsForExistingAdminViews< ActiveRecord::Migration[4.2]
  def change
    AdminView.all.each do |admin_view|
      if admin_view.admin_view_columns.blank?
        admin_view.create_default_columns 
        puts "==========  #{admin_view.program.name} ==============="
      end
    end
  end
end
