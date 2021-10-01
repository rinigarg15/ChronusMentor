# == Schema Information
#
# Table name: notification_settings
#
#  id                    :integer          not null, primary key
#  program_id            :integer
#  messages_notification :integer          default(0)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#

class NotificationSetting < ActiveRecord::Base
  belongs_to_program

  validates :program_id, :presence => true, :uniqueness => true
  validates_inclusion_of :messages_notification, in: UserConstants::DigestV2Setting::ProgramUpdates.all_db_valid
end
