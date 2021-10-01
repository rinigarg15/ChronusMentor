require_relative './../../../../test_helper'

module Push
  module Notifications
    class ProjectBasedEngagementPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        group_accepted = groups(:group_pbe_1)
        group_accepted.created_by = users(:pbe_student_1)
        group_accepted.save!
        @pbe_proposal_accepted  = Push::Notifications::ProjectBasedEngagementPushNotification.new(group_accepted, PushNotification::Type::PBE_PROPOSAL_ACCEPTED, {})
        @pbe_proposal_rejected  = Push::Notifications::ProjectBasedEngagementPushNotification.new(groups(:rejected_group_1), PushNotification::Type::PBE_PROPOSAL_REJECTED, {})
        make_user_owner_of_group(groups(:group_pbe), users(:f_mentor_pbe))
        @pbe_proposal_published = Push::Notifications::ProjectBasedEngagementPushNotification.new(groups(:group_pbe).reload, PushNotification::Type::PBE_PUBLISHED, {})
      end

      def test_recipients
        assert_equal [users(:f_student_pbe)], @pbe_proposal_rejected.recipients
        assert_equal [users(:pbe_student_1)], @pbe_proposal_accepted.recipients
        assert_equal_unordered users(:f_student_pbe, :f_mentor_pbe), @pbe_proposal_published.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/#{@pbe_proposal_accepted.ref_obj.id}/profile?push_notification=true&push_type=#{PushNotification::Type::PBE_PROPOSAL_ACCEPTED}", @pbe_proposal_accepted.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups?push_notification=true&push_type=#{PushNotification::Type::PBE_PROPOSAL_REJECTED}&show=my&tab=6&view=0", @pbe_proposal_rejected.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/#{@pbe_proposal_published.ref_obj.id}?push_notification=true&push_type=#{PushNotification::Type::PBE_PUBLISHED}", @pbe_proposal_published.redirection_path
      end

      def test_generate_message_for
        assert_equal "Your proposed mentoring connection has been accepted. View project_b’s profile.", @pbe_proposal_accepted.generate_message_for(:en)
        assert_equal "Your request to create Incorporate family values by watching Breaking Bad has not been approved. Propose a new mentoring connection or join available mentoring connections.", @pbe_proposal_rejected.generate_message_for(:en)
        assert_equal "Your mentoring connection 'project_group' has started. You can start participating.", @pbe_proposal_published.generate_message_for(:en)
        GlobalizationUtils.run_in_locale(:de) do
          program = @pbe_proposal_accepted.ref_obj.program
          program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).update_attributes!(term_downcase: "de_circle", pluralized_term_downcase: "de_circles")
        end
        assert_equal "[[ Ýóůř ƿřóƿóšéď de_circle ĥáš ƀééɳ áččéƿťéď. Ѷíéŵ project_b’š ƿřóƒíłé. ]]", @pbe_proposal_accepted.generate_message_for(:de)
        assert_equal "[[ Ýóůř řéƣůéšť ťó čřéáťé Incorporate family values by watching Breaking Bad ĥáš ɳóť ƀééɳ áƿƿřóνéď. Рřóƿóšé á ɳéŵ de_circle óř ʲóíɳ áνáíłáƀłé de_circles. ]]", @pbe_proposal_rejected.generate_message_for(:de)
        assert_equal "[[ Ýóůř de_circle 'project_group' ĥáš šťářťéď. Ýóů čáɳ šťářť ƿářťíčíƿáťíɳǧ. ]]", @pbe_proposal_published.generate_message_for(:de)
      end

      def test_send_push_notification
        #@pbe_proposal_accepted.created_by.size = 1
        PushNotifier.expects(:push).with(users(:pbe_student_1).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/#{@pbe_proposal_accepted.ref_obj.id}/profile?push_notification=true&push_type=#{PushNotification::Type::PBE_PROPOSAL_ACCEPTED}"}, @pbe_proposal_accepted).once
        @pbe_proposal_accepted.send_push_notification

        #@pbe_proposal_rejected.created_by.size = 1
        PushNotifier.expects(:push).with(users(:f_student_pbe).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups?push_notification=true&push_type=#{PushNotification::Type::PBE_PROPOSAL_REJECTED}&show=my&tab=6&view=0"}, @pbe_proposal_rejected).once
        @pbe_proposal_rejected.send_push_notification

        #@pbe_proposal_published.members.size = 2
        PushNotifier.expects(:push).with(users(:f_student_pbe).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/#{@pbe_proposal_published.ref_obj.id}?push_notification=true&push_type=#{PushNotification::Type::PBE_PUBLISHED}"}, @pbe_proposal_published).once
        PushNotifier.expects(:push).with(users(:f_mentor_pbe).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/pbe/groups/#{@pbe_proposal_published.ref_obj.id}?push_notification=true&push_type=#{PushNotification::Type::PBE_PUBLISHED}"}, @pbe_proposal_published).once
        @pbe_proposal_published.send_push_notification
      end

      def test_send_push_notification_user_states_proposal_accepted
        user = @pbe_proposal_accepted.ref_obj.created_by
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::ProjectBasedEngagementPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @pbe_proposal_accepted.send_push_notification
        end
      end

      def test_send_push_notification_user_states_proposal_accepted_created_by_is_absent
        @pbe_proposal_accepted.ref_obj.created_by = nil
        @pbe_proposal_accepted.ref_obj.save!
        PushNotifier.expects(:push).never
        @pbe_proposal_accepted.send_push_notification
      end

      def test_send_push_notification_user_states_proposal_accepted
        user = @pbe_proposal_rejected.ref_obj.created_by
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::ProjectBasedEngagementPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @pbe_proposal_rejected.send_push_notification
        end
      end

      def test_send_push_notification_user_states_proposal_rejected_created_by_is_absent
        @pbe_proposal_rejected.ref_obj.created_by = nil
        @pbe_proposal_rejected.ref_obj.save!
        PushNotifier.expects(:push).never
        @pbe_proposal_rejected.send_push_notification
      end

      def test_send_push_notification_user_states_proposal_published
        user_1 = @pbe_proposal_published.ref_obj.members.first
        user_2 = @pbe_proposal_published.ref_obj.members.last
        user_1.update_column(:state, Push::Notifications::ProjectBasedEngagementPushNotification::VALIDATION_CHECKS[:user_states].first)
        user_2.update_column(:state, (User::Status.all - Push::Notifications::ProjectBasedEngagementPushNotification::VALIDATION_CHECKS[:user_states]).first)
        PushNotifier.expects(:push).times(1) # 2 users, but 1 is in invalid state
        @pbe_proposal_published.send_push_notification
      end

    end
  end
end
