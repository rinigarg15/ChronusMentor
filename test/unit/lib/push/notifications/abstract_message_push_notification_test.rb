require_relative './../../../../test_helper'

module Push
  module Notifications
    class AbstractMessagePushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @admin_message = messages(:third_admin_message)
        @notification = Push::Notifications::AbstractMessagePushNotification.new(@admin_message, PushNotification::Type::MESSAGE_SENT_ADMIN, {})
      end

      def test_recipients
        assert_equal [members(:f_student)], @notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/admin_messages/#{@admin_message.get_root.id}?is_inbox=true&push_notification=true&push_type=#{PushNotification::Type::MESSAGE_SENT_ADMIN}", @notification.redirection_path
        # Message casel
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/messages/#{messages(:first_message).id}?is_inbox=true&push_notification=true&push_type=#{PushNotification::Type::MESSAGE_SENT_ADMIN}", Push::Notifications::AbstractMessagePushNotification.new(messages(:first_message), PushNotification::Type::MESSAGE_SENT_ADMIN, {}).redirection_path
        # AdminMessage case
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/admin_messages/#{messages(:third_admin_message).parent_id}?is_inbox=true&push_notification=true&push_type=#{PushNotification::Type::MESSAGE_SENT_ADMIN}", Push::Notifications::AbstractMessagePushNotification.new(messages(:third_admin_message), PushNotification::Type::MESSAGE_SENT_ADMIN, {}).redirection_path
        # Other Message type
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/#{groups(:mygroup).id}/scraps?push_notification=true&push_type=#{PushNotification::Type::MESSAGE_SENT_ADMIN}", Push::Notifications::AbstractMessagePushNotification.new(messages(:mygroup_mentor_1), PushNotification::Type::MESSAGE_SENT_ADMIN, {}).redirection_path
      end

      def test_generate_message_for
        sender = members(:robert)
        member = members(:rahim)
        message = create_message(:sender => sender, :receiver => member, :organization => programs(:org_primary))
        french_admin_term = "AdminFr"
        GlobalizationUtils.run_in_locale(:"fr-CA") do
          member.organization.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).update_attribute(:term, french_admin_term)
        end

        @notification.ref_obj = message
        assert_equal "push_notification.message.alert".translate(sender_name: "Administrator", locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.message.alert".translate(sender_name: french_admin_term, locale: "fr-CA"), @notification.generate_message_for("fr-CA")

        @notification.notification_type = PushNotification::Type::MESSAGE_SENT_NON_ADMIN
        assert_equal "push_notification.message.alert".translate(sender_name: sender.name, locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.message.alert".translate(sender_name: sender.name, locale: "fr-CA"), @notification.generate_message_for("fr-CA")
      end

      def test_send_push_notification
        PushNotifier.expects(:push).times(@admin_message.receivers.size)
        @notification.send_push_notification

        @notification.expects(:recipients).returns([@admin_message.receivers.first])
        PushNotifier.expects(:push).with(@admin_message.receivers.first, {url: "http://primary.#{DEFAULT_HOST_NAME}/admin_messages/#{@admin_message.get_root.id}?is_inbox=true&push_notification=true&push_type=#{PushNotification::Type::MESSAGE_SENT_ADMIN}"}, @notification).once
        @notification.send_push_notification
      end

    end
  end
end
