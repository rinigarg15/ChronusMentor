class RemoveCanAutoCompletePasswordFromSecuritySettings< ActiveRecord::Migration[4.2]
  def up
    remove_column :security_settings, :can_autocomplete_password
  end

  def down
    add_column :security_settings, :can_autocomplete_password, :boolean, default: true
  end
end
