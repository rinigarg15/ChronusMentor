module TabConfigurationHelper
  module OrganizationTabConfigurationHelper
    def configure_organization_tabs
      cname = params[:controller]
      aname = params[:action]
      configure_logged_in_organization_tabs(cname, aname)
      pages_to_tabs!
      add_tab(TabConstants::ABOUT_PROGRAM, about_path, (cname == "pages"), iconclass: "fa-file") unless wob_member && wob_member.admin?
      compute_active_tab
    end

    private

    def configure_logged_in_organization_tabs(cname, aname)
      if logged_in_organization?
        add_tab(TabConstants::HOME, root_organization_path, cname == 'organizations' && aname == 'show', iconclass: "fa-home")
        configure_dashboards_tab
        configure_help_and_support_tab(false)
        configure_manage_organization_tab(cname, aname)
      end
    end

    def configure_manage_organization_tab(cname, aname)
      # Show Manage tab to Organization admin and if program user has permission.
      if wob_member.admin?
        add_tab(
          TabConstants::MANAGE, manage_organization_path, is_organization_manage_page?(cname, aname), iconclass: "fa-cogs"
        )
      end
    end

    def filter_pages(pages)
      logged_in_at_current_level? ? pages.select{|p| p.use_in_sub_programs?} : pages
    end

    def is_organization_manage_page?(cname, aname)
      organization_manage_tabs.any? do |key, value|
        if value[:match].blank?
          cname == key && organization_aname_match?(value[:aname], aname)
        else
          cname.match(key) && organization_aname_match?(value[:aname], aname)
        end
      end
    end

    def organization_manage_tabs
      # The following pages come under the manage tab, for admin.
      #
      # * Manage tab
      # * Program edit page
      # * Mentor requests index
      # * Announcements
      # * Membership requests
      # * Invite users page
      # * Add new mentor page
      #
      return {
        'pages' => {},
        'organizations' => { aname: ['manage' => {}, 'edit' => {}] },
        'programs' => { aname: ['new' => {}] },
        'questions' => {},
        'organization_admins' => {},
        'themes' => {},
        'profile_questions' => {},
        'mailer_templates' => {},
        'mailer_widgets' => {},
        'resources' => {},
        'admin_views' => {},
        'data_imports' => {},
        'organization_languages' => {},
        'translations' => {},
        'three_sixty' => { match: true},
      }
    end

    def organization_aname_match?(action_names, aname)
      (action_names.blank? || action_names.any? {|action| aname == action.keys.first} )
    end
  end
end