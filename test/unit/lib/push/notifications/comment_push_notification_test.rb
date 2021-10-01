require_relative './../../../../test_helper'

module Push
  module Notifications
    class CommentPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @article = articles(:kangaroo)
        @article_publication = @article.publications.first
        @user = users(:f_student)
        @comment = @article_publication.comments.create!(user: @user, body: "comment 1")
        @notification = Push::Notifications::CommentPushNotification.new(@comment, PushNotification::Type::ARTICLE_COMMENT_CREATED, {user_id: @user.id})
      end

      def test_recipients
        assert_equal [@user], @notification.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/articles/#{@article.id}?push_notification=true&push_type=#{PushNotification::Type::ARTICLE_COMMENT_CREATED}&scroll_to=comment_#{@comment.id}", @notification.redirection_path
      end

      def test_generate_message_for
        GlobalizationUtils.run_in_locale(:de) do
          program = @article_publication.program
          program.term_for(CustomizedTerm::TermType::ARTICLE_TERM).update_attribute(:term_downcase, "de_article")
        end
        assert_equal "student example commented on an article, Australia Kangaro...", @notification.generate_message_for(:en)
        assert_equal "[[ student example čóɱɱéɳťéď óɳ áɳ de_article, Australia Kangaro... ]]", @notification.generate_message_for(:de)
      end

      def test_send_push_notification
        assert PushNotifier.respond_to?(:push)
        @comment.publication.program.organization.enable_feature(FeatureName::ARTICLES, false)
        @comment.publication.program.enable_feature(FeatureName::ARTICLES, false)
        PushNotifier.expects(:push).never
        @notification.send_push_notification
        @comment.publication.program.enable_feature(FeatureName::ARTICLES)
        PushNotifier.expects(:push).once
        @notification.send_push_notification
        User::Status.all.each do |state|
          @user.update_column(:state, state)
          if Push::Notifications::CommentPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          Push::Notifications::CommentPushNotification.new(@comment, PushNotification::Type::ARTICLE_COMMENT_CREATED, {user_id: @user.id}).send_push_notification
        end
      end

      def test_get_program_or_organization
        assert_equal @article_publication.program, @notification.get_program_or_organization
      end

    end
  end
end
