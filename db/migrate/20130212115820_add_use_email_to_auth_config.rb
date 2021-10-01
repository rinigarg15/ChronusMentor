class AddUseEmailToAuthConfig< ActiveRecord::Migration[4.2]
  def change
    add_column :auth_configs, :use_email, :boolean, :default => false
  end
end
