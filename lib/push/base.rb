#  STEPS TO ADD A NEW PUSH NOTIFICATION HANDLER
#  ############################################
#  => Add a new class in lib/push/notifications by inheriting from Push::Base
#  => Override all methods marked as "# Mandatory method" below
#  => Define HANDLED_NOTIFICATIONS as an array of PushNotification::Type, for which the class would respond to
#     > Example: HANDLED_NOTIFICATIONS = [PushNotification::Type::ANNOUNCEMENT_NEW]
#  => Define level of notification as either program or organization using NOTIFICATION_LEVEL
#  => If any access checks needs to be modified, define VALIDATION_CHECKS
#  => Apart from feature checks, user states check and organization check, if anything more needs to be verified, override custom_check? method

module Push
  class Base

    include Rails.application.routes.url_helpers

    VALIDATION_CHECKS = {
      check_for_features: [], # [feature1, [feature2, feature3], [feature4, feature5]] => (feature1 && (feature2 || feature3) && (feature4 || feature5))
      user_states: [] # list of states the user should be in
    }
    COMMON_TRUNCATE_LENGTH = 20

    attr_accessor :ref_obj, :notification_type, :options

    def initialize(ref_obj, notification_type, options)
      self.ref_obj           = ref_obj
      self.notification_type = notification_type
      self.options           = options
    end

    # Mandatory method
    # Push notification alert message which will be shown to user
    def generate_message_for(locale)
      nil
    end

    def send_push_notification
      JobLog.compute_with_uuid(recipients, JobLog.generate_uuid, "Push notifications for #{self.class.name} of type #{self.notification_type}") do |recipient|
        PushNotifier.push(get_member(recipient), notification_options.merge(recipient_level_options(recipient)), self) if can_send_push_notification?(recipient)
      end
    end

    def get_common_url_options(options = {})
      program, organization = if options[:organization]
        [options[:program], options[:organization]]
      elsif options[:program]
        [options[:program], options[:program].organization]
      else
        [get_program, get_organization]
      end
      {
        host: organization.domain,
        subdomain: organization.subdomain,
        protocol: organization.get_protocol,
        root: program.try(:root),
        push_notification: true,
        push_type: self.notification_type
      }
    end

    def self.register
      Push::NotificationMapper.instance.register(self::HANDLED_NOTIFICATIONS, self)
    end

    def self.notify(notification_type, object_id, object_type, options = {})
      object = object_type.constantize.find_by(id: object_id)
      return if object.blank?
      Push::NotificationMapper.instance.get_class_for(notification_type).new(object, notification_type, options).send_push_notification
    end

    def self.queued_notify(notification_type, object, options = {})
      queue = options[:queue] || DjQueues::HIGH_PRIORITY
      if queue == :default
        Push::Base.delay.notify(notification_type, object.id, object.class.name, options)
      else
        Push::Base.delay(queue: queue).notify(notification_type, object.id, object.class.name, options)
      end
    end

    def get_program_for_locale
      get_program
    end

    private

    # Mandatory method
    # Expects an array of user or member objects
    def recipients
      Array.new
    end

    # Mandatory method
    # URL to which user will be redirected to from push notification
    # XXX: SHOULD CONTAIN {push_notification: true} WHILE GENERATING PATH Ex: mentor_request_path(ref_obj, push_notification: true)
    def redirection_path
      nil
    end

    def notification_options
      { url: redirection_path }
    end

    def recipient_level_options(user_or_member)
      Hash.new
    end

    #*********** Access checks related methods - Start ***********#
    def can_send_push_notification?(user_or_member)
      feature_enabled?(user_or_member) && organization_check?(user_or_member) && user_check?(user_or_member) && custom_check?(user_or_member)
    end

    # [feature1, [feature2, feature3], [feature4, feature5]] => (feature1 && (feature2 || feature3) && (feature4 || feature5))
    def feature_enabled?(user_or_member)
      return true unless self.class::VALIDATION_CHECKS[:check_for_features].present?
      program_features = get_program.try(:enabled_features) || []
      organization_features = get_organization.try(:enabled_features) || []
      all_features = (program_features + organization_features).uniq
      self.class::VALIDATION_CHECKS[:check_for_features].all? do |required_feature|
        (Array(required_feature) & all_features).present?
      end
    end

    def organization_check?(user_or_member)
      get_program_or_organization.active?
    end

    def user_check?(user_or_member)
      (user_or_member.is_a?(User) && self.class::VALIDATION_CHECKS[:user_states].present?) ? self.class::VALIDATION_CHECKS[:user_states].include?(user_or_member.state) : true
    end

    # sub classes can add custom checks by overriding this method
    def custom_check?(user_or_member)
      true
    end
    #*********** Access checks related methods - End ***********#

    # If ref_obj belongs_to_program_or_organization, override in subclass, to return appropriate object
    def get_program_or_organization
      self.class::NOTIFICATION_LEVEL == PushNotification::Level::PROGRAM ? self.ref_obj.program : self.ref_obj.organization
    end

    def get_program
      get_program_or_organization.is_a?(Program) ? get_program_or_organization : nil
    end

    def get_organization
      get_program ? get_program.organization : get_program_or_organization.is_a?(Organization) ? get_program_or_organization : nil
    end

    def get_member(user_or_member)
      user_or_member.is_a?(User) ? user_or_member.member : user_or_member
    end

  end
end
