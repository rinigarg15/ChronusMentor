class UpdateAdminViewFilerParams< ActiveRecord::Migration[4.2]
  def change
    views = AdminView.where(default_view: [AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES , AbstractView::DefaultType::NEVER_CONNECTED_MENTEES])
    views.find_each do |view|
      param_hash = view.filter_params_hash
      param_hash["roles_and_status"]["state"] = {"active"=> User::Status::ACTIVE}
      view.filter_params = AdminView.convert_to_yaml(param_hash)
      view.save!
    end
  end
end
