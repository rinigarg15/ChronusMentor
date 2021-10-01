class UpdateTaskStatusFilterParamsForConnectionViews< ActiveRecord::Migration[4.2]
  def up
    ConnectionView.all.each do |view|
      filter_params_hash = view.filter_params_hash
      if filter_params_hash && filter_params_hash[:params] && filter_params_hash[:params][:search_filters] && filter_params_hash[:params][:search_filters][:v2_tasks_status]
        filter_params_hash[:params][:search_filters][:v2_tasks_status] = GroupsController::TaskStatusFilter::OVERDUE
        view.update_attribute(:filter_params, AbstractView.convert_to_yaml(filter_params_hash)) 
      end
    end
  end

  def down
    ConnectionView.all.each do |view|
      filter_params_hash = view.filter_params_hash
      if filter_params_hash && filter_params_hash[:params] && filter_params_hash[:params][:search_filters] && filter_params_hash[:params][:search_filters][:v2_tasks_status]
        filter_params_hash[:params][:search_filters][:v2_tasks_status] = {"overdue" => [GroupsController::TaskStatusFilter::OVERDUE]}
        view.update_attribute(:filter_params, AbstractView.convert_to_yaml(filter_params_hash)) 
      end
    end
  end
end
