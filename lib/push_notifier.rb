class PushNotifier
  DEFAULT_SOUND = "sosumi.aiff"
  DEVELOPMENT_CERT_ENVS = ["development"]
  GCM_TIMEOUT = 300
  GCM_TITLE = "Chronus"

  attr_reader :member, :houston_client, :gcm_client

  def initialize(member)
    @member = member
    ## This can be done at the class level also, but going with the object level, as the connection may be timed out by APN
    @houston_client = setup_ios_client
    @gcm_client = setup_android_client
  end

  def notify(options, notification_obj)
    notifications = []
    notification = @member.push_notifications.create!(notification_params: options, ref_obj_id: notification_obj.ref_obj.id, ref_obj_type: notification_obj.ref_obj.class.name, notification_type: notification_obj.notification_type)

    alert_message = notification_obj.generate_message_for(Language.for_member(@member, notification_obj.get_program_for_locale))
    self.notify_ios_devices(alert_message, options)
    self.notify_android_devices(alert_message, options)
  end

  def notify_ios_devices(alert_message, options)
    notifications = []
    ## TODO: See if we can use apns feedback service to remove the device tokens, not sure if removing the device token is correct !!
    @member.mobile_devices.ios_devices.with_device.each do |mobile_device|
      begin
        notifications << Houston::Notification.new({
          device: mobile_device.device_token, alert: alert_message, sound: DEFAULT_SOUND
        }.merge(options))
      rescue => exception
        ## TODO: Not focussing on resending on failure as push notification might not make sense after some time!
        Airbrake.notify("Notification for MemberID##{@member.id} with #{mobile_device.device_token} failed")
      end  
    end
    @houston_client.push(notifications)
    JobLog.log_info(self.class.prepare_log_data(notifications))
  end
  
  def notify_android_devices(alert_message, options)
    device_tokens = @member.mobile_devices.android_devices.with_device.pluck(:device_token)
    if device_tokens.present?
      gcm_options = {data: {message: alert_message, title: GCM_TITLE, notId: rand(2**31)}.merge(options)}
      response = JSON.parse(@gcm_client.send(device_tokens, gcm_options)[:body])
      JobLog.log_info("Member ID - #{@member.id}, Notifications Delivered - #{response["success"]}, Notifications Failed - #{response["failure"]}")
    end
  end

  class << self
    def push(member, options, notification_obj)
      return unless APP_CONFIG[:push_enabled]
      PushNotifier.new(member).notify(options, notification_obj)
    end

    def prepare_log_data(notifications)
      sent_size, unsent_size = notifications.partition{|notification| notification.sent? }.collect(&:size)
      content = []
      content << notification_text(sent_size) unless sent_size.zero?
      content << notification_text(unsent_size) unless unsent_size.zero?
      content.join(", ")
    end

    def notification_text(content_size)
      "#{content_size} #{"notification".pluralize(content_size)} delivered"
    end
  end

private

  def setup_ios_client
    client = DEVELOPMENT_CERT_ENVS.include?(Rails.env) ? Houston::Client.development : Houston::Client.production
    # APN key (a .pem file) is encoded using Base64.strict_encode64(certificate.pem)
    # It is pushed to S3 using command line using the script app_secure_config
    client.certificate = Base64.decode64(APP_CONFIG[:apn_key])
    client
  end

  def setup_android_client
    GCM.new(APP_CONFIG[:gcm_server_key], {timeout: GCM_TIMEOUT})
  end
end