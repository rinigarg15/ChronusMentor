class AddProgramRoleStateHashToEligibilityRulesMemberView < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      AdminView.includes(:program).find_each do |admin_view|
        if admin_view.is_organization_view? && admin_view.filter_params_hash[:program_role_state].nil? && (admin_view.default_view == AbstractView::DefaultType::ELIGIBILITY_RULES_VIEW)
          params_hash = admin_view.filter_params_hash
          new_program_role_state_hash = {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true, AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE}
          params_hash.merge!(program_role_state: new_program_role_state_hash)
          admin_view.filter_params = AdminView.convert_to_yaml(params_hash)
          admin_view.save!
        end
      end
    end
  end

  def down
  end
end
