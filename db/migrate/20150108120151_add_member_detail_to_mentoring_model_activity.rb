class AddMemberDetailToMentoringModelActivity< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_activities, :member_id, :integer
    MentoringModel::Activity.reset_column_information
    MentoringModel::Activity.find_each do |activity|
      if activity.connection_membership.present?
        activity.member_id = activity.connection_membership.user.member_id
        activity.save
      else
        activity.destroy
      end
    end
  end
end
