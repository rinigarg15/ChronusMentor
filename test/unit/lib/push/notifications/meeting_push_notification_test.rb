require_relative './../../../../test_helper'

module Push
  module Notifications
    class MeetingPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @meeting = create_meeting
        @program = @meeting.program
        @user = @meeting.guests_users[0]
        @member_meeting = @meeting.member_meetings[0]
        @reminder_user = @member_meeting.member.user_in_program(@program)
        @meeting_created_notification = Push::Notifications::MeetingPushNotification.new(@meeting, PushNotification::Type::MEETING_CREATED, {user_id: @user.id})
        @meeting_updated_notification = Push::Notifications::MeetingPushNotification.new(@meeting, PushNotification::Type::MEETING_UPDATED, {user_id: @user.id, updated_by_member_id: @user.member.id})
        @meeting_reminder_notification = Push::Notifications::MeetingPushNotification.new(@member_meeting, PushNotification::Type::MEETING_REMINDER, {user_id: @reminder_user.id, current_occurrence_time: @meeting.occurrences[0].start_time})
      end

      def test_recipients
        assert_equal [@user], @meeting_created_notification.recipients
        assert_equal [@user], @meeting_updated_notification.recipients
        assert_equal [@reminder_user], @meeting_reminder_notification.recipients
      end

      def test_redirection_path
        hsh = Meeting.recurrent_meetings([@meeting], get_merged_list: true)[0]
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meetings/#{@meeting.id}?current_occurrence_time=#{@meeting.first_occurrence.to_s.gsub("+","%2B").gsub(" ", "+").gsub(":", "%3A")}&push_notification=true&push_type=#{PushNotification::Type::MEETING_CREATED}", @meeting_created_notification.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meetings/#{@meeting.id}?current_occurrence_time=#{@meeting.first_occurrence.to_s.gsub("+","%2B").gsub(" ", "+").gsub(":", "%3A")}&push_notification=true&push_type=#{PushNotification::Type::MEETING_UPDATED}", @meeting_updated_notification.redirection_path
        hsh = Meeting.recurrent_meetings([@member_meeting.meeting], get_merged_list: true)[0]
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meetings/#{@meeting.id}?current_occurrence_time=#{@meeting.first_occurrence.to_s.gsub("+","%2B").gsub(" ", "+").gsub(":", "%3A")}&push_notification=true&push_type=#{PushNotification::Type::MEETING_REMINDER}", @meeting_reminder_notification.redirection_path
      end

      def test_generate_message_for
        GlobalizationUtils.run_in_locale(:de) do
          @program.term_for(CustomizedTerm::TermType::MEETING_TERM).update_attribute(:articleized_term_downcase, "de_a_meeting")
        end

        assert_equal @user.member, @meeting_updated_notification.updated_by_member
        assert_equal "Good unique name invited you for a meeting.", @meeting_created_notification.generate_message_for(:en)
        assert_equal "[[ Good unique name íɳνíťéď ýóů ƒóř de_a_meeting. ]]", @meeting_created_notification.generate_message_for(:de)
        assert_equal "#{@user.name(name_only: true)} updated a meeting.", @meeting_updated_notification.generate_message_for(:en)
        assert_equal "[[ #{@user.name(name_only: true)} ůƿďáťéď de_a_meeting. ]]", @meeting_updated_notification.generate_message_for(:de)
        assert_equal "Your meeting is starting at #{DateTime.localize(@meeting_reminder_notification.ref_obj.meeting.start_time.in_time_zone(@meeting_reminder_notification.ref_obj.member.get_valid_time_zone), format: :short_time_small)}.", @meeting_reminder_notification.generate_message_for(:en)
        assert_equal "[[ Ýóůř meeting íš šťářťíɳǧ áť #{GlobalizationUtils.run_in_locale(:de){ DateTime.localize(@meeting_reminder_notification.ref_obj.meeting.start_time.in_time_zone(@meeting_reminder_notification.ref_obj.member.get_valid_time_zone), format: :short_time_small)}}. ]]", @meeting_reminder_notification.generate_message_for(:de)
      end

      def test_send_push_notification_for_meeting_push_notifications
        @member_meeting.stubs(:can_send_reminder?).returns(true)
        @program.enable_feature(FeatureName::CALENDAR, false)
        @program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
        PushNotifier.expects(:push).never
        @meeting_created_notification.send_push_notification
        @meeting_updated_notification.send_push_notification
        @meeting_reminder_notification.send_push_notification
        @program.enable_feature(FeatureName::CALENDAR, true)
        @program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
        PushNotifier.expects(:push).times(3)
        @meeting_created_notification.send_push_notification
        @meeting_updated_notification.send_push_notification
        @meeting_reminder_notification.send_push_notification
        @program.enable_feature(FeatureName::CALENDAR, false)
        @program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, true)
        PushNotifier.expects(:push).times(3)
        @meeting_created_notification.send_push_notification
        @meeting_updated_notification.send_push_notification
        @meeting_reminder_notification.send_push_notification
        User::Status.all.each do |state|
          @user.update_column(:state, state)
          @reminder_user.update_column(:state, state)
          if Push::Notifications::MeetingPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).times(3)
          else
            PushNotifier.expects(:push).never
          end
          @meeting_created_notification.user.reload
          @meeting_created_notification.send_push_notification
          @meeting_updated_notification.user.reload
          @meeting_updated_notification.send_push_notification
          @meeting_reminder_notification.user.reload
          @meeting_reminder_notification.send_push_notification
        end
      end

      def test_get_program_or_organization
        assert_equal @program, @meeting_created_notification.send(:get_program_or_organization)
        assert_equal @program, @meeting_updated_notification.send(:get_program_or_organization)
        assert_equal @program, @meeting_reminder_notification.send(:get_program_or_organization)
      end

    end
  end
end
