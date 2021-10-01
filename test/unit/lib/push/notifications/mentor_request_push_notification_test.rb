require_relative './../../../../test_helper'

module Push
  module Notifications
    class MentorRequestPushNotificationTest < ActiveSupport::TestCase

      def setup
        super
        @notification = Push::Notifications::MentorRequestPushNotification.new(mentor_requests(:moderated_request_with_favorites), PushNotification::Type::MENTOR_REQUEST_CREATE, {recipients: mentor_requests(:moderated_request_with_favorites).receivers.first})
      end

      def test_recipients
        assert_equal [mentor_requests(:moderated_request_with_favorites).receivers.first], @notification.recipients
      end

      def test_user_check
        user = @notification.recipients.first
        assert @notification.send(:user_check?, user)
        user.state = 'pending'
        user.save!
        assert @notification.send(:user_check?, user)
        user.state = 'suspended'
        user.track_reactivation_state = 'active'
        user.save!
        assert_false @notification.send(:user_check?, user)
      end

      def test_redirection_path
        @notification.notification_type = PushNotification::Type::MENTOR_REQUEST_CREATE
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/modprog/mentor_requests?mentor_request_id=#{@notification.ref_obj.id}&push_notification=true&push_type=#{PushNotification::Type::MENTOR_REQUEST_CREATE}", @notification.redirection_path
        @notification.ref_obj = mentor_requests(:mentor_request_11)
        @notification.notification_type = PushNotification::Type::MENTOR_REQUEST_REJECT
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/users?push_notification=true&push_type=#{PushNotification::Type::MENTOR_REQUEST_REJECT}&src=#{EngagementIndex::Src::BrowseMentors::PUSH_NOTIFICTAION}", @notification.redirection_path
        @notification.ref_obj.status = AbstractRequest::Status::ACCEPTED
        @notification.ref_obj.group_id = groups(:mygroup).id
        @notification.ref_obj.save!
        @notification.notification_type = PushNotification::Type::MENTOR_REQUEST_ACCEPT
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/1?first_visit=1&push_notification=true&push_type=#{PushNotification::Type::MENTOR_REQUEST_ACCEPT}", @notification.redirection_path
        @notification.notification_type = PushNotification::Type::MENTOR_REQUEST_REMINDER
        assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/mentor_requests?list=active&mentor_request_id=#{@notification.ref_obj.id}&push_notification=true&push_type=#{PushNotification::Type::MENTOR_REQUEST_REMINDER}", @notification.redirection_path
      end

      def test_generate_message_for
        program = programs(:albers)
        member = members(:rahim)
        mentee_name = users(:f_student).name
        mentor_name = users(:f_mentor).name
        french_mentoring_term = "mentoringfr"
        eng_mentoring_term = program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase
        mentor_request = MentorRequest.create!(:message => "Hi", :program => program, :student => users(:f_student), :mentor => users(:f_mentor))
        GlobalizationUtils.run_in_locale(:"de") do
          program.term_for(CustomizedTerm::TermType::MENTORING_TERM).update_term(term: french_mentoring_term)
        end

        @notification.ref_obj = mentor_request
        assert_equal "push_notification.mentor_request.create.alert_v1".translate(mentoring: eng_mentoring_term, mentee_name: mentee_name, locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.mentor_request.create.alert_v1".translate(mentoring: french_mentoring_term, mentee_name: mentee_name, locale: "de"), @notification.generate_message_for("de")

        @notification.notification_type = PushNotification::Type::MENTOR_REQUEST_ACCEPT
        assert_equal "push_notification.mentor_request.accept.alert".translate(mentoring: eng_mentoring_term, mentor_name: mentor_name, locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.mentor_request.accept.alert".translate(mentoring: french_mentoring_term, mentor_name: mentor_name, locale: "de"), @notification.generate_message_for("de")

        @notification.notification_type = PushNotification::Type::MENTOR_REQUEST_REJECT
        assert_equal "push_notification.mentor_request.reject.alert_v1".translate(mentoring: eng_mentoring_term, rejector_name: mentor_name, locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.mentor_request.reject.alert_v1".translate(mentoring: french_mentoring_term, rejector_name: mentor_name, locale: "de"), @notification.generate_message_for("de")

        @notification.notification_type = PushNotification::Type::MENTOR_REQUEST_REMINDER
        assert_equal "push_notification.mentor_request.reminder.alert".translate(mentoring: eng_mentoring_term, mentee_name: mentee_name, locale: "en"), @notification.generate_message_for("en")
        assert_equal "push_notification.mentor_request.reminder.alert".translate(mentoring: french_mentoring_term, mentee_name: mentee_name, locale: :de), @notification.generate_message_for(:de)
      end

      def test_send_push_notification
        @notification.options = {recipients: mentor_requests(:moderated_request_with_favorites).receivers}
        PushNotifier.expects(:push).times(mentor_requests(:moderated_request_with_favorites).receivers.size)
        @notification.send_push_notification

        @notification.options = {recipients: mentor_requests(:moderated_request_with_favorites).receivers.first}
        PushNotifier.expects(:push).with(mentor_requests(:moderated_request_with_favorites).receivers.first.member, {url: "http://primary.#{DEFAULT_HOST_NAME}/p/modprog/mentor_requests?mentor_request_id=#{@notification.ref_obj.id}&push_notification=true&push_type=#{PushNotification::Type::MENTOR_REQUEST_CREATE}"}, @notification).once
        @notification.send_push_notification
      end

    end
  end
end
