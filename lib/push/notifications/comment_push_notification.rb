require 'articles_helper'

module Push
  module Notifications
    class CommentPushNotification < Push::Base
      include ArticlesHelper

      VALIDATION_CHECKS = {
        check_for_features: [FeatureName::ARTICLES],
        user_states: [User::Status::ACTIVE, User::Status::PENDING]
      }
      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::ARTICLE_COMMENT_CREATED
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
        article_url(ref_obj.publication.article, get_common_url_options.merge(scroll_to: comment_html_id(ref_obj)))
      end

      def generate_message_for(locale)
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = {
            article_commenter_name: ref_obj.user.name(:name_only => true),
            customized_article_term: ref_obj.publication.program.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term_downcase,
            article_title: ref_obj.publication.article.title.truncate(COMMON_TRUNCATE_LENGTH)
          }
          "push_notification.article_comment.created".translate(attributes_hash)
        end
      end

      def get_program_or_organization
        ref_obj.publication.program
      end

    end
  end
end
