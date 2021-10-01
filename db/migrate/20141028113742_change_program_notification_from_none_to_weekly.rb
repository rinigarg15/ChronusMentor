class ChangeProgramNotificationFromNoneToWeekly< ActiveRecord::Migration[4.2]
  def up
    # 2 is the notification NONE, which is removed!
    User.where(:notification_setting => 2).update_all(:notification_setting => 3) # previously UserConstants::NotifySetting::WEEKLY_DIGEST
  end

  def down
  end
end
