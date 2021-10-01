class AddEligibilityRulesToRoles< ActiveRecord::Migration[4.2]
  def change
    add_column :roles, :eligibility_rules, :boolean
  end
end
