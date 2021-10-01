require_relative './../test_helper.rb'

class MobileDeviceTest < ActiveSupport::TestCase
  def test_belongs_to_member
    member = members(:f_student)
    mobile_device = member.set_mobile_access_tokens!("Skyler!!")
    assert_equal member, mobile_device.member
  end

  def test_scope
    member = members(:f_student)
    MobileDevice.destroy_all
    ios_device     = MobileDevice.create!(member: member, mobile_auth_token: "test", device_token: "happy", platform: MobileDevice::Platform::IOS)
    android_device = MobileDevice.create!(member: member, mobile_auth_token: "test", device_token: "happy", platform: MobileDevice::Platform::ANDROID)
    assert_equal [android_device], member.mobile_devices.android_devices
    assert_equal [ios_device], member.mobile_devices.ios_devices
  end

  def test_validations
    member = members(:f_student)
    mobile_device = MobileDevice.new
    assert_false mobile_device.valid?
    assert_equal ["can't be blank"], mobile_device.errors[:member]
    assert_equal ["can't be blank"], mobile_device.errors[:mobile_auth_token]
    assert_equal ["is not included in the list"], mobile_device.errors[:platform]
    mobile_device = MobileDevice.new
    mobile_device.member = member
    assert_false mobile_device.valid?
    assert_equal [], mobile_device.errors[:member]
    assert_equal ["can't be blank"], mobile_device.errors[:mobile_auth_token]
    assert_equal ["is not included in the list"], mobile_device.errors[:platform]
    mobile_device.mobile_auth_token = "Carrre Mathison"
    assert_false mobile_device.valid?
    assert_equal [], mobile_device.errors[:member]
    assert_equal [], mobile_device.errors[:mobile_auth_token]
    assert_equal ["is not included in the list"], mobile_device.errors[:platform]
    mobile_device.platform = MobileDevice::Platform::IOS
    assert mobile_device.valid?
  end

  def test_scope_with_device
    member = members(:f_student)
    MobileDevice.destroy_all
    MobileDevice.create!(member: member, mobile_auth_token: "susan123", device_token: "happy", platform: MobileDevice::Platform::IOS)
    MobileDevice.create!(member: member, mobile_auth_token: "joffery123", platform: MobileDevice::Platform::ANDROID)
    assert_equal 2, MobileDevice.count
    assert_equal 1, MobileDevice.with_device.size
    assert_equal ["happy", nil], MobileDevice.all.collect(&:device_token)
    assert_equal ["happy"], MobileDevice.with_device.collect(&:device_token)
  end

  def test_handle_device_token_before_save
    member_1 = members(:f_student)
    member_2 = members(:f_mentor)
    MobileDevice.destroy_all

    MobileDevice.create!(member: member_1, mobile_auth_token: "susan123", device_token: "happy", platform: MobileDevice::Platform::IOS)
    assert_equal 1, MobileDevice.count

    MobileDevice.create!(member: member_2, mobile_auth_token: "joffery123", device_token: "angry", platform: MobileDevice::Platform::IOS)
    assert_equal 2, MobileDevice.count

    assert_no_difference "MobileDevice.count" do
      MobileDevice.create!(member: member_2, mobile_auth_token: "snow123", device_token: "happy", platform: MobileDevice::Platform::IOS)
    end
    assert_equal [], member_1.reload.mobile_devices
    assert_equal 2, member_2.reload.mobile_devices.size

    assert_no_difference "MobileDevice.count" do
      MobileDevice.create!(member: member_1, mobile_auth_token: "arya123", device_token: "angry", platform: MobileDevice::Platform::IOS)
    end
    assert_equal 1, member_1.reload.mobile_devices.size
    assert_equal 1, member_2.reload.mobile_devices.size

    # Same token can be present in different platforms
    assert_difference "MobileDevice.count", 1 do
      MobileDevice.create!(member: member_1, mobile_auth_token: "android-arya123", device_token: "angry", platform: MobileDevice::Platform::ANDROID)
    end
    assert_equal 2, member_1.reload.mobile_devices.size
    assert_equal 1, member_2.reload.mobile_devices.size

    device = nil
    assert_difference 'MobileDevice.count', 1 do
      device = MobileDevice.create!(member: member_1, mobile_auth_token: "arya1234", platform: MobileDevice::Platform::IOS)
    end
    assert_equal ['arya123', 'arya1234'], member_1.reload.mobile_devices.ios_devices.collect(&:mobile_auth_token)
    assert_equal ['android-arya123'], member_1.reload.mobile_devices.android_devices.collect(&:mobile_auth_token)
    member_1.mobile_devices.android_devices.destroy_all
    # update case
    device.update_attributes!(member_id: member_2.id, device_token: "angry")
    assert_equal [], member_1.reload.mobile_devices.collect(&:mobile_auth_token)
    assert_equal ['snow123', 'arya1234'], member_2.reload.mobile_devices.collect(&:mobile_auth_token)
  end

  def test_set_mobile_auth_cookie
    cookie = setup_cookie
    MobileDevice.destroy_all
    member = members(:f_student)
    device = MobileDevice.create!(member: member, mobile_auth_token: "test", device_token: "happy", platform: MobileDevice::Platform::IOS)
    # without refresh
    device.set_mobile_auth_cookie(cookie)
    assert_equal "test", cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert "test" != cookie[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    # with refresh
    MobileDevice.expects(:make_token).returns("abc")
    assert_difference "MobileDevice.count", 1 do
      member.mobile_devices.new(platform: MobileDevice::Platform::ANDROID).set_mobile_auth_cookie(cookie, true)
    end
    assert_equal "abc", member.mobile_devices.last.mobile_auth_token
    assert_equal "abc", cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert "abc" != cookie[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
  end

  def test_refresh_mobile_auth_token
    MobileDevice.expects(:make_token).returns("abc")
    member = members(:f_student)
    MobileDevice.destroy_all
    device = MobileDevice.create!(member: member, mobile_auth_token: "test", device_token: "happy", platform: MobileDevice::Platform::IOS)
    assert_equal 'test', device.mobile_auth_token
    # refresh
    device.refresh_mobile_auth_token
    assert_equal 'abc', device.mobile_auth_token
  end

  def test_remove_device
    cookie = setup_cookie
    member = members(:f_student)
    MobileDevice.destroy_all
    ios_device = MobileDevice.create!(member: member, mobile_auth_token: "test", device_token: "happy", platform: MobileDevice::Platform::IOS)
    android_device = MobileDevice.create!(member: member, mobile_auth_token: "test", device_token: "happy", platform: MobileDevice::Platform::ANDROID)
    # Both IOS and android device with same token present, should delete only IOS
    assert_equal [android_device], member.mobile_devices.android_devices
    assert_equal [ios_device], member.mobile_devices.ios_devices
    cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = "test"
    assert_difference "MobileDevice.count", -1 do
      MobileDevice.remove_device(cookie, MobileDevice::Platform::IOS)
    end
    assert_nil cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert_equal [android_device], member.mobile_devices.android_devices
    assert member.mobile_devices.ios_devices.blank?

    # no valid IOS device
    cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = "test"
    assert_no_difference "MobileDevice.count" do
      MobileDevice.remove_device(cookie, MobileDevice::Platform::IOS)
    end
    assert_nil cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert_equal [android_device], member.mobile_devices.android_devices
    assert member.mobile_devices.ios_devices.blank?

    # Android device present
    cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = "test"
    assert_difference "MobileDevice.count", -1 do
      MobileDevice.remove_device(cookie, MobileDevice::Platform::ANDROID)
    end
    assert_nil cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert member.mobile_devices.ios_devices.blank?
    assert member.mobile_devices.android_devices.blank?
  end
end