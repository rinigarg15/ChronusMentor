class RemoveCommonGoalsFeature< ActiveRecord::Migration[4.2]
  def up
    feature = Feature.find_by(name: "common_goals")
    feature.destroy if feature.present?
    RecentActivity.where("ref_obj_type = 'CommonTask'").destroy_all
    PendingNotification.where("ref_obj_type = 'CommonTask'").destroy_all
  end

  def down
    Feature.create!(name: "common_goals")    
  end
end
