require_relative './../../../../test_helper'

module Push
  module Notifications
    class MentorOfferPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @mentor_offer = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
        @mentor_offer_notification = Push::Notifications::MentorOfferPushNotification.new(@mentor_offer, PushNotification::Type::MENTOR_OFFER, {})
        @accepted        = create_mentor_offer(:mentor => users(:f_mentor_student), :group => groups(:mygroup))
        @accepted.status = MentorOffer::Status::ACCEPTED
        @accepted.save!
        @mentor_offer_accepted = Push::Notifications::MentorOfferPushNotification.new(@accepted, PushNotification::Type::MENTOR_OFFER_ACCEPTED, {})
        @rejected          = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
        @rejected.status   = MentorOffer::Status::REJECTED
        @rejected.response = "Test Response"
        @accepted.save!
        @mentor_offer_rejected = Push::Notifications::MentorOfferPushNotification.new(@rejected, PushNotification::Type::MENTOR_OFFER_REJECTED, {})
      end

      def test_recipients
        assert_equal [users(:f_student)], @mentor_offer_notification.recipients
        assert_equal [users(:f_mentor_student)], @mentor_offer_accepted.recipients
        assert_equal [users(:f_mentor)], @mentor_offer_rejected.recipients
      end

      def test_redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/mentor_offers?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER}", @mentor_offer_notification.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/1?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER_ACCEPTED}", @mentor_offer_accepted.redirection_path
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/users?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER_REJECTED}&view=student", @mentor_offer_rejected.redirection_path
      end

      def test_generate_message_for
        assert_equal "Good unique name has offered to be your mentor in Albers Mentor Program.", @mentor_offer_notification.generate_message_for(:en)
        assert_equal "student example has accepted to be your student in Albers Mentor Program", @mentor_offer_accepted.generate_message_for(:en)
        assert_equal "student example did not accept your mentoring connection offer in Albers Mentor Program. We have other students who may benefit from your mentoring connection.", @mentor_offer_rejected.generate_message_for(:en)
        french_mentoring_term = "mentoringfr"
        GlobalizationUtils.run_in_locale(:"de") do
          @mentor_offer.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).update_term(term: french_mentoring_term)
          @accepted.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).update_term(term: "studentfr")
          @rejected.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).update_term(term: "circlede")
          @rejected.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).update_term(pluralized_term: "studentfr")
        end
        assert_equal "[[ Good unique name ĥáš óƒƒéřéď ťó ƀé ýóůř mentor íɳ Albers Mentor Program. ]]", @mentor_offer_notification.generate_message_for(:de)
        assert_equal "[[ student example ĥáš áččéƿťéď ťó ƀé ýóůř student íɳ Albers Mentor Program ]]", @mentor_offer_accepted.generate_message_for(:de)
        assert_equal "[[ student example ďíď ɳóť áččéƿť ýóůř circlede óƒƒéř íɳ Albers Mentor Program. Ŵé ĥáνé óťĥéř studentfr ŵĥó ɱáý ƀéɳéƒíť ƒřóɱ ýóůř circlede. ]]", @mentor_offer_rejected.generate_message_for(:de)
      end

      def test_send_push_notification
        PushNotifier.expects(:push).with(users(:f_student).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/mentor_offers?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER}"}, @mentor_offer_notification).once
        @mentor_offer_notification.send_push_notification
        PushNotifier.expects(:push).with(users(:f_mentor_student).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/1?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER_ACCEPTED}"}, @mentor_offer_accepted).once
        @mentor_offer_accepted.send_push_notification
        PushNotifier.expects(:push).with(users(:f_mentor).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/users?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER_REJECTED}&view=student"}, @mentor_offer_rejected).once
        @mentor_offer_rejected.send_push_notification
      end

      def test_send_push_notification_mentor_offer_user_states
        user = @mentor_offer_notification.ref_obj.student
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::MentorOfferPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @mentor_offer_notification.send_push_notification
        end
      end

      def test_send_push_notification_mentor_offer_accepted_user_states
        user = @mentor_offer_accepted.ref_obj.mentor
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::MentorOfferPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @mentor_offer_accepted.send_push_notification
        end
      end

      def test_send_push_notification_mentor_offer_rejected_user_states
        user = @mentor_offer_rejected.ref_obj.mentor
        User::Status.all.each do |state|
          user.update_column(:state, state)
          if Push::Notifications::MentorOfferPushNotification::VALIDATION_CHECKS[:user_states].include?(state)
            PushNotifier.expects(:push).once
          else
            PushNotifier.expects(:push).never
          end
          @mentor_offer_rejected.send_push_notification
        end
      end

      def test_send_push_notification_mentor_offer_feature_check
        @mentor_offer.program.enable_feature(FeatureName::OFFER_MENTORING, false)
        PushNotifier.expects(:push).never
        @mentor_offer_notification.send_push_notification

        @mentor_offer.program.enable_feature(FeatureName::OFFER_MENTORING, true)
        PushNotifier.expects(:push).with(users(:f_student).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/mentor_offers?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER}"}, @mentor_offer_notification).once
        @mentor_offer_notification.send_push_notification
      end

      def test_send_push_notification_mentor_offer_accepted_feature_check
        @accepted.program.enable_feature(FeatureName::OFFER_MENTORING, false)
        PushNotifier.expects(:push).never
        @mentor_offer_accepted.send_push_notification

        @accepted.program.enable_feature(FeatureName::OFFER_MENTORING, true)
        PushNotifier.expects(:push).with(users(:f_mentor_student).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/1?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER_ACCEPTED}"}, @mentor_offer_accepted).once
        @mentor_offer_accepted.send_push_notification
      end

      def test_send_push_notification_mentor_offer_rejected_feature_check
        @rejected.program.enable_feature(FeatureName::OFFER_MENTORING, false)
        PushNotifier.expects(:push).never
        @mentor_offer_rejected.send_push_notification

        @rejected.program.enable_feature(FeatureName::OFFER_MENTORING, true)
        PushNotifier.expects(:push).with(users(:f_mentor).member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/users?push_notification=true&push_type=#{PushNotification::Type::MENTOR_OFFER_REJECTED}&view=student"}, @mentor_offer_rejected).once
        @mentor_offer_rejected.send_push_notification
      end

    end
  end
end