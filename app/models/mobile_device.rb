# == Schema Information
#
# Table name: mobile_devices
#
#  id                :integer          not null, primary key
#  member_id         :integer
#  device_token      :text(65535)
#  created_at        :datetime
#  updated_at        :datetime
#  mobile_auth_token :text(65535)
#  badge_count       :integer          default(0)
#  platform          :integer
#

# MobileDevice: Scenarios
# 1. mobile_auth_token must be always present which is required to access/authenticate the client side mobile app.
# 2. we are using secure_digest for creating the mobile_auth_token which will return an unique token every time.
#    -: secure_digest(Time.now, (1..10).map{ rand.to_s })
# 3. device_token will be present in the case of webview(accessed as app) but not in the browsers view(accessed through web/mobile browsers).
#    and current use of device token is only for sending push notifications.
# 4. device_token should be unique if present in the table. This constraint is required to handle the following scenario.
#    -: Member A installs mobile app and login in our app. ( we now have device token for the Member A)
#    -: Then Member A uninstalls the mobile app. ( device token won't be deleted in server side)
#    -: Now either Member A or any other Member installs the app in the same device and login
#       then it will create problem because of either reduntant device token for same member or
#       same device token for two different member but only last login member is using the mobile app.
#       This can cause push notifcations with inconsistent data on that device.
#    -: To handle this we will destroy all the previous records with same device token before creating a new record.

class MobileDevice < ActiveRecord::Base
  include Authentication

  module Platform
    IOS     = 100
    ANDROID = 200
    ALL     = [IOS, ANDROID]
  end

  belongs_to :member
  validates :member, :mobile_auth_token, presence: true
  validates :platform, inclusion: Platform::ALL
  scope :with_device, -> { where("device_token IS NOT NULL")}
  scope :android_devices, -> { where(platform: Platform::ANDROID) }
  scope :ios_devices, -> { where(platform: Platform::IOS)}

  before_save :handle_device_token

  def set_mobile_auth_cookie(cookies, refresh = false)
    refresh_mobile_auth_token if refresh
    cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = {value: self.mobile_auth_token, expires: MobileV2Constants::COOKIE_EXPIRY.days.from_now}
  end

  def refresh_mobile_auth_token
    self.update_attributes!(mobile_auth_token: self.class.make_token)
    self.mobile_auth_token
  end

  def self.remove_device(cookies, platform)
    self.where(platform: platform, mobile_auth_token: cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]).destroy_all
    cookies.delete(MobileV2Constants::MOBILE_V2_AUTH_TOKEN)
  end

  private

  def handle_device_token
    if self.device_token.present?
      # To handle the uniqueness of device token we need to destroy previous record with same device token.
      invalid_devices = MobileDevice.where(device_token: self.device_token, platform: self.platform)
      invalid_devices = invalid_devices.where("id != :self_id", self_id: self.id) unless self.new_record?
      invalid_devices.destroy_all
    end
  end
end
