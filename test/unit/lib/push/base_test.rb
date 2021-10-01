require_relative './../../../test_helper'

module Push
  class BaseTest < ActiveSupport::TestCase

    def setup
      super
      @object = Push::Base.new(nil, nil, {})
    end

    def test_initialize
      object = Push::Base.new(Announcement.first, PushNotification::Type::ANNOUNCEMENT_UPDATE, {})
      assert_equal Announcement.first, object.ref_obj
      assert_equal PushNotification::Type::ANNOUNCEMENT_UPDATE, object.notification_type
      assert_equal Hash.new, object.options
    end

    def test_generate_message_for
      assert_nil @object.generate_message_for(Language.for_member(members(:f_admin)))
    end

    def test_send_push_notification
      # as recipients is [] in base class, PushNotifier should not be called
      PushNotifier.expects(:push).never
      @object.send_push_notification
    end

    def test_should_have_method_queued_notify
      assert Push::Base.respond_to?(:queued_notify)
    end

    def test_register
      Push::NotificationMapper.instance.responders = nil
      assert_nil Push::NotificationMapper.instance.instance_variable_get("@responders")
      # Should raise exception as HANDLED_NOTIFICATIONS is not defined in base and should be defined by sub classes
      assert_raise NameError do
        @object.class.register
      end
      Push::Base.const_set('HANDLED_NOTIFICATIONS', [PushNotification::Type::ANNOUNCEMENT_UPDATE])
      @object.class.register
      assert_equal @object.class, Push::NotificationMapper.instance.instance_variable_get("@responders")[PushNotification::Type::ANNOUNCEMENT_UPDATE.to_s]
    ensure
      Push::Base.send(:remove_const, 'HANDLED_NOTIFICATIONS')
    end

    def test_handled_notifications
      Push::NotificationMapper.instance.send(:get_descendants).each do |notification_klass|
        notification_klass::HANDLED_NOTIFICATIONS.each do |type|
          assert_equal notification_klass, Push::NotificationMapper.instance.get_class_for(type)
        end
      end
    end

    def test_notify
      # invalid object case
      Push::Base.any_instance.expects(:send_push_notification).never
      Push::Base.notify(PushNotification::Type::ANNOUNCEMENT_UPDATE, Announcement.last.id + 1032, Announcement.name)
      # valid case
      Push::Notifications::AnnouncementPushNotification.any_instance.expects(:send_push_notification)
      Push::Base.notify(PushNotification::Type::ANNOUNCEMENT_UPDATE, Announcement.first, Announcement.name)
    end

    def test_queued_notify
      object = mentor_recommendations(:mentor_recommendation_1)
      notification_type = PushNotification::Type::MENTOR_RECOMMENDATION_PUBLISH
      options = {queue: "test_queue", a: 1, b: 2}
      Push::Base.expects(:delay).once.with({queue: "test_queue"}).returns(Push::Base)
      Push::Base.expects(:notify).once.with(notification_type, object.id, object.class.name, options)
      Push::Base.queued_notify(notification_type, object, options)
      options = {queue: :default, a: 1, b: 2}
      Push::Base.expects(:delay).once.with().returns(Push::Base)
      Push::Base.expects(:notify).once.with(notification_type, object.id, object.class.name, options)
      Push::Base.queued_notify(notification_type, object, options)
      options = {a: 1, b: 2}
      Push::Base.expects(:delay).once.with({queue: DjQueues::HIGH_PRIORITY}).returns(Push::Base)
      Push::Base.expects(:notify).once.with(notification_type, object.id, object.class.name, options)
      Push::Base.queued_notify(notification_type, object, options)
    end

    def test_recipients
      assert_equal [], @object.send(:recipients)
    end

    def test_redirection_path
      assert_nil @object.send(:redirection_path)
    end

    def test_notification_options
      expected = {url: nil}
      assert_equal expected, @object.send(:notification_options)
    end

    def test_recipient_level_options
      assert_equal Hash.new, @object.send(:recipient_level_options, users(:f_admin))
      assert_equal Hash.new, @object.send(:recipient_level_options, members(:f_admin))
    end

    def test_can_send_push_notification_organization_level
      @object.ref_obj = members(:f_admin)
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::ORGANIZATION) do
        # all true
        assert @object.send(:can_send_push_notification?, users(:f_admin))
        # organization is inactive
        @object.ref_obj.organization.active = false
        @object.ref_obj.organization.save!
        @object.ref_obj.reload
        assert_false @object.send(:can_send_push_notification?, users(:f_admin))
        # feature check
        @object.ref_obj.organization.active = true
        @object.ref_obj.organization.save!
        @object.ref_obj.reload
        assert @object.send(:can_send_push_notification?, users(:f_admin))
        change_const_of(Push::Base, "VALIDATION_CHECKS".to_sym, {check_for_features: [FeatureName::COACH_RATING, [FeatureName::MENTOR_RECOMMENDATION, FeatureName::DATA_IMPORT]]}) do
          assert_false @object.send(:can_send_push_notification?, users(:f_admin))

          @object.ref_obj.organization.enable_feature(FeatureName::MENTOR_RECOMMENDATION)
          @object.ref_obj.reload
          assert_false @object.send(:can_send_push_notification?, users(:f_admin))

          @object.ref_obj.organization.enable_feature(FeatureName::DATA_IMPORT)
          @object.ref_obj.reload
          assert_false @object.send(:can_send_push_notification?, users(:f_admin))

          @object.ref_obj.organization.enable_feature(FeatureName::MENTOR_RECOMMENDATION, false)
          @object.ref_obj.organization.enable_feature(FeatureName::COACH_RATING)
          @object.ref_obj.reload
          assert @object.send(:can_send_push_notification?, users(:f_admin))

          @object.ref_obj.organization.enable_feature(FeatureName::DATA_IMPORT, false)
          @object.ref_obj.organization.enable_feature(FeatureName::COACH_RATING)
          @object.ref_obj.reload
          assert_false @object.send(:can_send_push_notification?, users(:f_admin))

          @object.ref_obj.organization.enable_feature(FeatureName::MENTOR_RECOMMENDATION)
          @object.ref_obj.reload
          assert @object.send(:can_send_push_notification?, users(:f_admin))
        end

        # user states check
        assert @object.send(:can_send_push_notification?, users(:f_admin))
        change_const_of(Push::Base, "VALIDATION_CHECKS".to_sym, {user_states: [User::Status::PENDING]}) do
          assert_false @object.send(:user_check?, users(:f_admin))
          # should not respect for member object
          assert @object.send(:user_check?, members(:f_admin))
        end
      end
    end

    def test_can_send_push_notification_program_level
      @object.ref_obj = Announcement.first
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::PROGRAM) do
        # all true
        assert @object.send(:can_send_push_notification?, users(:f_admin))
        # organization is inactive
        @object.ref_obj.program.organization.active = false
        @object.ref_obj.program.organization.save!
        @object.ref_obj.reload
        assert_false @object.send(:can_send_push_notification?, users(:f_admin))
        # feature check
        users(:f_admin).program.organization.active = true
        users(:f_admin).program.organization.save!
        @object.ref_obj.reload
        assert @object.send(:can_send_push_notification?, users(:f_admin))
        change_const_of(Push::Base, "VALIDATION_CHECKS".to_sym, {check_for_features: [FeatureName::MENTOR_RECOMMENDATION]}) do
          assert_false @object.send(:can_send_push_notification?, users(:f_admin))
          users(:f_admin).program.enable_feature(FeatureName::MENTOR_RECOMMENDATION)
          @object.ref_obj.reload
          assert @object.send(:can_send_push_notification?, users(:f_admin))
        end
        # user states check
        assert @object.send(:can_send_push_notification?, users(:f_admin))
        change_const_of(Push::Base, "VALIDATION_CHECKS".to_sym, {user_states: [User::Status::PENDING]}) do
          assert_false @object.send(:user_check?, users(:f_admin))
          # should not respect for member object
          assert @object.send(:user_check?, members(:f_admin))
        end
      end
    end

    def test_feature_enabled
      @object.ref_obj = Announcement.first
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::PROGRAM) do
        assert @object.class::VALIDATION_CHECKS[:check_for_features].blank?
        assert @object.send(:feature_enabled?, users(:f_admin))
        change_const_of(Push::Base, "VALIDATION_CHECKS".to_sym, {check_for_features: [FeatureName::MENTOR_RECOMMENDATION]}) do
          assert_false @object.send(:feature_enabled?, users(:f_admin))
          users(:f_admin).program.enable_feature(FeatureName::MENTOR_RECOMMENDATION)
          @object.ref_obj.reload
          assert @object.send(:feature_enabled?, users(:f_admin))
        end
      end
    end

    def test_get_common_url_options
      @object.ref_obj = Announcement.first
      @object.notification_type = PushNotification::Type::ANNOUNCEMENT_NEW
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::PROGRAM) do
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "primary", protocol: "http", root: "albers", push_notification: true, push_type: PushNotification::Type::ANNOUNCEMENT_NEW}, @object.get_common_url_options)
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "annauniv", protocol: "http", root: "ceg", push_notification: true, push_type: PushNotification::Type::ANNOUNCEMENT_NEW}, @object.get_common_url_options(program: programs(:ceg)))
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "foster", protocol: "http", root: nil, push_notification: true, push_type: PushNotification::Type::ANNOUNCEMENT_NEW}, @object.get_common_url_options(organization: programs(:org_foster)))
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "foster", protocol: "http", root: "main", push_notification: true, push_type: PushNotification::Type::ANNOUNCEMENT_NEW}, @object.get_common_url_options(organization: programs(:org_foster), program: programs(:foster)))
      end
      @object.ref_obj = Member.first
      @object.notification_type = PushNotification::Type::MESSAGE_SENT_NON_ADMIN
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::ORGANIZATION) do
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "primary", protocol: "http", root: nil, push_notification: true, push_type: PushNotification::Type::MESSAGE_SENT_NON_ADMIN}, @object.get_common_url_options)
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "annauniv", protocol: "http", root: "ceg", push_notification: true, push_type: PushNotification::Type::MESSAGE_SENT_NON_ADMIN}, @object.get_common_url_options(program: programs(:ceg)))
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "foster", protocol: "http", root: nil, push_notification: true, push_type: PushNotification::Type::MESSAGE_SENT_NON_ADMIN}, @object.get_common_url_options(organization: programs(:org_foster)))
        assert_equal_hash({host: DEFAULT_HOST_NAME, subdomain: "foster", protocol: "http", root: "main", push_notification: true, push_type: PushNotification::Type::MESSAGE_SENT_NON_ADMIN}, @object.get_common_url_options(organization: programs(:org_foster), program: programs(:foster)))
      end
    end

    def test_get_program_and_get_organization
      @object.ref_obj = Announcement.first
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::PROGRAM) do
        assert_equal programs(:albers), @object.send(:get_program)
        assert_equal programs(:org_primary), @object.send(:get_organization)
      end
      @object.ref_obj = Member.first
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::ORGANIZATION) do
        assert_nil @object.send(:get_program)
        assert_equal programs(:org_primary), @object.send(:get_organization)
      end
    end

    def test_organization_check
      # program level
      @object.ref_obj = Announcement.first
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::PROGRAM) do
        assert @object.send(:organization_check?, users(:f_admin))
        assert @object.send(:organization_check?, members(:f_admin))

        @object.ref_obj.program.organization.active = false
        @object.ref_obj.program.organization.save!
        @object.ref_obj.reload
        assert_false @object.send(:organization_check?, users(:f_admin))
        assert_false @object.send(:organization_check?, members(:f_admin))
      end

      # organization level
      @object.ref_obj = Member.first #just some organization level object
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::ORGANIZATION) do
        assert_false @object.send(:organization_check?, users(:f_admin))
        assert_false @object.send(:organization_check?, members(:f_admin))

        @object.ref_obj.organization.active = true
        @object.ref_obj.organization.save!
        @object.ref_obj.reload
        assert @object.send(:organization_check?, users(:f_admin))
        assert @object.send(:organization_check?, members(:f_admin))
      end
    end

    def test_user_check
      assert @object.class::VALIDATION_CHECKS[:user_states].blank?
      assert @object.send(:user_check?, users(:f_admin))
      change_const_of(Push::Base, "VALIDATION_CHECKS", {user_states: [User::Status::PENDING]}) do
        assert_false @object.send(:user_check?, users(:f_admin))
        # should not respect for member object
        assert @object.send(:user_check?, members(:f_admin))
      end
    end

    def test_custom_check
      assert @object.send(:custom_check?, users(:f_admin))
    end

    def test_get_program_or_organization
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::ORGANIZATION) do
        @object.ref_obj = members(:f_admin)
        assert_equal programs(:org_primary), @object.send(:get_program_or_organization)
      end
      change_const_of(Push::Base, "NOTIFICATION_LEVEL".to_sym, PushNotification::Level::PROGRAM) do
        @object.ref_obj = Announcement.first
        assert_equal programs(:albers), @object.send(:get_program_or_organization)
      end
    end

    def test_get_member
      # user case
      assert_equal members(:f_admin), @object.send(:get_member, users(:f_admin))
      # member case
      assert_equal members(:f_admin), @object.send(:get_member, users(:f_admin).member)
    end

  end
end
