module Push
  module Notifications
    class AnnouncementPushNotification < Push::Base

      HANDLED_NOTIFICATIONS = [PushNotification::Type::ANNOUNCEMENT_NEW, PushNotification::Type::ANNOUNCEMENT_UPDATE]
      NOTIFICATION_LEVEL    = PushNotification::Level::PROGRAM

      def recipients
        ref_obj.notification_list
      end

      def redirection_path
        announcement_url(ref_obj, get_common_url_options)
      end

      def generate_message_for(locale)
        key     = nil
        message = nil
        case self.notification_type
        when PushNotification::Type::ANNOUNCEMENT_NEW
          key = "push_notification.announcement.new.alert_v1"
        when PushNotification::Type::ANNOUNCEMENT_UPDATE
          key = "push_notification.announcement.update.alert_v1"
        end
        GlobalizationUtils.run_in_locale(locale) do
          message = key.translate
        end
        message
      end

    end
  end
end
