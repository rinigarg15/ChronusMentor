require_relative './../../../../test_helper'

module Push
  module Notifications
    class AnnouncementPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @notification = Push::Notifications::AnnouncementPushNotification.new(Announcement.first, PushNotification::Type::ANNOUNCEMENT_NEW, {})
      end

      def test_recipients
        assert_equal Announcement.first.notification_list, @notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/announcements/#{@notification.ref_obj.id}?push_notification=true&push_type=#{PushNotification::Type::ANNOUNCEMENT_NEW}", @notification.redirection_path
      end

      def test_generate_message_for
        french_title = "French title"
        announcement = create_announcement(:title => "English title", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
        GlobalizationUtils.run_in_locale(:"de") do
          announcement.update_attribute(:title, "French title")
        end

        @notification.ref_obj = announcement
        assert_equal "push_notification.announcement.new.alert_v1".translate(title: "English title", locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.announcement.new.alert_v1".translate(title: french_title, locale: "de"), @notification.generate_message_for("de")

        @notification.notification_type = PushNotification::Type::ANNOUNCEMENT_UPDATE
        assert_equal "push_notification.announcement.update.alert_v1".translate(title: "English title", locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.announcement.update.alert_v1".translate(title: french_title, locale: "de"), @notification.generate_message_for("de")
      end

      def test_send_push_notification
        PushNotifier.expects(:push).times(Announcement.first.notification_list.size)
        @notification.send_push_notification

        @notification.expects(:recipients).returns([Announcement.first.notification_list.first])
        PushNotifier.expects(:push).with(Announcement.first.notification_list.first.member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/announcements/#{@notification.ref_obj.id}?push_notification=true&push_type=#{PushNotification::Type::ANNOUNCEMENT_NEW}"}, @notification).once
        @notification.send_push_notification
      end

    end
  end
end
