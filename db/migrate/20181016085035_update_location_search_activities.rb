class UpdateLocationSearchActivities < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      location_question_ids = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).pluck(:id)
      activities = UserSearchActivity.where(profile_question_id: location_question_ids)
      activities.each do |activity|
        location_text = activity.search_text.split(",")[0]
        activity.update_column(:search_text, location_text)
      end
    end
  end

  def down
  end
end
