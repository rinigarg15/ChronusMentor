class UpdateAdmivViewsSignupStateFilters< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      AdminView.find_each do |admin_view|
        filter_params = YAML.load(admin_view.filter_params)
        if filter_params.try(:[], :roles_and_status).try(:[], :signup_state).try(:[], :never_signed_up)
          filter_params[:roles_and_status][:signup_state][:accepted_not_signed_up_users] = AdminView::RolesStatusQuestions::ACCEPTED_NOT_SIGNED_UP
          filter_params[:roles_and_status][:signup_state][:added_not_signed_up_users] = AdminView::RolesStatusQuestions::ADDED_NOT_SIGNED_UP
          filter_params[:roles_and_status][:signup_state].delete(:never_signed_up)
          admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
          admin_view.save!
        end
      end
    end
  end

  def down
    ActiveRecord::Base.transaction do
      AdminView.find_each do |admin_view|
        filter_params = YAML.load(admin_view.filter_params)
        if filter_params.try(:[], :roles_and_status).try(:[], :signup_state)
          if filter_params[:roles_and_status][:signup_state][:accepted_not_signed_up_users] && filter_params[:roles_and_status][:signup_state][:added_not_signed_up_users]
            filter_params[:roles_and_status][:signup_state][:never_signed_up] = AdminView::RolesStatusQuestions::NEVER_SIGNED_UP
            filter_params[:roles_and_status][:signup_state].delete(:accepted_not_signed_up_users)
            filter_params[:roles_and_status][:signup_state].delete(:added_not_signed_up_users)
            admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
            admin_view.save!
          end
        end
      end
    end
  end
end
