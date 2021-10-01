require_relative './../../../../test_helper'

module Push
  module Notifications
    class PostPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @forum = forums(:forums_2)
        @topic = create_topic(forum: @forum)
        @post = create_post(user: users(:f_admin), topic: @topic)
        @user = users(:f_mentor)
        @notification = Push::Notifications::PostPushNotification.new(@post, PushNotification::Type::FORUM_POST_CREATED, user_id: @user.id)
      end

      def test_recipients
        assert_equal [@user], @notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/forums/#{@forum.id}/topics/#{@topic.id}?push_notification=true&push_type=#{PushNotification::Type::FORUM_POST_CREATED}&scroll_to=post_#{@post.id}", @notification.redirection_path
      end

      def test_generate_message_for
        assert_equal "Freakin Admin posted in the conversation '#{@topic.title}'", @notification.generate_message_for(:en)
        assert_equal "[[ Freakin Admin ƿóšťéď íɳ ťĥé čóɳνéřšáťíóɳ '#{@topic.title}' ]]", @notification.generate_message_for(:de)
      end

      def test_send_push_notification
        @post.expects(:can_be_accessed_by?).with(@user, :read_only).once.returns(false)
        PushNotifier.expects(:push).never
        @notification.send_push_notification

        @post.expects(:can_be_accessed_by?).with(@user, :read_only).once.returns(true)
        PushNotifier.expects(:push).once
        @notification.send_push_notification

        User::Status.all.each do |state|
          @user.update_column(:state, state)
          if Push::Notifications::PostPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            @post.expects(:can_be_accessed_by?).with(@user, :read_only).once.returns(true)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          Push::Notifications::PostPushNotification.new(@post, PushNotification::Type::FORUM_POST_CREATED, user_id: @user.id).send_push_notification
        end
      end
    end
  end
end