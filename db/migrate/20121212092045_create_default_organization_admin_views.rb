class CreateDefaultOrganizationAdminViews< ActiveRecord::Migration[4.2]
  def change
  	Organization.active.all.each do |organization|
      Organization.create_default_admin_views(organization.id)
      puts "Default Admin Views for #{organization.name} created."
    end
  end
end
