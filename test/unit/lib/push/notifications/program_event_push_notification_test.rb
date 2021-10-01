require_relative './../../../../test_helper'

module Push
  module Notifications
    class ProgramEventPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @program_event = program_events(:birthday_party)
        @user = users(:f_admin)
        @user.update_column(:state, User::Status::ACTIVE)
        @notification = Push::Notifications::ProgramEventPushNotification.new(@program_event, PushNotification::Type::PROGRAM_EVENT_CREATED, {user_id: @user.id})
        @notification_reminder = Push::Notifications::ProgramEventPushNotification.new(@program_event, PushNotification::Type::PROGRAM_EVENT_REMINDER, {user_id: @user.id})
      end

      def test_recipients
        assert_equal [@user], @notification.recipients
        assert_equal [@user], @notification_reminder.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/program_events/#{@program_event.id}?push_notification=true&push_type=#{PushNotification::Type::PROGRAM_EVENT_CREATED}", @notification.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/program_events/#{@program_event.id}?push_notification=true&push_type=#{PushNotification::Type::PROGRAM_EVENT_REMINDER}", @notification_reminder.redirection_path
      end

      def test_generate_message_for
        assert_equal "Kal Raman invites you to attend an event in Albers Mentor Program.", @notification.generate_message_for(:en)
        assert_equal "[[ Kal Raman íɳνíťéš ýóů ťó áťťéɳď áɳ éνéɳť íɳ Albers Mentor Program. ]]", @notification.generate_message_for(:de)

        assert_equal "Birthday Party is starting tomorrow at chennai, tamilnad....", @notification_reminder.generate_message_for(:en)
        assert_equal "[[ Birthday Party íš šťářťíɳǧ ťóɱóřřóŵ áť chennai, tamilnad.... ]]", @notification_reminder.generate_message_for(:de)
        @notification_reminder.ref_obj.location = ""
        assert_equal "Birthday Party is starting tomorrow.", @notification_reminder.generate_message_for(:en)
        assert_equal "[[ Birthday Party íš šťářťíɳǧ ťóɱóřřóŵ. ]]", @notification_reminder.generate_message_for(:de)
      end

      def test_send_push_notification
        assert PushNotifier.respond_to?(:push)
        @program_event.program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
        @program_event.program.enable_feature(FeatureName::PROGRAM_EVENTS, false)
        PushNotifier.expects(:push).never
        @notification.send_push_notification
        @notification_reminder.send_push_notification
        @program_event.program.enable_feature(FeatureName::PROGRAM_EVENTS)
        PushNotifier.expects(:push).times(2)
        @notification.send_push_notification
        @notification_reminder.send_push_notification
        User::Status.all.each do |state|
          @user.update_column(:state, state)
          if Push::Notifications::ProgramEventPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).times(2)
          else
            PushNotifier.expects(:push).never
          end
          Push::Notifications::ProgramEventPushNotification.new(@program_event, PushNotification::Type::PROGRAM_EVENT_CREATED, {user_id: @user.id}).send_push_notification
          Push::Notifications::ProgramEventPushNotification.new(@program_event, PushNotification::Type::PROGRAM_EVENT_REMINDER, {user_id: @user.id}).send_push_notification
        end
      end

    end
  end
end
