require_relative './../../../../test_helper'

module Push
  module Notifications
    class MentorRecommendationPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
        @notification = Push::Notifications::MentorRecommendationPushNotification.new(@mentor_recommendation, PushNotification::Type::MENTOR_RECOMMENDATION_PUBLISH, {})
      end

      def test_recipients
        assert_equal [@mentor_recommendation.receiver], @notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/?push_notification=true&push_type=#{PushNotification::Type::MENTOR_RECOMMENDATION_PUBLISH}&scroll_to=cjs_quick_connect_box", @notification.redirection_path
      end

      def test_generate_message_for
        GlobalizationUtils.run_in_locale(:de) do
          program = @mentor_recommendation.program
          program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).update_attribute(:term_downcase, "de_admin")
          program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).update_attribute(:term_downcase, "de_mentor")
        end
        assert_equal "You have new mentor recommendations. Connect with your mentor now.", @notification.generate_message_for(:en)
        assert_equal "[[ Ýóů ĥáνé ɳéŵ de_mentor řéčóɱɱéɳďáťíóɳš. Čóɳɳéčť ŵíťĥ ýóůř de_mentor ɳóŵ. ]]", @notification.generate_message_for(:de)
      end

      def test_send_push_notification
        @mentor_recommendation.program.enable_feature(FeatureName::MENTOR_RECOMMENDATION, false)
        PushNotifier.expects(:push).never
        @notification.send_push_notification
        @mentor_recommendation.program.enable_feature(FeatureName::MENTOR_RECOMMENDATION)
        PushNotifier.expects(:push).once
        @notification.send_push_notification
        user = @mentor_recommendation.receiver
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::MentorRecommendationPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @notification.send_push_notification
        end
      end

    end
  end
end
