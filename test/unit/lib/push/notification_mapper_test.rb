require_relative './../../../test_helper'

module Push
  class NotificationMapperTest < ActiveSupport::TestCase

    def setup
      super
      Push::NotificationMapper.instance.responders = nil
    end

    def test_instance
      instance = Push::NotificationMapper.instance
      # should return same instance, as it is a singleton class
      assert_equal instance, Push::NotificationMapper.instance
    end

    def test_register
      assert_nil Push::NotificationMapper.instance.instance_variable_get("@responders")
      Push::NotificationMapper.instance.register([PushNotification::Type::MESSAGE_SENT_NON_ADMIN, PushNotification::Type::MESSAGE_SENT_ADMIN], Push::Notifications::AbstractMessagePushNotification)
      responders = Push::NotificationMapper.instance.instance_variable_get("@responders")
      assert_equal Push::Notifications::AbstractMessagePushNotification, responders[PushNotification::Type::MESSAGE_SENT_NON_ADMIN.to_s]
      assert_equal Push::Notifications::AbstractMessagePushNotification, responders[PushNotification::Type::MESSAGE_SENT_ADMIN.to_s]
      assert_nil responders["random"]
    end

    def test_get_class_for
      assert_equal Push::Notifications::AbstractMessagePushNotification, Push::NotificationMapper.instance.get_class_for(PushNotification::Type::MESSAGE_SENT_NON_ADMIN)
      assert_equal Push::Notifications::AnnouncementPushNotification, Push::NotificationMapper.instance.get_class_for(PushNotification::Type::ANNOUNCEMENT_NEW)
      assert_equal Push::Notifications::MentorRequestPushNotification, Push::NotificationMapper.instance.get_class_for(PushNotification::Type::MENTOR_REQUEST_REJECT)
    end

    def test_get_descendants
      files = Dir[Rails.root.join("lib/push/notifications/*.rb")]
      assert_equal files.size, Push::NotificationMapper.instance.send(:get_descendants).size
    end

    def test_init_responders
      assert_nil Push::NotificationMapper.instance.instance_variable_get("@responders")
      files = Dir[Rails.root.join("lib/push/notifications/*.rb")]

      Push::NotificationMapper.instance.send(:init_responders)
      assert_equal files.size, Push::NotificationMapper.instance.instance_variable_get("@responders").values.uniq.size
    end

  end
end
