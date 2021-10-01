class SchedulingAccount < ActiveRecord::Base

  module Status
    ACTIVE   = 1
    INACTIVE = 0
  end

  has_many :calendar_sync_notification_channels

  scope :active, -> { where( status: Status::ACTIVE )}
  scope :inactive, -> { where( status: Status::INACTIVE )}

end