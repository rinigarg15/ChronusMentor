require_relative './../../test_helper.rb'

class CordovaHelperTest < ActionView::TestCase

  def test_cordova_onload_arguments
    # can_register_for_push_notification = true
    @current_member         = members(:f_admin)
    session[:mobile_device] = nil
    self.expects(:working_on_behalf?).returns(false)
    self.expects(:ios_browser?).at_least(1).returns(true)
    self.expects(:is_ios_app?).at_least(1).returns(true)
    output = JSON.parse cordova_onload_arguments(@current_member.organization)
    expected = {"pushNotification" => {"gcmId" => "12345", "register" => true, "deviceRegisterPath" => register_device_token_session_path}, "defaultHosts" => ["primary."+DEFAULT_HOST_NAME], "appUpdate" => {"latestAppVersion"=>"0.0.1", "appStoreLink"=>"itms-services://?action=download-manifest&url=http://mentor.test.host/mobile/downloads/ChronusMentor-test.plist"}}
    assert_equal expected, output
    # can_register_for_push_notification = false
    self.expects(:working_on_behalf?).returns(true)
    output = JSON.parse cordova_onload_arguments(@current_member.organization)
    expected = {"pushNotification"=>{"gcmId"=>"12345"}, "defaultHosts" => ["primary."+DEFAULT_HOST_NAME], "appUpdate" => {"latestAppVersion"=>"0.0.1", "appStoreLink"=>"itms-services://?action=download-manifest&url=http://mentor.test.host/mobile/downloads/ChronusMentor-test.plist"}}
    assert_equal expected, output
    self.expects(:ios_browser?).at_least(1).returns(false)
    self.expects(:is_ios_app?).at_least(1).returns(false)
    self.expects(:working_on_behalf?).returns(false)
    output = JSON.parse cordova_onload_arguments(@current_member.organization)
    expected = {"pushNotification" => {"gcmId" => "12345", "register" => true, "deviceRegisterPath" => register_device_token_session_path}, "defaultHosts" => ["primary."+DEFAULT_HOST_NAME], "appUpdate" => {"latestAppVersion"=>"1.0.0", "appStoreLink"=>"http://mentor.test.host/mobile/android/downloads/ChronusMentor-test.apk"}}
    assert_equal expected, output
    # can_register_for_push_notification = false
    self.expects(:working_on_behalf?).returns(true)
    output = JSON.parse cordova_onload_arguments(@current_member.organization)
    expected = {"pushNotification"=>{"gcmId"=>"12345"}, "defaultHosts" => ["primary."+DEFAULT_HOST_NAME], "appUpdate" => {"latestAppVersion"=>"1.0.0", "appStoreLink"=>"http://mentor.test.host/mobile/android/downloads/ChronusMentor-test.apk"}}
    assert_equal expected, output
  end

  def test_can_register_for_push_notification
    # valid case with no session[:mobile_device]
    @current_member         = members(:f_admin)
    session[:mobile_device] = nil
    self.expects(:working_on_behalf?).returns(false)
    assert can_register_for_push_notification?

    # valid case with session[:mobile_device][:refreshed_at] >= MobileV2Constants::PUSH_NOTIFICATION_MIN_DURATION
    self.expects(:working_on_behalf?).returns(false)
    session[:mobile_device] = {refreshed_at: (MobileV2Constants::PUSH_NOTIFICATION_MIN_DURATION + 1).days.ago.utc.to_datetime}
    assert can_register_for_push_notification?

    # not logged_in_organization
    @current_member = nil
    assert_false can_register_for_push_notification?

    # working on behalf
    self.expects(:working_on_behalf?).returns(false)
    @current_member = members(:f_admin)
    assert can_register_for_push_notification?
    self.expects(:working_on_behalf?).returns(true)
    assert_false can_register_for_push_notification?

    # session[:mobile_device][:refreshed_at] < MobileV2Constants::PUSH_NOTIFICATION_MIN_DURATION
    self.expects(:working_on_behalf?).returns(false).twice
    assert can_register_for_push_notification?
    session[:mobile_device][:refreshed_at] = DateTime.now.utc
    assert_false can_register_for_push_notification?
  end

  def test_app_store_link
    assert_equal "itms-services://?action=download-manifest&url=http://mentor.test.host/mobile/downloads/ChronusMentor-test.plist", get_app_store_link
  end

  def test_is_non_production_env
    assert is_non_production_env?
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))
    assert_false is_non_production_env?
  end

  def test_google_play_link
    assert_equal "http://mentor.test.host/mobile/android/downloads/ChronusMentor-test.apk", get_google_play_link(programs(:org_primary), "source")
  end

  def test_get_latest_mobile_app_version
    self.expects(:is_ios_app?).returns(true)
    assert_equal "0.0.1", get_latest_mobile_app_version
    self.expects(:is_ios_app?).returns(false)
    assert_equal "1.0.0", get_latest_mobile_app_version
  end

  def test_get_app_download_icon
    self.expects(:ios_browser?).returns(false)
    assert_equal "android_app_icon.png", get_app_download_icon
    self.expects(:ios_browser?).returns(true)
    assert_equal "ios_app_icon.jpg", get_app_download_icon
  end

  def test_get_app_download_link
    self.expects(:ios_browser?).returns(true)
    assert_equal "itms-services://?action=download-manifest&url=http://mentor.test.host/mobile/downloads/ChronusMentor-test.plist", get_app_download_link
    self.expects(:ios_browser?).returns(false)
    self.expects(:is_ios_app?).returns(true)
    assert_equal "itms-services://?action=download-manifest&url=http://mentor.test.host/mobile/downloads/ChronusMentor-test.plist", get_app_download_link
    self.expects(:ios_browser?).returns(false)
    self.expects(:is_ios_app?).returns(false)
    assert_equal "http://mentor.test.host/mobile/android/downloads/ChronusMentor-test.apk", get_app_download_link
  end

  def test_get_mobile_prompt_event
    self.expects(:ios_browser?).returns(true)
    assert_equal 1, get_mobile_prompt_event
    self.expects(:ios_browser?).returns(false)
    assert_equal 2, get_mobile_prompt_event
  end

  def test_get_push_notification_args
    # can_register_for_push_notification = true
    @current_member         = members(:f_admin)
    session[:mobile_device] = nil
    self.expects(:working_on_behalf?).returns(false)
    expected = {:gcmId => "12345", :register => true, :deviceRegisterPath => register_device_token_session_path}
    assert_equal expected, get_push_notification_args
    # can_register_for_push_notification = false
    self.expects(:working_on_behalf?).returns(true)
    expected = {:gcmId => "12345"}
    assert_equal expected, get_push_notification_args
  end

  def test_get_store_icon_size
    self.expects(:ios_browser?).returns(true)
    assert_equal "145x45", get_store_icon_size
    self.expects(:ios_browser?).returns(false)
    assert_equal "155x50", get_store_icon_size
  end

  def test_get_mobile_prompt_image
    self.expects(:ios_browser?).returns(true)
    assert_equal "mobile_ios.png", get_mobile_prompt_image
    self.expects(:ios_browser?).returns(false)
    assert_equal "mobile_android.png", get_mobile_prompt_image
  end

  private

  def logged_in_organization?
    !!current_member
  end

end
