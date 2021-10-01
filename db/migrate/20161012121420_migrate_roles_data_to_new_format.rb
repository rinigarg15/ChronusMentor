class MigrateRolesDataToNewFormat< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      AdminView.find_each do |admin_view|
        next unless admin_view.is_program_view?
        filter_params = admin_view.filter_params_hash
        if filter_params[:roles_and_status] && filter_params[:roles_and_status][:roles]
          role_names = filter_params[:roles_and_status].delete(:roles)
          filter_params[:roles_and_status][:role_filter_1] = {type: :include, roles: role_names.split(',')}
          admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
          admin_view.save!
        end
      end
    end
  end

  def down
    # nothing
  end
end
