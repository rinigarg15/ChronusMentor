module Push
  module Notifications
    class ProjectRequestPushNotification < Push::Base

      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT,
        PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT
      ]

      VALIDATION_CHECKS = {
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }

      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      def recipients
        [self.ref_obj.sender]
      end

      def redirection_path
        case self.notification_type
        when PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT
          profile_group_url(ref_obj.group, get_common_url_options)
        when PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT
          find_new_groups_url(get_common_url_options)
        end
      end

      def generate_message_for(locale)
        key = "push_notification.project_request."
        GlobalizationUtils.run_in_locale(locale) do
          case self.notification_type
          when PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT
            key << "accepted"
            attributes_hash = {project_name: ref_obj.group.name}
          when PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT
            key << "rejected"
            custom_term = ref_obj.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
            attributes_hash = {
              customized_mentoring_connection_term: custom_term.term_downcase,
              customized_mentoring_connections_term: custom_term.pluralized_term_downcase
            }
          end
          key.translate(attributes_hash)
        end
      end

    end
  end
end