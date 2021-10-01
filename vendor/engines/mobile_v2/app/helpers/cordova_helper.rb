module CordovaHelper

  module AndroidAppStoreSource
    MOBILE_PROMPT = "mobile_prompt"
    ANNOUNCEMENT = "announcement"
    OVERVIEW_PAGE = "overview_page"
    EMAIL = "email"
  end

  def cordova_onload_arguments(org)
    args = {}
    args[:pushNotification] = get_push_notification_args
    args[:defaultHosts] = org.hostnames if org.present?
    args[:appUpdate] = {latestAppVersion: get_latest_mobile_app_version, appStoreLink: get_app_download_link }
    args.to_json.html_safe #will be passed as argument to javascript
  end

  def can_register_for_push_notification?
    logged_in_organization? && !working_on_behalf? && (session[:mobile_device].blank? || session[:mobile_device][:refreshed_at] <= (DateTime.now.utc - MobileV2Constants::PUSH_NOTIFICATION_MIN_DURATION.days))
  end

  def get_app_download_icon
    ios_browser? ? "ios_app_icon.jpg" : "android_app_icon.png"
  end

  def get_store_icon_size
    ios_browser? ? "145x45" : "155x50"
  end

  def get_app_download_link(organization = nil, source = nil)
    (ios_browser? || is_ios_app?) ? get_app_store_link : get_google_play_link(organization, source)
  end

  def get_mobile_prompt_image
    ios_browser? ? "mobile_ios.png" : "mobile_android.png"
  end

  def get_app_store_link
    #app store link should be shown for all production environments
    is_non_production_env? ? "itms-services://?action=download-manifest&url=#{APP_CONFIG[:cors_origin].first}/mobile/downloads/ChronusMentor-#{Rails.env}.plist" : APP_CONFIG[:app_store_link]
  end

  def get_google_play_link(organization, source)
    is_non_production_env? ? "#{APP_CONFIG[:cors_origin].first}/mobile/android/downloads/ChronusMentor-#{Rails.env}.apk" : android_app_store_link(organization, source)
  end

  def is_non_production_env?
    Rails.env.development? || Rails.env.test? || Rails.env.staging? || Rails.env.standby?
  end

  def get_latest_mobile_app_version
    path = is_ios_app? ? APP_CONFIG[:app_version_path] : APP_CONFIG[:android_version_path]
    File.read(File.join(Rails.root, path)).strip
  end

  def get_mobile_prompt_event
    ios_browser? ? MobileV2Constants::MobilePrompt::IOS : MobileV2Constants::MobilePrompt::ANDROID
  end

  def get_push_notification_args
    args = {gcmId: APP_CONFIG[:gcm_id]}
    args.merge!({register: true, deviceRegisterPath: register_device_token_session_path}) if can_register_for_push_notification?
    args
  end
end