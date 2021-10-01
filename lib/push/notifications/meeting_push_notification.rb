module Push
  module Notifications
    class MeetingPushNotification < Push::Base
      include MeetingsHelper

      VALIDATION_CHECKS = {
        check_for_features: [[FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING]],
        user_states: [User::Status::ACTIVE, User::Status::PENDING],
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::MEETING_CREATED,
        PushNotification::Type::MEETING_UPDATED,
        PushNotification::Type::MEETING_REMINDER
      ]
      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      attr_accessor :user, :current_occurrence_time, :updated_by_member

      def initialize(ref_obj, notification_type, options)
        self.user = User.find_by(id: options[:user_id])
        self.updated_by_member = Member.find_by(id: options[:updated_by_member_id])
        self.current_occurrence_time = options[:current_occurrence_time]
        super
      end

      def recipients
        [user].compact
      end

      def redirection_path
        meeting = case notification_type
        when PushNotification::Type::MEETING_CREATED, PushNotification::Type::MEETING_UPDATED
          ref_obj
        when PushNotification::Type::MEETING_REMINDER
          ref_obj.meeting
        end
        if meeting.accepted?
          meeting_url(meeting, get_common_url_options.merge(current_occurrence_time: meeting.first_occurrence))
        else
          member_url(user.member, get_common_url_options.merge(tab: MembersController::ShowTabs::AVAILABILITY, scroll_to: get_meeting_html_id(Meeting.recurrent_meetings([meeting], get_merged_list: true)[0])))
        end
      end

      def generate_message_for(locale)
        program = get_program
        key = "push_notification.meeting."
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = case self.notification_type
          when PushNotification::Type::MEETING_CREATED
            key << "created"
            {customized_meeting_term_articleized: program.term_for(CustomizedTerm::TermType::MEETING_TERM).articleized_term_downcase, meeting_owner_name: ref_obj.owner.name(name_only: true)}
          when PushNotification::Type::MEETING_UPDATED
            key << "updated"
            {customized_meeting_term_articleized: program.term_for(CustomizedTerm::TermType::MEETING_TERM).articleized_term_downcase, meeting_owner_name: self.updated_by_member.try(:name, {:name_only => true})}
          when PushNotification::Type::MEETING_REMINDER
            key << "reminder"
            {meeting_term: program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase, meeting_start_time: DateTime.localize(ref_obj.meeting.start_time.in_time_zone(ref_obj.member.get_valid_time_zone), format: :short_time_small)}
          end
          key.translate(attributes_hash)
        end
      end

      private

      def get_program_or_organization
        case self.notification_type
        when PushNotification::Type::MEETING_REMINDER
          ref_obj.meeting.program
        else
          super
        end
      end

    end
  end
end
