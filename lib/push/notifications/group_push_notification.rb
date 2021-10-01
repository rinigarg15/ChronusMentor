module Push
  module Notifications
    class GroupPushNotification < Push::Base

      VALIDATION_CHECKS = {
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::GROUP_MEMBER_ADDED,
        PushNotification::Type::GROUP_INACTIVITY
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
        group_url(ref_obj, get_common_url_options)
      end

      def generate_message_for(locale)
        program = get_program
        key = "push_notification.group."
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = case self.notification_type
          when PushNotification::Type::GROUP_MEMBER_ADDED
            key << "member_added"
            {role_name_articleized: program.term_for(CustomizedTerm::TermType::ROLE_TERM, ref_obj.membership_of(user).role.name).articleized_term_downcase, group_name: ref_obj.name.truncate(COMMON_TRUNCATE_LENGTH)}
          when PushNotification::Type::GROUP_INACTIVITY
            key << "member_inactive"
            {}
          end
          key.translate(attributes_hash)
        end
      end

    end
  end
end
