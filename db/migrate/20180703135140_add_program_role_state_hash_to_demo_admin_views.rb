class AddProgramRoleStateHashToDemoAdminViews < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.demo?
        ActiveRecord::Base.transaction do
          all_roles = AbstractProgram.includes(roles: :translations).all.collect(&:roles).flatten.index_by(&:id)
          file = "/tmp/#{Time.now.utc.strftime('%Y%m%d%H%M%S') + "_" + Rails.try(:env)}_filter_params_saved_data.csv"
          CSV.open(file, "a") do |csv|
            AdminView.includes(:program).find_each do |admin_view|
              if admin_view.is_organization_view? && admin_view.filter_params_hash[:program_role_state].nil?
                csv << [admin_view.id, admin_view.filter_params, admin_view.filter_params_hash.inspect]
                params_hash = admin_view.filter_params_hash
                filter_count = 1
                #program_roles
                new_program_role_state_hash = {"all_members" => false, "inclusion" => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE}
                if params_hash[:program_roles].present?
                  prev_role_hash = params_hash[:program_roles].collect{|role_id| all_roles[role_id.to_i]}.compact.group_by(&:program_id)
                  new_program_role_state_hash.merge!({"filter_conditions"=> {"parent_filter_1"=>{}}}) if prev_role_hash.present?
                  prev_role_hash.keys.each do |org_id|
                    new_program_role_state_hash["filter_conditions"]["parent_filter_1"]["child_filter_#{filter_count}"] = {"program"=> [org_id], "role"=> prev_role_hash[org_id].collect(&:name).uniq}
                    filter_count += 1
                  end
                  params_hash.delete(:program_roles)
                end
                # member status
                if params_hash[:member_status]
                  user_state = params_hash[:member_status][:user_state].to_i
                  case user_state
                  when AdminView::UserState::MEMBER_WITH_ACTIVE_USER, AdminView::UserState::MEMBER_WITHOUT_ACTIVE_USER
                    new_program_role_state_hash["filter_conditions"] = {} unless new_program_role_state_hash["filter_conditions"].present?
                    new_program_role_state_hash["filter_conditions"]["parent_filter_2"] = {"child_filter_#{filter_count}"=> {"state"=> [User::Status::ACTIVE]}}
                    new_program_role_state_hash["inclusion"] = (user_state == AdminView::UserState::MEMBER_WITHOUT_ACTIVE_USER) ? AdminView::ProgramRoleStateFilterObjectKey::EXCLUDE : AdminView::ProgramRoleStateFilterObjectKey::INCLUDE
                  else
                    # do nothing
                  end
                  params_hash[:member_status].delete(:user_state)
                end
                if new_program_role_state_hash["filter_conditions"].nil?
                  new_program_role_state_hash["all_members"] = true
                end
                params_hash.merge!(program_role_state: new_program_role_state_hash)
                admin_view.filter_params = AdminView.convert_to_yaml(params_hash)
                admin_view.save!
              end
            end
          end
        end
      end
    end
  end

  def down
    # Do nothing
  end  
end
