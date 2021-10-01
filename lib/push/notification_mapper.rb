module Push
  class NotificationMapper
    include Singleton

    attr_accessor :responders

    def register(notification_types, klass)
      notification_types.each { |notification_type| responders[notification_type.to_s] = klass }
    end

    # This method identifies which class responds to a particular type of push notification
    # In case responders is blank(initially on first load), try loading all classes to register for push notifications
    def get_class_for(notification_type)
      init_responders if responders.blank?
      responders[notification_type.to_s]
    end

    private

    def responders
      @responders ||= Hash.new
    end

    # This methods registers individual push_notification classes for the type of notifications each will respond to.
    def init_responders
      get_descendants.each { |notification_klass| notification_klass.register }
    end

    def get_descendants
      Dir[Rails.root.join("lib/push/notifications/*.rb")].collect do |f|
        ("Push::Notifications::" + File.basename(f,'.rb').camelize).constantize
      end
    end

  end
end
