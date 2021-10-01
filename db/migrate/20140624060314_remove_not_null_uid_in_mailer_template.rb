class RemoveNotNullUidInMailerTemplate< ActiveRecord::Migration[4.2]
  def up
    change_column :mailer_templates, :uid, :string, :null => true
  end

  def down
    change_column :mailer_templates, :uid, :string, :null => false
  end
end