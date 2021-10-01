module Push
  module Notifications
    class ProjectBasedEngagementPushNotification < Push::Base

      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::PBE_PROPOSAL_ACCEPTED,
        PushNotification::Type::PBE_PROPOSAL_REJECTED,
        PushNotification::Type::PBE_PUBLISHED
      ]

      VALIDATION_CHECKS = {
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }

      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      def recipients
        case self.notification_type
        when PushNotification::Type::PBE_PROPOSAL_ACCEPTED, PushNotification::Type::PBE_PROPOSAL_REJECTED
          ref_obj.created_by.present? ? [ref_obj.created_by] : []
        when PushNotification::Type::PBE_PUBLISHED
          ref_obj.members
        end
      end

      def redirection_path
        case self.notification_type
        when PushNotification::Type::PBE_PROPOSAL_ACCEPTED
          profile_group_url(ref_obj, get_common_url_options)
        when PushNotification::Type::PBE_PROPOSAL_REJECTED
          groups_url({show: 'my', tab: Group::Status::REJECTED, view: Group::View::DETAILED}.merge(get_common_url_options))
        when PushNotification::Type::PBE_PUBLISHED
          group_url(ref_obj, get_common_url_options)
        end
      end

      def generate_message_for(locale)
        key = "push_notification.project_based_engagement."
        GlobalizationUtils.run_in_locale(locale) do
          custom_term = ref_obj.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
          attributes_hash = {customized_mentoring_connection_term: custom_term.term_downcase, project_name: ref_obj.name}
          case self.notification_type
          when PushNotification::Type::PBE_PROPOSAL_ACCEPTED
            key << "proposal_accept"
          when PushNotification::Type::PBE_PROPOSAL_REJECTED
            key << "proposal_reject"
            attributes_hash.merge!(customized_mentoring_connections_term: custom_term.pluralized_term_downcase)
          when PushNotification::Type::PBE_PUBLISHED
            key << "published"
          end
          key.translate(attributes_hash)
        end
      end

    end
  end
end
