module Push
  module Notifications
    class MeetingRequestPushNotification < Push::Base
      include ApplicationHelper
      include MeetingsHelper

      VALIDATION_CHECKS = {
        check_for_features: [FeatureName::CALENDAR],
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::MEETING_REQUEST_CREATED,
        PushNotification::Type::MEETING_REQUEST_ACCEPTED,
        PushNotification::Type::MEETING_REQUEST_REJECTED,
        PushNotification::Type::MEETING_REQUEST_REMINDER
      ]
      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM
      # Push notifications enabled states are added here
      ENABLED_NOTIFICATIONS_MAPPER = {
        AbstractRequest::Status::ACCEPTED => PushNotification::Type::MEETING_REQUEST_ACCEPTED,
        AbstractRequest::Status::REJECTED => PushNotification::Type::MEETING_REQUEST_REJECTED
      }

      def recipients
        case self.notification_type
        when PushNotification::Type::MEETING_REQUEST_CREATED, PushNotification::Type::MEETING_REQUEST_REMINDER
          [ref_obj.mentor]
        when PushNotification::Type::MEETING_REQUEST_ACCEPTED, PushNotification::Type::MEETING_REQUEST_REJECTED
          [ref_obj.student]
        end
      end

      def redirection_path
        case self.notification_type
        when PushNotification::Type::MEETING_REQUEST_CREATED, PushNotification::Type::MEETING_REQUEST_REMINDER
          meeting_requests_url(get_common_url_options.merge({filter: AbstractRequest::Filter::TO_ME, list: AbstractRequest::Status::STATUS_TO_SCOPE[AbstractRequest::Status::NOT_ANSWERED]}))
        when PushNotification::Type::MEETING_REQUEST_ACCEPTED
          meeting_url(ref_obj.meeting, get_common_url_options.merge(current_occurrence_time: ref_obj.meeting.first_occurrence))
        when PushNotification::Type::MEETING_REQUEST_REJECTED
          users_url(get_common_url_options.merge({src: EngagementIndex::Src::BrowseMentors::PUSH_NOTIFICTAION}))
        end
      end

      def generate_message_for(locale)
        program = ref_obj.program
        key = "push_notification.meeting_request."
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = case self.notification_type
          when PushNotification::Type::MEETING_REQUEST_CREATED
            key << "created"
            {requester_name: ref_obj.student.name(name_only: true), customized_meeting_term_articleized: program.term_for(CustomizedTerm::TermType::MEETING_TERM).articleized_term_downcase}
          when PushNotification::Type::MEETING_REQUEST_ACCEPTED
            key << "accepted_v1"
            meeting = ref_obj.meeting
            contextual_message = if meeting.calendar_time_available?
              ref_obj.receiver_updated_time? ? "push_notification.meeting_request.contextual_message.calendar".translate(name: ref_obj.mentor.name(name_only: true), meeting: program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase) : ""
            else
              "push_notification.meeting_request.contextual_message.non_calendar".translate(name: ref_obj.mentor.name(name_only: true), meeting: program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase)
            end
            {mentor_name: ref_obj.mentor.name(name_only: true), customized_meeting_term_articleized: program.term_for(CustomizedTerm::TermType::MEETING_TERM).articleized_term_downcase, contextual_message: contextual_message}
          when PushNotification::Type::MEETING_REQUEST_REJECTED
            key << "rejected"
            {mentor_name: ref_obj.mentor.name(name_only: true), customized_meeting_term_articleized: program.term_for(CustomizedTerm::TermType::MEETING_TERM).articleized_term_downcase}
          when PushNotification::Type::MEETING_REQUEST_REMINDER
            key << "reminder"
            {mentee_name: ref_obj.student.name(name_only: true), meeting_term: program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase}
          end
          key.translate(attributes_hash).strip
        end
      end

      private

      def custom_check?(user_or_member)
        case self.notification_type
        when PushNotification::Type::MEETING_REQUEST_REMINDER
          meeting = self.ref_obj.get_meeting
          (meeting.present? && ((meeting.calendar_time_available? && meeting.start_time > DateTime.now.utc) || !meeting.calendar_time_available?)) || meeting.nil?
        else
          true
        end
      end

    end
  end
end
