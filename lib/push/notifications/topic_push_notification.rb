module Push
  module Notifications
    class TopicPushNotification < Push::Base

      VALIDATION_CHECKS = {
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::FORUM_TOPIC_CREATED
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
        forum_topic_url(ref_obj.forum, ref_obj, get_common_url_options)
      end

      def generate_message_for(locale)
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = {
            user_name: ref_obj.user.name(name_only: true),
            topic_name: ref_obj.title.truncate(COMMON_TRUNCATE_LENGTH)
          }
          "push_notification.topic.created".translate(attributes_hash)
        end
      end

      private

      def custom_check?(user)
        self.ref_obj.can_be_accessed_by?(user, :read_only)
      end
    end
  end
end