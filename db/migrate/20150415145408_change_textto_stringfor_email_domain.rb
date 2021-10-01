class ChangeTexttoStringforEmailDomain< ActiveRecord::Migration[4.2]
  def up
    change_column :security_settings, :email_domain, :text
  end

  def down
    change_column :security_settings, :email_domain, :string
  end
end
