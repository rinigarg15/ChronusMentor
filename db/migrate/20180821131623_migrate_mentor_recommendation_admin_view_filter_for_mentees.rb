class MigrateMentorRecommendationAdminViewFilterForMentees < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      AdminView.includes(:program).find_each do |admin_view|
        next unless admin_view.is_program_view?
        filter_params = admin_view.filter_params_hash
        selected_value = filter_params.try(:dig, :connection_status, :mentor_recommendations)
        next unless selected_value.present?
        filter_params[:connection_status][:mentor_recommendations] = {mentees: selected_value}
        advanced_options = filter_params.dig(:connection_status, :advanced_options, :mentor_recommendations, :both)
        if advanced_options.present?
          filter_params[:connection_status][:advanced_options][:mentor_recommendations][:mentees] = advanced_options
          filter_params[:connection_status][:advanced_options][:mentor_recommendations].delete(:both)
        end
        admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
        admin_view.save!
      end
    end
  end

  def down
    # do nothing
  end
end
