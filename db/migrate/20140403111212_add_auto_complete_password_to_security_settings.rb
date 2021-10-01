class AddAutoCompletePasswordToSecuritySettings< ActiveRecord::Migration[4.2]
  def up
    add_column :security_settings, :can_autocomplete_password, :boolean, default: true
  end
  def down
    remove_column :security_settings, :can_autocomplete_password
  end
end