class AddRoleEligibilityMessage< ActiveRecord::Migration[4.2]
  def up
    add_column :roles, :eligibility_message, :text, default: nil 
  end

  def down
    remove_column :roles, :eligibility_message, :text, default: nil
  end
end
