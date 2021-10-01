class AddAutoEmailToAdminMessages< ActiveRecord::Migration[4.2]
  def change
    add_column :messages, :auto_email, :boolean, default: false
  end
end