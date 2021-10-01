module Push
  module Notifications
    class ProgramEventPushNotification < Push::Base

      VALIDATION_CHECKS = {
        check_for_features: [FeatureName::PROGRAM_EVENTS],
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::PROGRAM_EVENT_CREATED,
        PushNotification::Type::PROGRAM_EVENT_REMINDER
      ]
      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      attr_accessor :user

      def initialize(ref_obj, notification_type, options)
        self.user = User.find_by(id: options[:user_id])
        super
      end

      def recipients
        [user].compact
      end

      def redirection_path
        program_event_url(ref_obj, get_common_url_options)
      end

      def generate_message_for(locale)
        program = ref_obj.program
        key = "push_notification.program_event."
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = case self.notification_type
          when PushNotification::Type::PROGRAM_EVENT_CREATED
            key << "created"
            {program_event_owner_name: ref_obj.user.name(:name_only => true), program_or_subprogram_name: program.name}
          when PushNotification::Type::PROGRAM_EVENT_REMINDER
            key << (ref_obj.location.present? ? "reminder_with_location" : "reminder")
            {program_event_title: ref_obj.title.truncate(COMMON_TRUNCATE_LENGTH), event_location: ref_obj.location.truncate(COMMON_TRUNCATE_LENGTH)}
          end
          key.translate(attributes_hash)
        end
      end

    end
  end
end
