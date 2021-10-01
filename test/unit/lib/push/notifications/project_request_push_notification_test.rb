require_relative './../../../../test_helper'

module Push
  module Notifications
    class ProjectRequestPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        project_request = users(:pbe_student_1).sent_project_requests.where(group_id: groups(:group_pbe_0)).first
        project_request.mark_accepted(users(:f_admin_pbe))
        @pbe_request_accepted    = Push::Notifications::ProjectRequestPushNotification.new(project_request, PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT, {})
        project_request_rejected = users(:pbe_student_2).sent_project_requests.where(group_id: groups(:group_pbe_0)).first
        @pbe_request_rejected    = Push::Notifications::ProjectRequestPushNotification.new(project_request_rejected, PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT, {})
      end

      def test_recipients
        assert_equal [users(:pbe_student_1)], @pbe_request_accepted.recipients
        assert_equal [users(:pbe_student_2)], @pbe_request_rejected.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/#{@pbe_request_accepted.ref_obj.group.id}/profile?push_notification=true&push_type=#{PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT}", @pbe_request_accepted.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/find_new?push_notification=true&push_type=#{PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT}", @pbe_request_rejected.redirection_path
      end

      def test_generate_message_for
        assert_equal "Your request to join project_a has been accepted. View project_a’s profile.", @pbe_request_accepted.generate_message_for(:en)
        assert_equal "Your request to join mentoring connection has not been accepted. However, there are other mentoring connections that you may find more suitable.", @pbe_request_rejected.generate_message_for(:en)
        GlobalizationUtils.run_in_locale(:de) do
          program = @pbe_request_accepted.ref_obj.program
          program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).update_attributes!(term_downcase: "de_circle", pluralized_term_downcase: "de_circles")
        end
        assert_equal "[[ Ýóůř řéƣůéšť ťó ʲóíɳ project_a ĥáš ƀééɳ áččéƿťéď. Ѷíéŵ project_a’š ƿřóƒíłé. ]]", @pbe_request_accepted.generate_message_for(:de)
        assert_equal "[[ Ýóůř řéƣůéšť ťó ʲóíɳ de_circle ĥáš ɳóť ƀééɳ áččéƿťéď. Ĥóŵéνéř, ťĥéřé ářé óťĥéř de_circles ťĥáť ýóů ɱáý ƒíɳď ɱóřé šůíťáƀłé. ]]", @pbe_request_rejected.generate_message_for(:de)
      end

      def test_send_push_notification
        #@pbe_request_accepted.sender.size = 1
        PushNotifier.expects(:push).with(users(:pbe_student_1).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/#{@pbe_request_accepted.ref_obj.group.id}/profile?push_notification=true&push_type=#{PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT}"}, @pbe_request_accepted).once
        @pbe_request_accepted.send_push_notification

        #@pbe_request_rejected.sender.size = 1
        PushNotifier.expects(:push).with(users(:pbe_student_2).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/find_new?push_notification=true&push_type=#{PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT}"}, @pbe_request_rejected).once
        @pbe_request_rejected.send_push_notification
      end

      def test_send_push_notification_user_states_request_accepted
        user = @pbe_request_accepted.ref_obj.sender
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::ProjectRequestPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @pbe_request_accepted.send_push_notification
        end
      end

      def test_send_push_notification_user_states_request_rejected
        user = @pbe_request_rejected.ref_obj.sender
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::ProjectRequestPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @pbe_request_rejected.send_push_notification
        end
      end

    end
  end
end
