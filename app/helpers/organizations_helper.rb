module OrganizationsHelper
  module SecuritySetting
    DEFAULT_PASSWORD_AUTO_EXPIRY = 30
    DEFAULT_LOGIN_ATTEMPTS = 3
    DEFAULT_AUTO_REACTIVATE_PASSWORD = 24.0
    DEFAULT_PASSWORD_HISTORY_LIMIT = 4
  end

  module Headers
    PROGRAM_DETAILS = 1
    ADMIN_ACCOUNT = 2
    COMPLETE_REGISTRATION = 3
  end

  module SrcTracker
    GLOBAL_REPORTS_V2 = "global_reports_v2"
  end

  # Renders organization settings page tabs
  #
  # ==== Params
  # <tt>cur_tab</tt>  : the number of the currently selected tab.
  #
  def organization_settings_tabs(cur_tab, customized_terms = {})
    tabs_to_show = []
    tabs_to_show << ProgramsController::SettingsTabs::GENERAL
    tabs_to_show << ProgramsController::SettingsTabs::TERMINOLOGY if super_console?
    tabs_to_show << ProgramsController::SettingsTabs::FEATURES
    tabs_to_show << ProgramsController::SettingsTabs::SECURITY

    tabs = []
    ProgramsController::SettingsTabs.all.each do |tab|
      next unless tabs_to_show.include?(tab)

      tabs << {
        :label => ProgramsController::SettingsTabs.get_label(tab, customized_terms),
        :url => edit_organization_path(:tab => tab),
        :active => (tab == cur_tab)}
    end

    inner_tabs(tabs)
  end

  def get_features_to_hide(abstract_program)
    features_to_hide = abstract_program.removed_as_feature_from_ui
    if abstract_program.is_a?(Program)
      features_to_hide += FeatureName.ongoing_mentoring_related_features unless abstract_program.ongoing_mentoring_enabled?
      features_to_hide += FeatureName.organization_level_features unless abstract_program.standalone?
    end
    features_to_hide
  end

  def render_editable_feature(prog_or_org, feature_name, input_field, disabled_list, options = {})
    control_group do
      controls do
        content_tag(:label, :class => "checkbox") do
          check_box_tag(input_field, feature_name, prog_or_org.has_feature?(feature_name), :id => feature_name.to_html_id, :class => "cjs_features_list", :disabled => disabled_list.include?(feature_name)) +
          FeatureName.list(feature_name, prog_or_org, options)
        end +
        content_tag(:div, FeatureName::Descriptions.translate(feature_name, prog_or_org, options), :class => 'dim fixed-checkbox-offset')
      end
    end
  end

  def prepare_disabled_list(prog_or_org)
    disabled_list = get_disabled_list(prog_or_org)
    org = prog_or_org.is_a?(Program) ? prog_or_org.organization : prog_or_org
    disabled_list << FeatureName::MANAGER if org.profile_questions.where(question_type: ProfileQuestion::Type::MANAGER).present?
    disabled_list << FeatureName::MEMBERSHIP_ELIGIBILITY_RULES if prog_or_org.is_a?(Program) && prog_or_org.has_allowing_join_with_criteria?
    disabled_list << FeatureName::CAMPAIGN_MANAGEMENT if prog_or_org.campaign_feature_non_editable?
    disabled_list.uniq
  end

  def rollup_box_wrapper(options = {}, &block)
    container_class = options[:container_class] || "col-md-4 col-sm-12 p-r-0 p-l-0 cjs_current_status_tiles m-b-sm"
    ibox_content_padding_options = options[:ibox_content_padding_options] || "p-b-xxs"
    content_tag(:div, class: container_class) do
      content_tag(:div, class: "ibox m-0") do
        content_tag(:div, class: "ibox-content clearfix #{ibox_content_padding_options}") do
          content_str = rollup_box_title(options)
          content_str << content_tag(:div, class: "row #{options[:rollup_box_container_class]}") do
            capture(&block)
          end
          content_str
        end
      end
    end
  end

  def rollup_body_box(options = {})
    content_tag(:div, class: (options[:box_grid_class] || "col-xs-12")) do
      content_tag(:h1, class: "m-b-md") do
        content_str = get_icon_content("fa #{options[:box_icon_class]} m-r-sm text-navy")
        content_str << (options[:link_number] ? rollup_body_box_link_number(options) : content_tag(:span, options[:text_number].to_s, class: "font-600 #{options[:text_number_class]}"))
        content_str << options[:right_addon]
        content_str
      end
    end
  end

  def rollup_body_sub_boxes(data_array, options = {})
    default_col_class = "col-xs-#{12 / data_array.size} #{options[:additional_class]}"
    content_str = get_safe_string
    data_array.each do |data|
      content_str << rollup_body_sub_box(data, default_col_class: "#{default_col_class}")
    end
    content_str
  end

  def rollup_body_sub_box(data, options = {})
    content_tag(:div, class: "#{(data[:box_grid_class] || options[:default_col_class])} #{data[:additional_class]}") do
      content_str = get_safe_string
      content_str << content_tag(:div, data[:title])
      content_str << content_tag(:h4, data[:content])
      content_str
    end
  end

  def get_toggle_class_for_security(show_control)
    show_control ? "" : "hide"
  end

  def get_page_action_for_multi_track_admin(show_admin_dashboard)
    if show_admin_dashboard
      {label: "feature.org_home_page.multi_track_admin.content.activities_dashboard".translate, url: root_organization_path(activities_dashboard: true), class: "btn btn-primary btn-large"}
    else
      {label: "feature.org_home_page.multi_track_admin.content.global_dashboard".translate, url: root_organization_path, class: "btn btn-primary btn-large"}
    end
  end

  def display_user_states_in_program(program, role_names, status_string, _options = {})
    result = "".html_safe
    RoleConstants.to_program_role_names(program, role_names).each do |role_name|
      result = result + content_tag(:span, "#{role_name}#{status_string || ""}", class: "label label-default inline m-t-xs m-r-xs")
    end

    return result
  end

  def display_user_actions_in_program(user, program, options = {})
    result = "".html_safe
    roles_to_join = get_roles_to_join(user, options)
    result << link_to((options[:icon_content] || "") + "feature.enrollment.join_program".translate(program: _Program),"javascript:void(0)",
                      :data => {:url => enrollment_popup_path(format: :js, roles: roles_to_join.collect(&:name), program: program.id)},
                      class: "enrollment_popup_link_#{program.id} btn btn-primary remote-popup-link"
    ) if roles_to_join.present?

    return content_tag(:div, result)
  end

  def enrollment_popup_title(program_name)
    "feature.enrollment.enroll_in_program".translate(program_name: program_name)
  end

  def get_ip_container(ip_address, is_standalone, options={})
    input_prefix = is_standalone ? "program[organization]" : "organization"
    input = "#{input_prefix}[security_setting_attributes][allowed_ips][]"
    from, to = ips_to_array(ip_address)
    content_tag(:div, class: "has-below no-padding col-xs-12") do
      concat label_tag("#{input}[from]", "program_settings_strings.content.allowed_ips_from_text".translate, :for => "security_setting_attributes_allowed_ips_from", :class => "sr-only")
      concat content_tag(:span, text_field_tag("#{input}[from]", from, class: "has-next form-control input-sm", placeholder: "program_settings_strings.content.allowed_ips_from_text".translate, id: "security_setting_attributes_allowed_ips_from"), :class => "col-xs-5 no-padding")
      concat content_tag(:span, 'display_string.to'.translate, class: 'p-xxs pull-left text-center')
      concat label_tag("#{input}[to]", "program_settings_strings.content.allowed_ips_to_text".translate, :class => "sr-only", :for => "security_setting_attributes_allowed_ips_to")
      concat content_tag(:span, text_field_tag("#{input}[to]", to, class: "has-next form-control input-sm", placeholder: "program_settings_strings.content.allowed_ips_to_text".translate, id: "security_setting_attributes_allowed_ips_to"), :class => "col-xs-5 no-padding")
      concat content_tag(:span, get_icon_content('fa fa-trash'), class: "pointer cjs_allowed_ip p-xxs pull-left cjs_ip_input #{options[:additional_class]}")
    end
  end

  def show_join_at_organization_level
    (!@only_login && organization_view? && @current_organization.programs.allowing_membership_requests.any? && @current_organization.programs_listing_visible_to_all? && @current_organization.programs.published_programs.present?)
  end

  def show_join_now?
    (program_view? && @current_program.allow_join_now?  && !@only_login) || show_join_at_organization_level
  end

  def join_now_join_url
    return unless show_join_now?
    return show_join_at_organization_level ? programs_pages_path(:src => 'join_now') : new_membership_request_path
  end

  def ips_to_array(ip_address)
    case ip_address
    when Range
      [ip_address.first, ip_address.last]
    else
      [ip_address, nil]
    end
  end

  def get_enrollment_form(url, program, roles, options={})
    remote = options[:remote] || false
    label_content, roles_content = get_label_and_roles_content_for_enrollment_form(roles, program, options)
    form_tag(url, remote: remote, id: options[:form_id], class: "form-horizontal #{options[:form_class]}") do
      hidden_field_tag(:program, program.id) +
      control_group do
        label_content +
        controls(class: "col-sm-9") do
          roles_content
        end +

        controls(class: "m-t-md col-sm-12") do
          submit_tag("display_string.Proceed".translate, :class => 'btn btn-primary btn-block-xxs pull-right')
        end

      end
    end.html_safe
  end

  def program_license_summary(program, program_term)
    content_tag(:em, :class => "dim") do
      if program.number_of_licenses.present?
        "feature.org_home_page.program_tile.header.license_usage".translate(licenses_count: program.number_of_licenses, users_count: program.all_users.active.count)
      else
        "feature.org_home_page.program_tile.header.active_users".translate(program: program_term, users_count: program.all_users.active.count)
      end
    end
  end

  def combine_overdue_ontrack_string(overdue, on_track)
    content_tag(:span, '(', class: 'large') + overdue +  content_tag(:span, on_track, class: 'divider-vertical') + content_tag(:span, ')', class: 'large')
  end

  def program_type(program, program_term)
    case program.program_type
    when Program::ProgramType::CHRONUS_MENTOR
      "feature.org_home_page.program_tile.header.mentoring_program".translate(program: program_term)
    when Program::ProgramType::CHRONUS_COACH
      "feature.org_home_page.program_tile.header.coaching_program".translate(program: program_term)
    when Program::ProgramType::CHRONUS_LEARN
      "feature.org_home_page.program_tile.header.learning_program".translate(program: program_term)
    end
  end

  def get_new_organization_wizard_view_headers
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::PROGRAM_DETAILS] = { label: "program_settings_strings.label.program_details".translate }
    wizard_info[Headers::ADMIN_ACCOUNT] = { label: "program_settings_strings.label.create_administrator_account".translate }
    wizard_info[Headers::COMPLETE_REGISTRATION] = { label: "program_settings_strings.label.complete_registration".translate }
    wizard_info
  end

  def get_organization_admin_actions(admin)
    actions = []
    actions << {:label => get_icon_content("fa fa-trash") + "feature.org_admins.action.remove_admin".translate, :url => organization_admin_path(admin), :method => :delete, data: {:confirm => "feature.org_admins.content.remove_admin_confirmation".translate(admin_name: admin.name, admin: _admin)} } if organization_view? &&  admin.no_owner_in_organization?
    actions << {:url => new_message_path(:receiver_id => admin.id, :source => "admin_listing"), :label => get_icon_content("fa fa-envelope") + "feature.org_admins.label.send_message".translate}
    return actions
  end

  def options_for_region
    [
      ["timezone.region.US".translate, HostingRegions::US],
      ["timezone.region.Europe".translate, HostingRegions::EUROPE]
    ] +
    (Rails.env.staging? ? [["display_string.Other".translate, HostingRegions::OTHER]] : [])
  end

  def can_render_select_region?
    Rails.env.production? ||  Rails.env.productioneu? || Rails.env.staging?
  end

  def error_messages_for_regions
    messages_hash = {}
    options_for_region.each do |region_name, hosting_region|
      messages_hash[hosting_region] = "program_settings_strings.content.select_region_error_flash_html".translate(url_link: link_to(HostingRegions::SUBDOMAIN_MAPPING[hosting_region], "https://#{HostingRegions::SUBDOMAIN_MAPPING[hosting_region]}", target: '_blank'), region: region_name)
    end
    messages_hash.to_json
  end

  def display_alert_messages_for_regions
    messages_hash = {}
    options_for_region.each do |region_name, hosting_region|
      messages_hash[hosting_region] = "program_settings_strings.content.select_region_notice_flash".translate(region_name: region_name)
    end
    messages_hash.to_json
  end

  def render_selected_region_alert
    return unless can_render_select_region?
    content_tag :div, "", class: "alert alert-warning hide m-t-md m-b-0 text-center font-bold", id: "cjs_selected_region_alert"
  end

  private

  def rollup_box_title(options = {})
    content_str = get_safe_string
    if options[:title]
      content_str << content_tag(:h4, class: "m-b-md") do
        title_content = get_safe_string
        title_content << options[:title]
        if options[:title_tooltip]
          title_content << ' '
          title_content << content_tag(:span, get_icon_content('fa fa-info-circle text-info'), class: options[:title_tooltip_class])
          title_content << tooltip(options[:title_tooltip_class], options[:title_tooltip], false, is_identifier_class: true, placement: 'bottom')
        end
        title_content << options[:title_right_addon]
        title_content
      end
    end
    content_str
  end

  def rollup_body_box_link_number(options = {})
    link_to(options[:link_number_path], class: "h2 font-600") do
      number_content = get_safe_string
      number_content << content_tag(:span, options[:link_number].to_s, class: "text-info")
      if options[:link_number_additional_html]
        number_content << " "
        number_content << options[:link_number_additional_html]
      end
      number_content
    end
  end

  def get_label_and_roles_content_for_enrollment_form(roles, program, options = {})
    label_text = options[:label] || "feature.enrollment.enroll".translate
    if options[:is_checkbox]
      [content_tag(:label, label_text, class: "col-sm-3 control-label false-label p-b-xxs"), get_role_checkboxes(roles, program, selected: roles, name: "roles[]")]
    else
      [label_tag("roles", label_text, class: "col-sm-3 control-label p-b-xxs"), select_tag("roles", options_for_join_as(program, roles), class: "form-control")]
    end    
  end

  def get_roles_to_join(user, options = {})
    user_roles = (user.present? && !user.suspended?) ? user.roles : []
    program_roles = options[:program_roles] || []
    program_roles - user_roles - Array(options[:prog_mem_req_pending_roles])
  end

  def get_disabled_list(prog_or_org)
    disabled_list = []
    FeatureName.dependent_features.each_pair do |feature_name, status_hash|
      if prog_or_org.has_feature?(feature_name)
        disabled_list += status_hash.values.flatten
      end
    end
    if prog_or_org.is_a?(Program) && prog_or_org.project_based?
      disabled_list += FeatureName.specific_dependent_features[:project_based].values.flatten
    end
    disabled_list
  end
end
