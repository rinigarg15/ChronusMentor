class AddMobileAuthTokenToMembers< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :mobile_auth_token, :text
  end
end
