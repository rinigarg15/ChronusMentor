module Push
  module Notifications
    class QaAnswerPushNotification < Push::Base
      include QaAnswersHelper

      VALIDATION_CHECKS = {
        check_for_features: [FeatureName::ANSWERS],
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::QA_ANSWER_CREATED
      ]
      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      attr_accessor :user

      def initialize(ref_obj, notification_type, options)
        self.user = User.find_by(id: options[:user_id])
        super
      end

      def recipients
        [user].compact
      end

      def redirection_path
        qa_question_url(ref_obj.qa_question, get_common_url_options.merge(scroll_to: qa_answer_html_id(ref_obj)))
      end

      def generate_message_for(locale)
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = {
            answerer_name: ref_obj.user.name(:name_only => true),
            question_title: ref_obj.qa_question.summary.truncate(COMMON_TRUNCATE_LENGTH)
          }
          "push_notification.qa_answer.created".translate(attributes_hash)
        end
      end

      def get_program_or_organization
        ref_obj.qa_question.program
      end

    end
  end
end
