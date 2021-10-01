module ApplicationControllerExtensions::ActionGroups

  extend ActiveSupport::Concern

  included do
    #
    # Sets the action callbacks for checking the login at the current program/organization
    # level.
    #
    SUPER_USER_ONLY_SKIP_FILTERS = [
      :set_web_dj_priority, :set_dj_organization_id, :login_required_in_program, :require_program,
      :require_organization, :load_current_organization, :load_current_root, :load_current_program,
      :configure_program_tabs, :configure_mobile_tabs
    ]
  end

  class_methods do

    def contextual_login_filters(*opts)
      skip_before_action :require_program, :login_required_in_program, *opts
      before_action :login_required_at_current_level, *opts
    end

    def skip_action_callbacks(action_callbacks, mandatory_filters = [], options = {})
      before_action_callbacks = get_action_callbacks(action_callbacks, :before, mandatory_filters)
      after_action_callbacks  = get_action_callbacks(action_callbacks, :after, mandatory_filters)
      around_action_callbacks = get_action_callbacks(action_callbacks, :around, mandatory_filters)
      arguments = options[:arguments] || []
      # Skip all before and after filters but the mandatory ones.
      skip_before_action(*before_action_callbacks + arguments)
      skip_after_action(*after_action_callbacks + arguments)
      skip_around_action(*around_action_callbacks + arguments)
    end

    def get_action_callbacks(action_callbacks, kind, mandatory_filters)
      action_callbacks.select{|callback| callback.kind == kind}.map(&:filter) - mandatory_filters
    end

    #
    # Skips unwanted filters for the autocomplete actions in +actions+
    #
    def skip_action_callbacks_for_autocomplete(*actions)
      # Filters that are mandatory for autocomplete actions.
      mandatory_filters = [
        :set_web_dj_priority, :set_dj_organization_id, :load_current_organization, :handle_inactive_organization, :load_current_root,
        :load_current_program, :login_required_in_program, :require_organization,
        :require_program, :set_locale_from_cookie_or_member, :set_terminology_helpers, :verify_authenticity_token, :set_session_expiry_cookie, :set_time_zone
      ]

      skip_action_callbacks(_process_action_callbacks, mandatory_filters, arguments: [{only: actions}])
    end

    def skip_action_callbacks_for_api
      mandatory_filters = [
        :set_dj_organization_id, :load_current_organization, :handle_inactive_organization, :load_current_root,
        :load_current_program, :require_organization, :require_program, :set_time_zone, :check_feature_access
      ]
      skip_action_callbacks(_process_action_callbacks, mandatory_filters)
    end

    def skip_action_callbacks_for_mobile_api
      mandatory_filters = [
        :set_dj_organization_id, :set_web_dj_priority, :load_current_organization, :handle_inactive_organization, :load_current_root,
        :load_current_program, :require_organization, :require_program, :set_time_zone, :check_feature_access, :audit_activity
      ]
      skip_action_callbacks(_process_action_callbacks, mandatory_filters)
    end

    def skip_action_callbacks_for_super_user_only_features
      # Skip all before and after filters not required for super user only feature
      action_callbacks = _process_action_callbacks.select{|callback| callback.filter.in?(SUPER_USER_ONLY_SKIP_FILTERS)}
      skip_action_callbacks(action_callbacks)
    end

    def skip_all_action_callbacks(options = {})
      if options.empty?
        skip_action_callbacks(_process_action_callbacks)
      else
        skip_action_callbacks(_process_action_callbacks,  [], arguments: [options])
      end
    end
  end
end