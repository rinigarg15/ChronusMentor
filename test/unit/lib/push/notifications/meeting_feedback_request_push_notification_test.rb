require_relative './../../../../test_helper'

module Push
  module Notifications
    class MeetingFeedbackRequestPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @meeting = create_meeting
        @program = @meeting.program
        @member_meeting = @meeting.member_meetings[0]
        @user = @member_meeting.member.user_in_program(@program)
        @current_occurrence_time = @meeting.occurrences[0].start_time
        @meeting_feedback_request_notification = Push::Notifications::MeetingFeedbackRequestPushNotification.new(@member_meeting, PushNotification::Type::MEETING_FEEDBACK_REQUEST, {user_id: @user.id, current_occurrence_time: @current_occurrence_time, content: "Something"})
      end

      def test_recipients
        assert_equal [@user], @meeting_feedback_request_notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/surveys/#{@program.get_meeting_feedback_survey_for_user_in_meeting(@user, @member_meeting.meeting).id}/participate?meeting_occurrence_time=#{@current_occurrence_time.to_s.gsub('+','%2B').gsub(' ','+').gsub(':','%3A')}&member_meeting_id=#{@member_meeting.id}&push_notification=true&push_type=#{PushNotification::Type::MEETING_FEEDBACK_REQUEST}", @meeting_feedback_request_notification.redirection_path
      end

      def test_generate_message_for
        assert_equal "Something", @meeting_feedback_request_notification.generate_message_for(:en)
        assert_equal "Something", @meeting_feedback_request_notification.generate_message_for(:de)
      end

      def test_send_push_notification_for_meeting_push_notifications
        @program.enable_feature(FeatureName::CALENDAR, false)
        PushNotifier.expects(:push).never
        @meeting_feedback_request_notification.send_push_notification
        @program.enable_feature(FeatureName::CALENDAR, true)
        PushNotifier.expects(:push).once
        @meeting_feedback_request_notification.send_push_notification
        User::Status.all.each do |state|
          @user.update_column(:state, state)
          if Push::Notifications::MeetingFeedbackRequestPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @meeting_feedback_request_notification.user.reload
          @meeting_feedback_request_notification.send_push_notification
        end
      end

      def test_get_program_or_organization
        assert_equal @program, @meeting_feedback_request_notification.send(:get_program_or_organization)
      end
    end
  end
end
