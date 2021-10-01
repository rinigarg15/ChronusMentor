require_relative './../../../../test_helper'

module Push
  module Notifications
    class GroupPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @group = groups(:mygroup)
        @user = @group.members[0]
        @group_member_added_notification = Push::Notifications::GroupPushNotification.new(@group, PushNotification::Type::GROUP_MEMBER_ADDED, {user_id: @user.id})
        @group_inactivity_notification = Push::Notifications::GroupPushNotification.new(@group, PushNotification::Type::GROUP_INACTIVITY, {user_id: @user.id})
      end

      def test_recipients
        assert_equal [@user], @group_member_added_notification.recipients
        assert_equal [@user], @group_inactivity_notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/#{@group.id}?push_notification=true&push_type=#{PushNotification::Type::GROUP_MEMBER_ADDED}", @group_member_added_notification.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/#{@group.id}?push_notification=true&push_type=#{PushNotification::Type::GROUP_INACTIVITY}", @group_inactivity_notification.redirection_path
      end

      def test_generate_message_for
        GlobalizationUtils.run_in_locale(:de) do
          program = @group.program
          program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).update_attribute(:articleized_term_downcase, "a_de_student")
          program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).update_attribute(:articleized_term_downcase, "a_de_mentor")
        end
        assert_equal "You have been added as a student in name & madankumar....", @group_member_added_notification.generate_message_for(:en)
        assert_equal "[[ Ýóů ĥáνé ƀééɳ áďďéď áš a_de_student íɳ name & madankumar.... ]]", @group_member_added_notification.generate_message_for(:de)
        assert_equal "We've missed hearing from you! Get back to catch up on any pending tasks.", @group_inactivity_notification.generate_message_for(:en)
        assert_equal "[[ Ŵé'νé ɱíššéď ĥéáříɳǧ ƒřóɱ ýóů! Ǧéť ƀáčǩ ťó čáťčĥ ůƿ óɳ áɳý ƿéɳďíɳǧ ťášǩš. ]]", @group_inactivity_notification.generate_message_for(:de)
      end

      def test_send_push_notification
        User::Status.all.each do |state|
          @user.update_column(:state, state)
          if Push::Notifications::GroupPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).times(2)
          else
            PushNotifier.expects(:push).never
          end
          @group_member_added_notification.user.reload
          @group_member_added_notification.send_push_notification
          @group_inactivity_notification.user.reload
          @group_inactivity_notification.send_push_notification
        end
      end

    end
  end
end
