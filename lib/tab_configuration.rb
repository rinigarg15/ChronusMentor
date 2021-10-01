require File.join(Rails.root, 'config', 'tab_constants')

module TabConfiguration
  def self.included(controller)
    controller.send :include, InstanceMethods
  end

  # Represents a tab in the application.
  class Tab
    attr_accessor :label
    attr_accessor :url
    attr_accessor :active
    attr_accessor :subtabs
    attr_accessor :iconclass
    attr_accessor :open_by_default
    attr_accessor :hide_tab_header
    attr_accessor :tab_class
    attr_accessor :mobile_tab_modal_id
    attr_accessor :mobile_tab_badge
    attr_accessor :mobile_tab_class

    module SubTabKeys
      LINKS_LIST = "links_list"
      LINK_LABEL_HASH = "link_label"
      BADGE_COUNT_HASH = "badge_count"
      ICON_CLASS_HASH = "icon_class"
      IS_ACTIVE_HASH = "is_active"
      HAS_PARTIAL_HASH = "has_partial"
      RENDER_PATH_HASH = "link_path"
    end

    module SubTabLinks
      REQUESTED_MEETINGS = "requested_meetings"
      UPCOMING_MEETINGS = "upcoming_meetings"
      PAST_MEETINGS = "past_meetings"
      MENTORING_CALENDAR = "mentoring_calendar"
      MENTORING_CONNECTION = "mentoring_connection"
      CLOSED_CONNECTION = "closed_connection"
      RESOURCES = "resources"
      FORUM = "forum"
      QA = "qa"
      ARTICLES = "articles"
      ADVICE = "advice"
      EXECUTIVE_DASHBOARD = "executive_dashboard"
      PROGRAM_EVENTS = "program_events"
      CONTACT_ADMIN = "contact_admin"
      SUPPORT = "support"
      HEALTH_REPORT = "health_report"
      OUTCOME_REPORT = "outcome_report"
      USER_REPORT = "user_report"
    end

    def initialize(init_label, init_url, init_active, options = {})
      @label = init_label
      @url = init_url
      @active = init_active
      @subtabs = options[:subtabs]
      @iconclass = options[:iconclass]
      @open_by_default = options[:open_by_default]
      @tab_class = options[:tab_class]
      @mobile_tab_modal_id = options[:modal_id]
      @mobile_tab_badge = options[:badge_text]
      @mobile_tab_class = options[:mobile_tab_class]
    end
  end

  module InstanceMethods
    # <code>Tab</code>s in the order of addition
    attr_accessor :all_tabs, :mobile_tabs

    # <code>Tab</code>s indexed by tab label
    attr_accessor :tab_info

    def all_tabs
      @all_tabs ||= []
      @all_tabs
    end

    def mobile_tabs
      @mobile_tabs ||= []
      @mobile_tabs
    end

    def tab_info
      @tab_info ||= {}
      @tab_info
    end

    # Returns the default tab to select.
    def default_tab
      if logged_in_organization?
        tab_info[TabConstants::HOME]
      else
        # When <code>TabConstants::APP_HOME</code> tab is not be available,
        # default to about tab.
        tab_info[TabConstants::APP_HOME] || tab_info[TabConstants::ABOUT_PROGRAM]
      end
    end

    # Adds the tab for the given configuration.
    #
    # ==== Params
    # label       ::  <code>TabConfiguration::Tab</code> to be added
    # url         ::  url that the tab should link to
    # active      ::  true if the tab should be marked active.
    #
    def add_tab(label, url, active, options = Hash.new)
      tab_entry = Tab.new(label, url, active, options)
      self.tab_info ||= {}
      self.all_tabs ||= []
      self.tab_info[label] = tab_entry
      self.all_tabs << tab_entry
    end

    def add_mobile_tab(label, url, active, options = Hash.new)
      tab_entry = Tab.new(label, url, active, options)
      self.mobile_tabs ||= []
      self.mobile_tabs << tab_entry
    end

    # Iterate until we find the first match, assign the selected tab and break
    # out of the loop.
    def compute_active_mobile_tab
      selected_tab = nil
      self.mobile_tabs.each do |tab_info|
        (selected_tab = tab_info) and break if tab_info.active
      end
      activate_tab(selected_tab, true)
    end

    def compute_active_tab
      selected_tab = default_tab
      is_subtab_selected = false
      is_active_tab_found = false
      
      self.all_tabs.each do |tab_info|
        if tab_info.subtabs.present? && tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH].present? && tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH].values.include?(true)
          is_subtab_selected = true
        end

        if !is_active_tab_found && tab_info.active
          selected_tab = tab_info
          is_active_tab_found = true
        end
      end
      
      if is_subtab_selected
        deactivate_tabs
      else
        activate_tab(selected_tab)
      end
    end

    # Marks the tab corresponding to the given <i>given_tab_info</i> as active
    # and also setting all others inactive.
    #
    def activate_tab(given_tab_info, mobile_tab = false)
      tabs = mobile_tab ? self.mobile_tabs : self.all_tabs
      tabs.each do |tab|
        tab.active = (tab == given_tab_info)
      end
    end

    def deactivate_tabs
      self.all_tabs.each do |tab|
        tab.active = false
      end
    end
  end
end
