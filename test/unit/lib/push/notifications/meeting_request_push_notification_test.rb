require_relative './../../../../test_helper'

module Push
  module Notifications
    class MeetingRequestPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @non_calendar_meeting = create_meeting(force_non_time_meeting: true)
        @non_calendar_meeting_request = @non_calendar_meeting.meeting_request
        @non_calendar_meeting_request_created_notification = Push::Notifications::MeetingRequestPushNotification.new(@non_calendar_meeting_request, PushNotification::Type::MEETING_REQUEST_CREATED, {})
        @non_calendar_meeting_request_accepted_notification = Push::Notifications::MeetingRequestPushNotification.new(@non_calendar_meeting_request, PushNotification::Type::MEETING_REQUEST_ACCEPTED, {})
        @non_calendar_meeting_request_rejected_notification = Push::Notifications::MeetingRequestPushNotification.new(@non_calendar_meeting_request, PushNotification::Type::MEETING_REQUEST_REJECTED, {})
        @calendar_meeting = create_meeting(force_non_group_meeting: true)
        @calendar_meeting_request = @calendar_meeting.meeting_request
        @calendar_meeting_request_created_notification = Push::Notifications::MeetingRequestPushNotification.new(@calendar_meeting_request, PushNotification::Type::MEETING_REQUEST_CREATED, {})
        @calendar_meeting_request_accepted_notification = Push::Notifications::MeetingRequestPushNotification.new(@calendar_meeting_request, PushNotification::Type::MEETING_REQUEST_ACCEPTED, {})
        @calendar_meeting_request_rejected_notification = Push::Notifications::MeetingRequestPushNotification.new(@calendar_meeting_request, PushNotification::Type::MEETING_REQUEST_REJECTED, {})
        @meeting_request_reminder_notification = Push::Notifications::MeetingRequestPushNotification.new(@non_calendar_meeting_request, PushNotification::Type::MEETING_REQUEST_REMINDER, {})
      end

      def test_recipients
        assert_equal [@non_calendar_meeting_request.mentor], @non_calendar_meeting_request_created_notification.recipients
        assert_equal [@non_calendar_meeting_request.student], @non_calendar_meeting_request_accepted_notification.recipients
        assert_equal [@non_calendar_meeting_request.student], @non_calendar_meeting_request_rejected_notification.recipients
        assert_equal [@non_calendar_meeting_request.mentor], @meeting_request_reminder_notification.recipients
        assert_equal [@non_calendar_meeting_request.mentor], @calendar_meeting_request_created_notification.recipients
        assert_equal [@non_calendar_meeting_request.student], @calendar_meeting_request_accepted_notification.recipients
        assert_equal [@non_calendar_meeting_request.student], @calendar_meeting_request_rejected_notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meeting_requests?filter=me&list=active&push_notification=true&push_type=#{PushNotification::Type::MEETING_REQUEST_CREATED}", @non_calendar_meeting_request_created_notification.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meeting_requests?filter=me&list=active&push_notification=true&push_type=#{PushNotification::Type::MEETING_REQUEST_CREATED}", @calendar_meeting_request_created_notification.redirection_path
        @non_calendar_meeting_request.status = AbstractRequest::Status::ACCEPTED
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meetings/#{@non_calendar_meeting.id}?current_occurrence_time=#{time_in_url(@non_calendar_meeting.first_occurrence)}&push_notification=true&push_type=#{PushNotification::Type::MEETING_REQUEST_ACCEPTED}", @non_calendar_meeting_request_accepted_notification.redirection_path
        hsh = Meeting.recurrent_meetings([@calendar_meeting], get_merged_list: true)[0]
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meetings/#{@calendar_meeting.id}?current_occurrence_time=#{time_in_url(@calendar_meeting.first_occurrence)}&push_notification=true&push_type=#{PushNotification::Type::MEETING_REQUEST_ACCEPTED}", @calendar_meeting_request_accepted_notification.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/users?push_notification=true&push_type=#{PushNotification::Type::MEETING_REQUEST_REJECTED}&src=#{EngagementIndex::Src::BrowseMentors::PUSH_NOTIFICTAION}", @calendar_meeting_request_rejected_notification.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/users?push_notification=true&push_type=#{PushNotification::Type::MEETING_REQUEST_REJECTED}&src=#{EngagementIndex::Src::BrowseMentors::PUSH_NOTIFICTAION}", @non_calendar_meeting_request_rejected_notification.redirection_path
        @non_calendar_meeting_request.status = AbstractRequest::Status::NOT_ANSWERED
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meeting_requests?filter=me&list=active&push_notification=true&push_type=#{PushNotification::Type::MEETING_REQUEST_REMINDER}", @meeting_request_reminder_notification.redirection_path
      end

      def test_generate_message_for
        GlobalizationUtils.run_in_locale(:de) do
          program = @non_calendar_meeting_request.program
          program.term_for(CustomizedTerm::TermType::MEETING_TERM).update_attribute(:articleized_term_downcase, "de_a_meeting")
          program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).update_attribute(:pluralized_term_downcase, "de_mentors")
        end
        assert_equal "mkr_student madankumarrajan has sent you a request for a meeting.", @non_calendar_meeting_request_created_notification.generate_message_for(:en)
        assert_equal "[[ mkr_student madankumarrajan ĥáš šéɳť ýóů á řéƣůéšť ƒóř de_a_meeting. ]]", @non_calendar_meeting_request_created_notification.generate_message_for(:de)
        assert_equal "mkr_student madankumarrajan has sent you a request for a meeting.", @calendar_meeting_request_created_notification.generate_message_for(:en)
        assert_equal "[[ mkr_student madankumarrajan ĥáš šéɳť ýóů á řéƣůéšť ƒóř de_a_meeting. ]]", @calendar_meeting_request_created_notification.generate_message_for(:de)
        assert_equal "Good unique name has accepted your request for a meeting. However Good unique name did not confirm the meeting time and has a message for you.", @non_calendar_meeting_request_accepted_notification.generate_message_for(:en)
        assert_equal "[[ Good unique name ĥáš áččéƿťéď ýóůř řéƣůéšť ƒóř de_a_meeting. [[ Ĥóŵéνéř Good unique name ďíď ɳóť čóɳƒířɱ ťĥé meeting ťíɱé áɳď ĥáš á ɱéššáǧé ƒóř ýóů. ]] ]]", @non_calendar_meeting_request_accepted_notification.generate_message_for(:de)
        assert_equal "Good unique name has accepted your request for a meeting.", @calendar_meeting_request_accepted_notification.generate_message_for(:en)
        assert_equal "[[ Good unique name ĥáš áččéƿťéď ýóůř řéƣůéšť ƒóř de_a_meeting.  ]]", @calendar_meeting_request_accepted_notification.generate_message_for(:de)
        assert_equal "Good unique name did not accept your request for a meeting.", @non_calendar_meeting_request_rejected_notification.generate_message_for(:en)
        assert_equal "[[ Good unique name ďíď ɳóť áččéƿť ýóůř řéƣůéšť ƒóř de_a_meeting. ]]", @non_calendar_meeting_request_rejected_notification.generate_message_for(:de)
        assert_equal "Good unique name did not accept your request for a meeting.", @calendar_meeting_request_rejected_notification.generate_message_for(:en)
        assert_equal "[[ Good unique name ďíď ɳóť áččéƿť ýóůř řéƣůéšť ƒóř de_a_meeting. ]]", @calendar_meeting_request_rejected_notification.generate_message_for(:de)
        @meeting_request_reminder_notification.ref_obj.update_column(:created_at, Time.utc(2016, 6, 10))
        assert_equal "mkr_student madankumarrajan's meeting request is waiting for your response.", @meeting_request_reminder_notification.generate_message_for(:en)
        assert_equal "[[ mkr_student madankumarrajan'š meeting řéƣůéšť íš ŵáíťíɳǧ ƒóř ýóůř řéšƿóɳšé. ]]", @meeting_request_reminder_notification.generate_message_for(:de)
        @calendar_meeting_request_accepted_notification.ref_obj.stubs(:receiver_updated_time?).returns(true)
        assert_equal "Good unique name has accepted your request for a meeting. Good unique name also updated the meeting with a new time that works.", @calendar_meeting_request_accepted_notification.generate_message_for(:en)
        assert_equal "[[ Good unique name ĥáš áččéƿťéď ýóůř řéƣůéšť ƒóř de_a_meeting. [[ Good unique name áłšó ůƿďáťéď ťĥé meeting ŵíťĥ á ɳéŵ ťíɱé ťĥáť ŵóřǩš. ]] ]]", @calendar_meeting_request_accepted_notification.generate_message_for(:de)
      end

      def test_send_push_notification_for_meeting_request_for_non_calendar_meeting_requests
        @non_calendar_meeting_request.program.enable_feature(FeatureName::CALENDAR, false)
        PushNotifier.expects(:push).never
        @non_calendar_meeting_request_created_notification.send_push_notification
        @non_calendar_meeting_request_accepted_notification.send_push_notification
        @non_calendar_meeting_request_rejected_notification.send_push_notification
        @meeting_request_reminder_notification.send_push_notification
        @non_calendar_meeting_request.program.enable_feature(FeatureName::CALENDAR)
        PushNotifier.expects(:push).times(4)
        @non_calendar_meeting_request_created_notification.send_push_notification
        @non_calendar_meeting_request_accepted_notification.send_push_notification
        @non_calendar_meeting_request_rejected_notification.send_push_notification
        @meeting_request_reminder_notification.send_push_notification
        User::Status.all.each do |state|
          @non_calendar_meeting_request.mentor.update_column(:state, state)
          @non_calendar_meeting_request.student.update_column(:state, state)
          if Push::Notifications::MeetingRequestPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).times(4)
          else
            PushNotifier.expects(:push).never
          end
          @non_calendar_meeting_request_created_notification.send_push_notification
          @non_calendar_meeting_request_accepted_notification.send_push_notification
          @non_calendar_meeting_request_rejected_notification.send_push_notification
          @meeting_request_reminder_notification.send_push_notification
        end
      end

      def test_send_push_notification_for_meeting_request_for_calendar_meeting_requests
        @calendar_meeting_request.program.enable_feature(FeatureName::CALENDAR, false)
        PushNotifier.expects(:push).never
        @calendar_meeting_request_created_notification.send_push_notification
        @calendar_meeting_request_accepted_notification.send_push_notification
        @calendar_meeting_request_rejected_notification.send_push_notification
        @calendar_meeting_request.program.enable_feature(FeatureName::CALENDAR)
        PushNotifier.expects(:push).times(3)
        @calendar_meeting_request_created_notification.send_push_notification
        @calendar_meeting_request_accepted_notification.send_push_notification
        @calendar_meeting_request_rejected_notification.send_push_notification
        User::Status.all.each do |state|
          @calendar_meeting_request.mentor.update_column(:state, state)
          @calendar_meeting_request.student.update_column(:state, state)
          if Push::Notifications::MeetingRequestPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).times(3)
          else
            PushNotifier.expects(:push).never
          end
          @calendar_meeting_request_created_notification.send_push_notification
          @calendar_meeting_request_accepted_notification.send_push_notification
          @calendar_meeting_request_rejected_notification.send_push_notification
        end
      end

      def test_custom_checks_for_meeting_reminder
        @non_calendar_meeting_request.program.enable_feature(FeatureName::CALENDAR, false)
        request = @meeting_request_reminder_notification.ref_obj
        request.program.enable_feature(FeatureName::CALENDAR)
        meeting = request.get_meeting
        assert_false meeting.calendar_time_available?
        PushNotifier.expects(:push).once
        @meeting_request_reminder_notification.send_push_notification
        meeting.update_column(:calendar_time_available, true)
        meeting.stubs(:start_time).returns(Time.now + 100.years)
        PushNotifier.expects(:push).once
        @meeting_request_reminder_notification.send_push_notification
        meeting.stubs(:start_time).returns(Time.now - 100.years)
        PushNotifier.expects(:push).never
        @meeting_request_reminder_notification.send_push_notification
        meeting.update_column(:meeting_request_id, nil)
        request.reload
        PushNotifier.expects(:push).once
        @meeting_request_reminder_notification.send_push_notification
      end

      private

      def time_in_url(time)
        time.to_s.gsub("+","%2B").gsub(" ", "+").gsub(":", "%3A")
      end

    end
  end
end
