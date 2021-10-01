require_relative './../../../../test_helper'

module Push
  module Notifications
    class QaAnswerPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @qa_answer = qa_answers(:for_question_what)
        @user = @qa_answer.qa_question.user
        @notification  = Push::Notifications::QaAnswerPushNotification.new(@qa_answer, PushNotification::Type::QA_ANSWER_CREATED, {user_id: @user.id})
      end

      def test_recipients
        assert_equal [@user], @notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/qa_questions/#{@qa_answer.qa_question_id}?push_notification=true&push_type=#{PushNotification::Type::QA_ANSWER_CREATED}&scroll_to=qa_answer_#{@qa_answer.id}", @notification.redirection_path
      end

      def test_generate_message_for
        assert_equal "student example posted an answer to the question, where is chennai?.", @notification.generate_message_for(:en)
        assert_equal "[[ student example ƿóšťéď áɳ áɳšŵéř ťó ťĥé ƣůéšťíóɳ, where is chennai?. ]]", @notification.generate_message_for(:de)
      end

      def test_send_push_notification
        @qa_answer.qa_question.program.organization.enable_feature(FeatureName::ANSWERS, false)
        @qa_answer.qa_question.program.enable_feature(FeatureName::ANSWERS, false)
        PushNotifier.expects(:push).never
        @notification.send_push_notification
        @qa_answer.qa_question.program.enable_feature(FeatureName::ANSWERS)
        PushNotifier.expects(:push).once
        @notification.send_push_notification
        User::Status.all.each do |state|
          @user.update_column(:state, state)
          if Push::Notifications::QaAnswerPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          Push::Notifications::QaAnswerPushNotification.new(@qa_answer, PushNotification::Type::QA_ANSWER_CREATED, {user_id: @user.id}).send_push_notification
        end
      end

    end
  end
end
