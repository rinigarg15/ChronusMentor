class AddZendeskSupportPortalToPrograms< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :zendesk_support_portal, :boolean, :default => true 
    #Organization.reset_column_information
    #Organization.update_all(:zendesk_support_portal => true)
  end
  def down
    remove_column :programs, :zendesk_support_portal
  end
end
