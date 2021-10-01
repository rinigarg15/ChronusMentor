module Push
  module Notifications
    class MentorRequestPushNotification < Push::Base

      VALIDATION_CHECKS = {
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }

      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::MENTOR_REQUEST_CREATE,
        PushNotification::Type::MENTOR_REQUEST_ACCEPT,
        PushNotification::Type::MENTOR_REQUEST_REJECT,
        PushNotification::Type::MENTOR_REQUEST_REMINDER
      ]

      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      def recipients
        Array(self.options[:recipients])
      end

      def redirection_path
        case self.notification_type
        when PushNotification::Type::MENTOR_REQUEST_REJECT
          users_url(get_common_url_options.merge({src: EngagementIndex::Src::BrowseMentors::PUSH_NOTIFICTAION}))
        when PushNotification::Type::MENTOR_REQUEST_ACCEPT
          group_url(ref_obj.group, {first_visit: 1}.merge(get_common_url_options))
        when PushNotification::Type::MENTOR_REQUEST_CREATE
          mentor_requests_url({mentor_request_id: ref_obj.id}.merge(get_common_url_options))
        when PushNotification::Type::MENTOR_REQUEST_REMINDER
          mentor_requests_url(get_common_url_options.merge({mentor_request_id: ref_obj.id, list: AbstractRequest::Status::STATUS_TO_SCOPE[AbstractRequest::Status::NOT_ANSWERED]}))
        end
      end

      def generate_message_for(locale)
        key = nil
        message = nil
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = {mentoring: ref_obj.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase}
          case self.notification_type
          when PushNotification::Type::MENTOR_REQUEST_CREATE
            key = "push_notification.mentor_request.create.alert_v1"
            attributes_hash[:mentee_name] = ref_obj.student.name
          when PushNotification::Type::MENTOR_REQUEST_ACCEPT
            key = "push_notification.mentor_request.accept.alert"
            attributes_hash[:mentor_name] = ref_obj.mentor.name
          when PushNotification::Type::MENTOR_REQUEST_REJECT
            key = "push_notification.mentor_request.reject.alert_v1"
            attributes_hash[:rejector_name] = ref_obj.mentor.name
          when PushNotification::Type::MENTOR_REQUEST_REMINDER
            key = "push_notification.mentor_request.reminder.alert"
            attributes_hash[:mentee_name] = ref_obj.student.name(name_only: true)
          end
          message = key.translate(attributes_hash)
        end
        message
      end

    end
  end
end
