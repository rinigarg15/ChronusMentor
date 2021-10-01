module Push
  module Notifications
    class AbstractMessagePushNotification < Push::Base

      HANDLED_NOTIFICATIONS = [PushNotification::Type::MESSAGE_SENT_NON_ADMIN, PushNotification::Type::MESSAGE_SENT_ADMIN]

      def recipients
        return self.ref_obj.receivers
      end

      def redirection_path
        AbstractMessagesHelper.get_message_url_for_notification(self.ref_obj, get_program_or_organization, get_common_url_options.except(:subdomain, :root))
      end

      def generate_message_for(locale)
        key = "push_notification.message.alert"
        message = nil
        GlobalizationUtils.run_in_locale(locale) do
          case self.notification_type
          when PushNotification::Type::MESSAGE_SENT_NON_ADMIN
            attributes_hash = { sender_name: ref_obj.sender.name }
          when PushNotification::Type::MESSAGE_SENT_ADMIN
            attributes_hash = { sender_name: ref_obj.program.get_organization.admin_custom_term.term }
          end
          message = key.translate(attributes_hash)
        end
        message
      end

      def get_program_for_locale
        ref_obj.program if ref_obj.for_program?
      end

      private

      def get_program_or_organization
        ref_obj.for_program? ? ref_obj.program.organization : ref_obj.program
      end
    end
  end
end
