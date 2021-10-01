class UserNotificationSetting < ActiveRecord::Base
  module SettingNames
    END_USER_COMMUNICATION = 'end_user_communication'
    PROGRAM_MANAGEMENT = 'program_management'
    DIGEST_AND_ALERTS = 'digest_and_alerts'
    def self.all
      [END_USER_COMMUNICATION, PROGRAM_MANAGEMENT, DIGEST_AND_ALERTS]
    end
  end

  belongs_to :user
  validates :user, presence: true
  validates :notification_setting_name, inclusion: {in: SettingNames.all}
end
