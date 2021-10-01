class RemoveDraftUsersInAdminViewFilters< ActiveRecord::Migration[4.2]

  def remove_draft_state_for_users!(filter_params)
    states_hsh = filter_params[:roles_and_status][:state] if filter_params[:roles_and_status].present?
    states_hsh.delete(:draft) if states_hsh.present? && states_hsh[:draft].present?
  end

  def up
    # Program.active.each do |program|
    # reran this as rake task to include inactive programs also.
    Program.all.each do |program|
      program.admin_views.where("default_view IS NULL").each do |admin_view|
        filter_params = YAML.load(admin_view.filter_params)
        next if filter_params.blank?
        remove_draft_state_for_users!(filter_params)
        admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
        admin_view.save!
      end
    end
  end

  def down
    # No down migration
  end
end
