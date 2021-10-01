class RemoveOrganizationAssociationFromNotificationSetting< ActiveRecord::Migration[4.2]
  def up
    organization_ids = Organization.pluck(:id)
    NotificationSetting.where(:program_id => organization_ids).destroy_all
  end

  def down
  end
end
