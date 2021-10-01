module Push
  module Notifications
    class MeetingFeedbackRequestPushNotification < Push::Base

      VALIDATION_CHECKS = {
        check_for_features: [FeatureName::CALENDAR],
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::MEETING_FEEDBACK_REQUEST
      ]
      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      attr_accessor :user, :current_occurrence_time, :content

      def initialize(ref_obj, notification_type, options)
        self.user = User.find_by(id: options[:user_id])
        self.current_occurrence_time = options[:current_occurrence_time]
        self.content = options[:content]
        super
      end

      def recipients
        [user].compact
      end

      def redirection_path
        program = get_program
        feedback_survey = program.get_meeting_feedback_survey_for_user_in_meeting(self.user, ref_obj.meeting)
        participate_survey_url(feedback_survey, get_common_url_options.merge(member_meeting_id: ref_obj.id, meeting_occurrence_time: current_occurrence_time))
      end

      def generate_message_for(locale)
        self.content
      end

      private

      def get_program_or_organization
        ref_obj.meeting.program
      end

    end
  end
end
