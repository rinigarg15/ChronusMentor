module Push
  module Notifications
    class MentorRecommendationPushNotification < Push::Base

      VALIDATION_CHECKS = {
        check_for_features: [FeatureName::MENTOR_RECOMMENDATION],
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::MENTOR_RECOMMENDATION_PUBLISH
      ]
      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      def recipients
        [ref_obj.receiver]
      end

      def redirection_path
        program_root_url(get_common_url_options.merge(scroll_to: 'cjs_quick_connect_box'))
      end

      def generate_message_for(locale)
        GlobalizationUtils.run_in_locale(locale) do
          "push_notification.mentor_recommendation.publish".translate({mentor: ref_obj.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase})
        end
      end

    end
  end
end
