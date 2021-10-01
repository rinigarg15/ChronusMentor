class AddPasswordHistoryLimitToSecuritySettings< ActiveRecord::Migration[4.2]
  def change
    add_column :security_settings, :password_history_limit, :integer
  end
end
