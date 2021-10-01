module GroupsHelper
  # Renders the status of the connection if not Group::Status::ACTIVE
  TRUNCATE_ATTACHMENT_STRING_LENGTH = 15
  PENDING_PROJECT_DAYS = 7
  MAX_CONNECTION_QUESTIONS_FOR_VIEW = 3
  MAX_MEMBERS_FOR_VIEW = 2
  DEFAULT_AVAILABLE_TO_JOIN_FILTER = "available_projects"
  GROUPS_ALERT_FLAG_NAME = "groups_alert_flag_shown"

  module Headers
    DESCRIBE_MENTORING_CONNECTION = 1
    ADD_MEMBERS = 2
  end

  module AnalyticsParams
    FILTER_GROUPS_LISTING = "filter_groups_listing"
  end

  # Writing this as a method instead of a constant, because there are translations
  def display_group_status_label_content
    {
      Group::Status::DRAFTED => ["feature.connection.header.status.Drafted".translate, ""],
      Group::Status::PENDING => ["feature.connection.header.status.Available".translate, "label-info"]
    }
  end

  def group_status_rows(group)
    if group.closed?
      # If not auto-termination and closed_by is nil, then say 'Admin'
      closing_info = group.auto_terminated? ? "feature.connection.content.auto_closed".translate : (group.closed_by.nil? ? _Admin : link_to_user(group.closed_by))
      closed_at = "#{formatted_time_in_words(group.closed_at, :no_ago => false)}"

      return [
        { label: "feature.connection.content.Closed_by".translate, content: closing_info },
        { label: "feature.connection.content.Closed_on".translate, content: closed_at },
        { label: "feature.connection.content.Reason".translate, content: group.closure_reason.reason }
      ]
    end
  end

  def can_write_to_group?(group, actor)
    group.has_member?(actor) && group.active? && !group.expired?
  end

  def connection_last_activity_time(group, user)
    last_activity = group.activities.last(:conditions => {:user_id => user.id})
    return unless last_activity

    content_tag(:span, :class => 'last_login') do
      "feature.connection.content.last_activity_time".translate(time: formatted_time_in_words(last_activity.created_at, :absolute => true, :no_time => true))
    end
  end

  def get_member_pictures(group)
    member_pictures = []
    if !group.logo?
      member_pictures << user_picture(current_user,  {:row_fluid => true, size: :small, no_name: true, new_size: :tiny, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION}, {:size => "21x21", :class => 'm-l-n-xs'})
      group.members.each do |user|
        if current_user != user
          member_pictures << user_picture(user,  {:row_fluid => true, size: :small, no_name: true, new_size: :tiny, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION}, {:size => "21x21", :class => 'm-l-n-xs'})
        end
      end
    else
      member_pictures << image_tag(group.logo_url, class: "img-circle m-l-n-xs", size: "46x43", override_size: :tiny)
    end
    member_pictures
  end

  def get_url_for_group_actions_form(source, action, url_options = {id: nil})
    options = { controller: :groups, action: action, only_path: true }
    if ["member_groups", EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET, GroupsController::ReactivationSrc::LISTING_PAGE, GroupsController::ReactivationSrc::NOTICE, GroupsController::ReactivationSrc::MAIL].include?(source)
      url_for(options.merge(src: source, format: :js, id: url_options[:id], ga_src: url_options[:ga_src]))
    elsif source == "profile"
      url_for(options.merge(src: source, id: url_options[:id]))
    else
      url_for(options.merge(format: :js, id: url_options[:id]))
    end
  end

  def get_mentor_request_popup_footer(slots_available, connection_count, connection_permission)
    change_link = ""
    if connection_permission != Program::ConnectionLimit::NONE
      change_link = link_to("display_string.Change".translate, edit_member_path(wob_member, scroll_to: "user_max_connections_limit", focus_settings_tab: true))
    end
    content_tag(:div, class: "text-center text-muted", style: "font-weight:bold") do
      if (slots_available <= 0)
        "feature.mentor_request.footer.accepted_request_footer_limit_reached_html".translate(mentoring: _mentoring, count: connection_count, Change: change_link)
      else
        "feature.mentor_request.footer.accepted_request_footer_html".translate(mentoring: _mentoring, connection_limit: slots_available, count: connection_count, Change: change_link)
      end
    end
  end

  def group_creation_email_notification_consequences_html(options = {})
    program = options[:program] || current_program
    if program.project_based?
      email_notification_consequences_on_action_html(GroupPublishedNotification, div_enclose: true, div_class: "m-b-sm", with_count: true, count: options[:count] || 1)
    else
      email_notification_consequences_for_multiple_mailers_html([GroupCreationNotificationToMentor, GroupCreationNotificationToStudents, GroupCreationNotificationToCustomUsers])
    end
  end

  def groups_sort_fields(most_active_first = true)
    if @is_pending_connections_view
      sort_fields = [
        {:field => "active", :order => :desc, :label => "feature.connection.header.Recently_active".translate},
        {:field => "pending_at", :order => :desc, :label => "feature.connection.header.available_since".translate},
      ]
    elsif @is_withdrawn_connections_view
      sort_fields = [
        {:field => "closed_at", :order => :desc, :label => "feature.connection.header.withdrawn_date_with_order".translate(order: "display_string.recent_first".translate)},
        {:field => "closed_at", :order => :asc, :label => "feature.connection.header.withdrawn_date_with_order".translate(order: "display_string.oldest_first".translate)}
      ]
    elsif @is_proposed_connections_view
      sort_fields = [
        {:field => "created_at", :order => :desc, :label => "feature.connection.header.proposed_date_with_order".translate(order: "display_string.recent_first".translate)},
        {:field => "created_at", :order => :asc, :label => "feature.connection.header.proposed_date_with_order".translate(order: "display_string.oldest_first".translate)}
      ]
    elsif @is_rejected_connections_view
      sort_fields = [
        {:field => "created_at", :order => :desc, :label => "feature.connection.header.proposed_date_with_order".translate(order: "display_string.recent_first".translate)},
        {:field => "created_at", :order => :asc, :label => "feature.connection.header.proposed_date_with_order".translate(order: "display_string.oldest_first".translate)},
        {:field => "closed_at", :order => :desc, :label => "feature.connection.header.rejected_date_with_order".translate(order: "display_string.recent_first".translate)},
        {:field => "closed_at", :order => :asc, :label => "feature.connection.header.rejected_date_with_order".translate(order: "display_string.oldest_first".translate)}
      ]
    else
      if most_active_first
        sort_fields = [
          {:field => "active",        :order => :desc,   :label => "feature.connection.header.Recently_active".translate},
          {:field => "activity",        :order => :desc,  :label => "feature.connection.header.Most_active".translate},
          {:field => "connected_time",  :order => :desc,   :label => "feature.connection.header.Recently_connected".translate},
          {:field => "expiry_time",        :order => :asc,   :label => "feature.connection.header.Expiration_time".translate}]
      else
        sort_fields = [
          {:field => "connected_time",  :order => :desc,   :label => "feature.connection.header.Recently_connected".translate},
          {:field => "activity",        :order => :desc,  :label => "feature.connection.header.Most_active".translate},
          {:field => "activity",        :order => :asc,   :label => "feature.connection.header.Least_active".translate},
          {:field => "active",        :order => :desc,   :label => "feature.connection.header.Recently_active".translate},
          {:field => "expiry_time",        :order => :asc,   :label => "feature.connection.header.Expiration_time".translate}]
      end
    end

    return sort_fields
  end

  def email_notification_consequences_in_group_manage_members_html(group)
    return get_safe_string unless group.active? || group.pending?
    program = group.program
    addition_mailer, removal_mailer = group.pending? ? [PendingGroupAddedNotification, PendingGroupRemovedNotification] : [GroupMemberAdditionNotificationToNewMember, GroupMemberRemovalNotificationToRemovedMember]
    addition_notification_enabled, removal_notification_enabled = [addition_mailer, removal_mailer].map{ |mailer| !program.email_template_disabled_for_activity?(mailer) }
    added_link = email_notification_consequences_on_action_html(addition_mailer, email_link_text: "display_string.added".translate, return_email_link_only: true)
    removed_link = email_notification_consequences_on_action_html(removal_mailer, email_link_text: "display_string.removed".translate, return_email_link_only: true)
    content_tag(:div, class: "m-b-sm hide cjs_member_update_info") do
      if (addition_notification_enabled && removal_notification_enabled)
        "feature.group.content.group_manage_email_notif.both_enabled_html".translate(added: added_link, removed: removed_link, mentoring_connection: _mentoring_connection)
      elsif (!addition_notification_enabled && !removal_notification_enabled)
        "feature.group.content.group_manage_email_notif.both_disabled_html".translate(added: added_link, removed: removed_link, mentoring_connection: _mentoring_connection)
      else
        action_enabled, action_disabled = addition_notification_enabled ? [added_link, removed_link] : [removed_link, added_link]
        "feature.group.content.group_manage_email_notif.hybrid_case_html".translate(action_enabled: action_enabled, action_disabled: action_disabled)
      end
    end
  end

  def display_group_in_auto_complete(group)
    program_roles = RoleConstants.program_roles_mapping(group.program, pluralize: true)
    contents = []
    group.memberships.includes(:role, [:user => :member]).group_by(&:role).each do |role, memberships|
      contents << program_roles[role.name] + ":    " + truncate(h(memberships.collect(&:user).flatten.collect(&:name).to_sentence), length: 45)
    end
    safe_join(contents, tag(:br))
  end

  def display_project_based_group_in_auto_complete(group, group_roles)
    group_details = [content_tag(:b, group.name), get_role_limits(group, group_roles)]
    group_details = safe_join(group_details, tag(:div, class: "m-b-xs"))
    logo = content_tag(:br, image_tag(group.logo_url, { class: "media-object img-circle", size: "50x50"}))
    label = content_tag(:br, get_group_label_for_auto_complete(group))
    content = content_tag(:div, logo, class: "col-xs-2") + content_tag(:div, group_details, class: "col-xs-6") + content_tag(:div, label, class: "col-xs-4")
    content_tag(:div, content, class: "clearfix")
  end

  def display_selected_group_in_auto_complete(group)
    truncate(group.members.collect(&:name).to_sentence(:last_word_connector => " #{'display_string.and'.translate} "), :length => 45)
  end

  def get_profile_filter_wrapper_for_groups(title, is_reports_view=false)
    is_reports_view ? {render_panel: false, hide_header_title: true, header_content: content_tag(:b, title), class: "social-feed-box"} : {}
  end

  def get_input_group_options(is_reports_view=false)
    is_reports_view ? {class: "hide"} : {}
  end

  def collapsible_group_search_filter(title, search_params_hash, is_reports_view=false)
    input_id = "search_filters_profile_name"
    value = search_params_hash.try(:[], :profile_name)
    input_group_class_options = is_reports_view ? {input_group_class: "col-xs-12"} : {}
    profile_filter_wrapper(title, value.blank?, true, false, get_profile_filter_wrapper_for_groups(title, is_reports_view)) do
      construct_input_group({}, groups_filter_input_group_submit_options(get_input_group_options(is_reports_view)), input_group_class_options) do
        label_tag(:search_filters, title, for: input_id, class: 'sr-only') +
        text_field(:search_filters, :profile_name, value: value, id: input_id, class: "form-control input-sm", placeholder: "feature.reports.content.enter_connection_name".translate(connection: _mentoring_connection)) +
        link_to_function("display_string.Clear".translate, %Q[jQuery("##{input_id}").val(""); GroupSearch.applyFilters();], class: 'clear_filter btn btn-xs hide', id: "reset_filter_profile_name")
      end
    end
  end

  def show_role_availability_slot_filters?(program, is_manage_connections_view, tab_number)
    program.project_based? && is_manage_connections_view && slots_availability_filter_allowed_tab?(tab_number) && program.roles.for_mentoring.any? { |role| role.slot_config_enabled? }
  end

  def slots_availability_filter_allowed_tab?(tab_number)
    Group::Status.slots_availability_filter_allowed_states.include?(tab_number)
  end

  def collapsible_group_role_slots_filter_inner_builder(program, title, key, value)
    html_id = "search_filters_#{key}"
    label_tag(:search_filters, title, for: html_id, class: 'sr-only') +
    label_tag(:search_filters, title, for: (html_id + "_tmp"), class: 'sr-only') +
    select_tag("search_filters[#{key}]", options_for_select(RoleConstants.program_roles_mapping(program, roles: program.roles.for_mentoring).invert.to_a, value), multiple: true, id: html_id, class: "form-control input-sm no-padding no-border") +
    link_to("display_string.Clear".translate, "javascript:void(0)", class: 'clear_filter btn btn-xs hide', id: "reset_filter_#{key}") +
    javascript_tag("jQuery('#reset_filter_#{key}').on('click', function(){jQuery('##{html_id}').select2('val', '');GroupSearch.applyFilters(); });") +
    javascript_tag("jQuery('##{html_id}').select2(); jQuery('label[for=#{(html_id + "_tmp")}]').attr('for', '#{html_id}');")
  end

  def collapsible_group_role_slots_filter(program, search_params_hash, is_reports_view=false)
    slots_available_value   = search_params_hash.try(:[], :slots_available)
    slots_unavailable_value = search_params_hash.try(:[], :slots_unavailable)
    collapsed               = (slots_available_value || slots_unavailable_value).nil?
    title = "feature.connection.header.mentoring_connection_slots_availability".translate(Mentoring_Connection: _Mentoring_Connection)

    profile_filter_wrapper(title, collapsed, true, false, get_profile_filter_wrapper_for_groups(title, is_reports_view)) do
      content_tag(:div, "feature.connection.header.slots_available_for".translate) +
      construct_input_group do
        collapsible_group_role_slots_filter_inner_builder(program, "feature.connection.header.slots_available_for".translate, :slots_available, slots_available_value) +
        content_tag(:span, "display_string.AND".translate, class: "input-group-addon no-border p-r-0")
      end +
      content_tag(:div, "feature.connection.header.slots_unavailable_for".translate, class: "m-t-sm") +
      construct_input_group([], groups_filter_input_group_submit_options) do
        collapsible_group_role_slots_filter_inner_builder(program, "feature.connection.header.slots_unavailable_for".translate, :slots_unavailable, slots_unavailable_value)
      end
    end
  end

  # only admin users are allowed for autocomplete search
  def collapsible_group_member_filters(program, options = {})
    role_terms = RoleConstants.program_roles_mapping(program)
    content = []
    can_manage_view = options.delete(:can_manage_view)
    program.roles.for_mentoring.each_with_index do |role, index|
      title = role_terms[role.name]
      value = @member_filters.present? ? (@member_filters[role.id.to_s] || "") : ""
      content << profile_filter_wrapper(title, !value.present?, true, false, get_profile_filter_wrapper_for_groups(title, options[:is_reports_view])) do
        label_tag("member_filters[#{role.id}]", title, :for => "member_filters_#{role.id}", :class => 'sr-only') +
        if can_manage_view
          text_field_with_auto_complete(nil, nil,
            {
              :name => "member_filters[#{role.id}]",
              :class => "form-control input-sm",
              :id => "member_filters_#{role.id}",
              :value => value,
              :right_addon => groups_filter_input_group_submit_options(get_input_group_options(options[:is_reports_view])),
              :autocomplete => "off",
              placeholder: "feature.reports.content.meeting_calendar_report_attendee_filter_placeholder".translate
            },
            {
              :url => auto_complete_for_name_users_path(format: :json, role: role.name, show_all_users: true, for_autocomplete: true),
              :highlight => true,
              :param_name => 'search'
            }
          )
        else
          construct_input_group({}, groups_filter_input_group_submit_options(get_input_group_options(options[:is_reports_view]))) do
            text_field_tag("member_filters[#{role.id}]", value, class: "form-control input-sm")
          end
        end +
        link_to_function("display_string.Clear".translate, %Q[jQuery("#member_filters_#{role.id}").val(""); GroupSearch.applyFilters();], :class => 'clear_filter btn btn-xs hide', :id => "reset_filter_member_filter_#{role.id}")
      end
    end
    safe_join(content, " ")
  end

  def get_group_member_profile_filters_base_details(program)
    [RoleConstants.program_roles_mapping(program), program.organization.skype_enabled?, program.roles.for_mentoring]
  end

  def collapsible_group_member_profile_filters(program, options = {})
    role_terms, is_skype_enabled, roles_for_mentoring = get_group_member_profile_filters_base_details(program)
    content = []
    roles_for_mentoring.each_with_index do |role|
      content << get_collapsible_group_member_profile_filters_container(options.merge({
        title: "feature.connection.content.role_profile_fields".translate(role_name: role_terms[role.name]),
        value: (@member_profile_filters.present? ? (@member_profile_filters[role.id.to_s] || "") : ""),
        inner_content: group_member_profile_filters_inner_content(program, role, is_skype_enabled, options.merge({class_name: ".cjs_role_profile_filter_container_#{role.id}"}))
      }))
    end
    safe_join(content, " ") + get_report_filter_common_partial(program, roles_for_mentoring, is_skype_enabled, @member_profile_filters)
  end

  def get_report_filter_common_partial(program, roles_for_mentoring, is_skype_enabled, member_profile_filters)
    render(partial: "surveys/report_filters_common_js", locals: {profile_questions: program.profile_questions_for(roles_for_mentoring.map(&:name), {default: false, skype: is_skype_enabled, fetch_all: true, pq_translation_include: true}), initialize_member_profile_filters: member_profile_filters.present?})
  end

  def get_safe_member_profile_filters(member_profile_filters)
    safe_member_profile_filters = {}
    member_profile_filters.each do |key, value|
      safe_member_profile_filters[key] = []
      value.each do |value_hash|
        copy_hash = {}
        value_hash.each do |hash_key, hash_value|
          copy_hash[j(hash_key)] = j(hash_value)
        end
      safe_member_profile_filters[key] << copy_hash
      end
    end
    safe_member_profile_filters
  end

  def get_collapsible_group_member_profile_filters_container(options = {})
    title = options[:title]
    profile_filter_wrapper(title, !options[:value].present?, true, false, get_profile_filter_wrapper_for_groups(title, options[:is_reports_view])) do
      options[:inner_content]
    end
  end

  def group_member_profile_filters_inner_content(program, role, is_skype_enabled, options = {})
    content_html = render(partial: "surveys/render_survey_and_profile_questions_filter", locals: {
      survey: nil,
      questions: program.profile_questions_for([role.name], {default: false, skype: is_skype_enabled, fetch_all: true, pq_translation_include: true}),
      is_survey_type: false,
      scope: "member_profile_filters[#{role.id}][]",
      role_id: role.id,
      prefix: "profile_#{role.id}"
    })
    content_html << construct_input_group_addon(groups_filter_input_group_submit_options(get_input_group_options(options[:is_reports_view])))
    content_html << link_to_function("display_string.Clear".translate, %Q[ReportFilters.clearFilters("#{options[:class_name]}"); GroupSearch.applyFilters();], class: 'clear_filter btn btn-xs hide', id: "reset_filter_member_profile_filter_#{role.id}")
    content_html
  end

  def get_status_filter_fields_v2(sub_filter, not_started, closed_filter, options = {})
    filter_fields = []
    filter_fields << {
      status_value: not_started || false,
      value: GroupsController::StatusFilters::NOT_STARTED,
      label: "feature.connection.header.group_status.not_started".translate,
      checkbox_id: "not_started"
    }
    filter_fields << {
      status_value: (sub_filter.blank? || sub_filter["inactive"].present?),
      value: GroupsController::StatusFilters::Code::INACTIVE,
      label: "feature.connection.header.group_status.started_inactive".translate,
      checkbox_id: "inactive"
    }
    filter_fields << {
      status_value: (sub_filter.blank? || sub_filter["active"].present?),
      value: GroupsController::StatusFilters::Code::ACTIVE,
      label: "feature.connection.header.group_status.started_active".translate,
      checkbox_id: "active"
    }
    if options[:add_closed_filter]
      filter_fields << {
        status_value: closed_filter || false,
        value: GroupsController::StatusFilters::Code::CLOSED,
        label: "feature.connection.header.status.Closed".translate,
        checkbox_id: "closed"
      }
    end
    filter_fields
  end

  def generate_collapsible_status_links(sub_filter, not_started, options)
    sub_filter_fields = get_status_filter_fields_v2(sub_filter, not_started, options.delete(:closed_filter), add_closed_filter: options.delete(:add_closed_filter))
    status_links = []
    arr = sub_filter_fields.map { |a| a[:status_value] }
    collapsed = (arr.uniq.size == 1)
    title = "feature.connection.header.status.Status".translate
    options.merge!(get_profile_filter_wrapper_for_groups(title, options[:is_reports_view]))
    profile_filter_wrapper(title, collapsed, true, true, options) do
      sub_filter_fields.each do |sub_filter_field|
        check_box_id = "sub_filter[#{sub_filter_field[:checkbox_id]}]"
        status_links << content_tag(:label, class: "checkbox cjs_group_status_sub_filters") do
          check_box_tag(check_box_id, sub_filter_field[:value], sub_filter_field[:status_value], onclick: %Q[GroupSearch.applyFilters();]) + " " + sub_filter_field[:label]
        end
      end
      status_links << link_to_function("feature.connection.action.reset".translate, "GroupSearch.resetStatusFilters();GroupSearch.applyFilters();", id: "reset_filter_status", style: 'display:none;')
      safe_join(status_links, "")
    end
  end

  def get_leave_connection_popup_head_text(is_terminate_action, type)
    if type == "head"
      is_terminate_action ? "quick_links.side_pane.close_mentoring_connection".translate(mentoring_connection: _Mentoring_Connection) : "quick_links.side_pane.leave_mentoring_connection".translate(mentoring_connection: _Mentoring_Connection)
    elsif type == "content"
      is_terminate_action ? "quick_links.side_pane.closing_the_mentoring_connection".translate(mentoring_connection: _Mentoring_Connection) : "quick_links.side_pane.leaving_the_mentoring_connection".translate(mentoring_connection: _Mentoring_Connection)
    end
  end

  def get_notice_text(group, user, connection_term, admin_term)
    notice_text = get_safe_string +
      if group.expired?
        @can_reactivate = group.can_be_reactivated_by_user?(user)
        if @can_reactivate
          "feature.connection.content.notice.expired_v2_html".translate(mentoring_connection: _mentoring_connection, connection_name: group.name, click_link: (link_to_function "display_string.here".translate, %Q[jQueryShowQtip(null, null, "#{fetch_reactivate_group_path(group, src: GroupsController::ReactivationSrc::NOTICE)}", {})]) )
        else
          "feature.connection.content.notice.expired_v1".translate(mentoring_connection: _mentoring_connection)
        end
      elsif group.about_to_expire?
        "feature.connection.content.notice.about_to_expire_v1".translate(time_period: distance_of_time_in_words(Time.now, group.expiry_time), :mentoring_connection => _mentoring_connection)
      elsif group.recently_reactivated?
        "feature.connection.content.notice.recently_reactivated".translate(connection: connection_term, time_period: distance_of_time_in_words(Time.now, group.expiry_time))
      elsif group.recently_expiry_date_changed?
        "feature.connection.content.notice.recently_expiry_date_changed_v1".translate(connection: connection_term, time_period: distance_of_time_in_words(Time.now, group.expiry_time))
      end
    if (group.expired? || group.about_to_expire?) && !user.is_admin? && !user.program.allow_to_change_connection_expiry_date? && !@can_reactivate
      action_url = contact_admin_path(req_change_expiry: true, group_id: group.id)
      action_id = "request_expiry_date_from_flash_#{group.id}"
      notice_text += "feature.connection.content.notice.Contact_admin_to_extend_v1_html".translate(Contact_Admin: link_to_function("feature.connection.action.Contact_Admin".translate(admin_term: admin_term), %Q[jQueryShowQtip('#cjs_connection_summary', 600, '#{action_url}','',{modal: true})], id: action_id), mentoring_connection: _mentoring_connection)
    end
    return notice_text
  end

  def get_group_notes_content(group, v2_enabled, options = {})
    if group.notes.present?
      if v2_enabled
        build_popover_with_content(options[:id], (get_icon_content("fa fa-file-text-o") + set_screen_reader_only_content("feature.connection.header.View_Notes_v1".translate)), "feature.connection.header.Notes_by_administrator".translate(admin: _admin), group.notes, class: "text-default")
      else
        embed_display_line_item("feature.connection.header.Notes".translate, group.notes)
      end
    end
  end

  def build_popover_with_content(id, link, title, content, options = {})
    if content.present?
      link_to(link, 'javascript:void(0)', class: options[:class]) + popover("##{id}", title, auto_link(content))
    end
  end

  def get_group_expiry_content(group, v2_enabled = false, options = {})
    options.reverse_merge!(show_expired_text: true)
    if v2_enabled
      content = formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)
      content << expired_text(class: "m-l-xs") if group.about_to_expire? && group.active? && options[:show_expired_text]
      content_tag(:span, content.html_safe, :class => "groups_expires_in")
    else
      label = "feature.connection.header.Expires_in".translate
      content = distance_of_time_in_words(Time.now, group.expiry_time) + " (#{formatted_time_in_words(group.expiry_time, no_ago: true, no_time: true)})"
      content << expired_text(class: "m-l-xs") if group.about_to_expire? && options[:show_expired_text]
      content = append_text_to_icon("fa fa-clock-o", content.html_safe)
      if options[:only_values]
        return [label, content]
      else
        embed_display_line_item(label, content)
      end
    end
  end

  def get_groups_bulk_actions_box(tab_number, view, program)
    bulk_actions = [:label => append_text_to_icon("fa fa-envelope", "display_string.Send_Message".translate), :url => "javascript:void(0)", :class => "cjs_bulk_action_groups",
        :data => {:url => new_bulk_admin_message_admin_messages_path(:for_groups => true)}]
    additional_actions = case tab_number
    when Group::Status::DRAFTED, Group::Status::PENDING
      actions = if (tab_number == Group::Status::DRAFTED) && program.project_based?
        [{label: append_text_to_icon("fa fa-check", "feature.connection.action.Make_Available".translate(Mentoring_Connection: _Mentoring_Connections)), url: "javascript:void(0)", class: "cjs_bulk_action_groups", data: {url: fetch_bulk_actions_groups_path, action_type: Group::BulkAction::MAKE_AVAILABLE}}]
      else
        [{:label => append_text_to_icon("fa fa-check", "feature.connection.action.Publish_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)), :url => "javascript:void(0)", :class => "cjs_bulk_action_groups", :data => {:url => fetch_bulk_actions_groups_path, :action_type => Group::BulkAction::PUBLISH}}]
      end
      if tab_number == Group::Status::PENDING && program.project_based?
        actions << [{:label => append_text_to_icon("fa fa-undo", "feature.connection.action.Withdraw_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)), :class => "cjs_bulk_action_groups", :url => "javascript:void(0)", :data => {:url => fetch_bulk_actions_groups_path, :action_type => Group::BulkAction::WITHDRAW_PROPOSAL}}]
      end
      if tab_number == Group::Status::DRAFTED
        actions << {:label => append_text_to_icon("fa fa-trash", "feature.connection.action.Discard_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)), :url => "javascript:void(0)", :class => "cjs_bulk_action_groups", :data => {:url => fetch_bulk_actions_groups_path, :action_type => Group::BulkAction::DISCARD}}
      end
      if program.mentoring_connections_v2_enabled?
        actions << {label: append_text_to_icon("fa fa-check", "feature.connection.action.Assign_Template_v1".translate(Mentoring_Connection: _Mentoring_Connection)), url: "javascript:void(0)", class: "cjs_bulk_action_groups", data: {url: fetch_bulk_actions_groups_path, action_type: Group::BulkAction::ASSIGN_TEMPLATE, tab_number: Group::Status::DRAFTED}}
      end
      actions
    when Group::Status::PROPOSED
      [
        {label: append_text_to_icon("fa fa-check", "feature.connection.action.accept_and_mark_available".translate), url: "javascript:void(0)", class: "cjs_bulk_action_groups", data: {url: fetch_bulk_actions_groups_path, action_type: Group::BulkAction::ACCEPT_PROPOSAL, tab_number: Group::Status::PROPOSED}},
        {label: append_text_to_icon("fa fa-ban", "feature.connection.action.reject".translate(Mentoring_Connection: _Mentoring_Connection)), url: "javascript:void(0)", class: "cjs_bulk_action_groups", data: {url: fetch_bulk_actions_groups_path, action_type: Group::BulkAction::REJECT_PROPOSAL, tab_number: Group::Status::PROPOSED}}
      ]
    when Group::Status::CLOSED
      get_closed_group_actions(program)
    when Group::Status::ACTIVE, Group::Status::INACTIVE
      [
        {:label => append_text_to_icon("fa fa-calendar", "feature.connection.action.Set_Expiration_Date".translate), :class => "cjs_bulk_action_groups", :url => "javascript:void(0)", :data => {:url => fetch_bulk_actions_groups_path(view: view), :action_type => Group::BulkAction::SET_EXPIRY_DATE, :tab_number => tab_number}},
        {:label => append_text_to_icon("fa fa-ban", "feature.connection.action.Close_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)), :class => "cjs_bulk_action_groups", :url => "javascript:void(0)", :data => {:url => fetch_bulk_actions_groups_path, :action_type => Group::BulkAction::TERMINATE}}
      ]
    end
    private_notes_action = {
      label: append_text_to_icon("fa fa-file-text-o", "feature.connection.action.Add_or_Update_Notes".translate), class: "cjs_single_action_groups",
      js: %Q[GroupSearch.checkAndSendSingleTypeAction('#bulk_action_private_notes', '#{fetch_notes_group_path(-1, view: view)}', 470);],
      id: "bulk_action_private_notes"
    }
    add_remove_member_action = Proc.new{ |tab|
      {
        label: append_text_to_icon("fa fa-users", "feature.connection.action.manage_members_v1".translate), class: "cjs_single_action_groups",
        js: %Q[GroupSearch.checkAndSendSingleTypeAction('#bulk_action_add_remove_#{tab.to_s}', '#{edit_group_path(-1, tab: tab, view: view, is_table_view: "true")}', 600);],
        id: "bulk_action_add_remove_#{tab.to_s}"
      }
    }
    add_remove_owner_action = [{
        label: append_text_to_icon("fa fa-user-plus", "feature.connection.action.update_owners".translate),
        js: %Q[GroupSearch.checkAndSendSingleTypeAction('#bulk_action_update_owners', '#{fetch_owners_group_path(-1, format: :js, from_index: :true, tab: tab_number, view: view)}', 600);],
        id: "bulk_action_update_owners", class: "cjs_single_action_groups"
    }]
    single_type_actions = []
    additional_actions ||= []
    single_type_actions = [private_notes_action] unless [Group::Status::REJECTED, Group::Status::WITHDRAWN].include?(tab_number)
    single_type_actions << add_remove_member_action.call(tab_number) if [Group::Status::ACTIVE, Group::Status::DRAFTED, Group::Status::PENDING].include?(tab_number) && current_program_or_organization.allow_one_to_many_mentoring?
    single_type_actions << add_remove_owner_action unless ([Group::Status::DRAFTED, Group::Status::CLOSED, Group::Status::REJECTED, Group::Status::WITHDRAWN].include?(tab_number) || !program.project_based?)
    additional_actions << {:label => append_text_to_icon("fa fa-download", "feature.connection.action.Export_Connections".translate(Mentoring_Connections: _Mentoring_Connections)), :class => "cjs_bulk_action_groups", :url => "javascript:void(0)", :data => {:url => fetch_bulk_actions_groups_path, :action_type => Group::BulkAction::EXPORT, :tab_number => tab_number}}
    build_dropdown_button("display_string.Actions".translate, bulk_actions + additional_actions + single_type_actions, btn_group_btn_class: "btn-sm btn-white", :is_not_primary => true)
  end

  def get_discard_connection_action(group, source)
    text = group.closed? ? "feature.connection.action.delete_connection" : "feature.connection.action.Discard_Connection_v1"
    {
      label: append_text_to_icon("fa fa-trash", text.translate(Mentoring_Connection: _Mentoring_Connection)),
      js: %Q[jQueryShowQtip('#group_#{group.id}', 470, '#{fetch_discard_group_path(group, src: source)}','',{modal: true})],
      id: "discard_group_#{group.id}"
    }
  end

  def get_discard_group_header_help_button_text(group)
    if group.closed?
      return "feature.connection.header.delete_connection".translate(Mentoring_Connection: _Mentoring_Connection, connection_name: @group.name), "feature.connection.content.help_text.delete_connection".translate(mentoring_connection: _mentoring_connection), "display_string.Delete".translate
    else
      return "feature.connection.header.discard_connection".translate(Mentoring_Connection: _Mentoring_Connection, connection_name: @group.name), "feature.connection.content.help_text.discard_connection".translate(mentoring_connection: _mentoring_connection), "display_string.Discard".translate
    end
  end

  def mentoring_area_right_pane_see_all(path_url, count)
    content_tag(:span, :class => "#{'divider-vertical' if @page_controls_allowed} pull-right") do
      link_to "display_string.See_all_with_count".translate(object_count: count), path_url
    end
  end

  def mentoring_area_right_pane_add_new(path_url, add_new_text, other_options = {})
    content_tag(:span, :class => "font-bold") do
      link_to("feature.connection.action.Add_New_Object".translate(Object: add_new_text), path_url, other_options)
    end
  end

  def get_group_cannot_be_reactivated_text(program, inconsistent_roles)
    return content_tag(:p, "feature.group.group_cannot_be_reactivated".translate(reason: get_inconsistent_roles_reason(program, inconsistent_roles)))
  end

  def get_group_cannot_be_duplicated_text(program, inconsistent_roles)
    return content_tag(:p, "feature.group.group_cannot_be_duplicated".translate(mentoring_connection: _mentoring_connection, reason: get_inconsistent_roles_reason(program, inconsistent_roles)))
  end

  def get_tab_box(tab_number, view, counts, settings, show_parameter)
    tab_link_proc = Proc.new do |tab_number__local, tab_string, options = {}|
      connection_count = content_tag(:span, counts[tab_string.to_sym].to_s, id: "cjs_#{tab_string}_count")
      label = (options[:label_key] || "feature.connection.header.#{tab_string}_html").translate(connection_count: connection_count)
      tab_params = groups_listing_filter_params.merge(
        tab: tab_number__local,
        view: view,
        show: show_parameter
      )
      content_tag(:li, class: "#{(tab_number.to_i == tab_number__local) ? 'ct_active active' : ''}", id: "#{tab_string}_tab") do
        link_to label, groups_path(tab_params)
      end
    end

    content = get_safe_string
    content << tab_link_proc.call(Group::Status::DRAFTED, "drafted") if settings[:show_drafted_tab]
    content << tab_link_proc.call(Group::Status::PROPOSED, "proposed") if settings[:show_proposed_tab]
    content << tab_link_proc.call(Group::Status::PENDING, "pending", label_key: "feature.connection.header.available_html") if settings[:show_pending_tab]
    content << tab_link_proc.call(Group::Status::ACTIVE, settings[:show_open_tab] ? "open" : "ongoing")
    content << tab_link_proc.call(Group::Status::CLOSED, "closed")
    content << tab_link_proc.call(Group::Status::REJECTED, "rejected") if settings[:show_rejected_tab]
    content << tab_link_proc.call(Group::Status::WITHDRAWN, "withdrawn") if settings[:show_withdrawn_tab]

    content_tag(:ul, class: "nav nav-tabs h5 no-margins", id: "tab-box") do
      content
    end
  end

  def groups_listing_filter_params
    filter_params = [:search_filters, :member_filters, :connection_questions, :sub_filter, :member_profile_filters]
    return group_params.to_unsafe_h.slice(*filter_params)
  end

  def groups_have_third_role_user?(groups)
    groups.collect(&:custom_users).flatten.size > 0
  end

  def reset_groups_listing_filter_params
    return {
      search_filters: {},
      member_filters: {},
      member_profile_filters: {},
      connection_questions: {},
      sub_filter: {}
    }
  end

  def group_settings_hash(manage_connections_view, open_connections_view, user, options = {})
    admin_manage_connections = !!manage_connections_view
    end_user_open_connections = !!open_connections_view
    proposed_rejected_groups = options[:counts] && ((options[:counts][:proposed].to_i + options[:counts][:rejected].to_i) > 0)
    withdrawn_groups = (admin_manage_connections || end_user_open_connections) && options[:counts] && ((options[:counts][:pending].to_i + options[:counts][:withdrawn].to_i) > 0)
    permission_to_propose_groups = @current_program.mentoring_roles_with_permission(RolePermission::PROPOSE_GROUPS).exists?
    admin_proposed_rejected_tabs = admin_manage_connections && (proposed_rejected_groups || permission_to_propose_groups)
    end_user_proposed_rejected_tabs = end_user_open_connections && user.can_propose_groups?

    {
      show_drafted_tab: admin_manage_connections,
      show_pending_tab: admin_manage_connections && @current_program.project_based?,
      show_open_tab: end_user_open_connections && @current_program.project_based?,
      show_withdrawn_tab: !!withdrawn_groups && @current_program.project_based?,
      show_proposed_tab: @current_program.project_based? && (admin_proposed_rejected_tabs || end_user_proposed_rejected_tabs) && user.can_be_shown_proposed_groups?,
      show_rejected_tab: @current_program.project_based? && (admin_proposed_rejected_tabs || end_user_proposed_rejected_tabs) && user.can_be_shown_proposed_groups?
    }
  end

  def get_task_status_custom_filter_text_when_filters_are_applied(operators)
    count = operators.count
    case operators.uniq
    when ["#{MentoringModel::Task::StatusFilter::COMPLETED}"]
      "feature.mentoring_model.label.n_completed_tasks".translate(count: count)
    when ["#{MentoringModel::Task::StatusFilter::NOT_COMPLETED}"]
      "feature.mentoring_model.label.n_not_completed_tasks".translate(count: count)
    when ["#{MentoringModel::Task::StatusFilter::OVERDUE}"]
      "feature.mentoring_model.label.n_overdue_tasks".translate(count: count)
    else
      "feature.mentoring_model.label.tasks_in_different_statuses".translate(count: count)
    end
  end

  def get_task_status_custom_filter_text(search_filters)
    if(search_filters && search_filters[:custom_v2_tasks_status] && search_filters[:custom_v2_tasks_status][:rows])
      operators = search_filters[:custom_v2_tasks_status][:rows].values.collect{|row| row[:operator]}
      return get_task_status_custom_filter_text_when_filters_are_applied(operators).html_safe
    end
    help_text = content_tag(:small, 'feature.mentoring_model.label.selected_tasks_with_status'.translate)
    return "feature.mentoring_model.label.custom_html".translate(help_text: help_text).html_safe
  end

  def get_custom_task_status_filter_hidden_fields(search_filters)
    content = []
    if(search_filters && search_filters[:custom_v2_tasks_status])
      content << hidden_field_tag("search_filters[custom_v2_tasks_status][template]", search_filters[:custom_v2_tasks_status][:template], class: "cjs_hidden_custom_task_filter", id: "cjs_hidden_custom_task_filter_template") if search_filters[:custom_v2_tasks_status][:template].present?
      if search_filters[:custom_v2_tasks_status][:rows]
        rows_count = search_filters[:custom_v2_tasks_status][:rows].values.size
        rows_count.times do |index|
          content << content_tag(:div, class: "hide cjs_hidden_custom_task_filter cjs_hidden_custom_task_rows") do
            hidden_field_tag("search_filters[custom_v2_tasks_status][rows][#{index}][task_id]", search_filters[:custom_v2_tasks_status][:rows]["#{index}"][:task_id], class: "cjs_hidden_custom_task_filter_task") +
            hidden_field_tag("search_filters[custom_v2_tasks_status][rows][#{index}][operator]", search_filters[:custom_v2_tasks_status][:rows]["#{index}"][:operator], class: "cjs_hidden_custom_task_filter_operator")
          end
        end
      end
    end
    safe_join(content, "")
  end

  def mentoring_connections_v2_behind_schedule(search_filters, is_reports_view=false)
    content = []
    title = "feature.mentoring_model.label.v2_tasks_status".translate
    selected_v2_task_status = search_filters.try(:[], :v2_tasks_status)
    profile_filter_wrapper(title, selected_v2_task_status.blank?, true, false, get_profile_filter_wrapper_for_groups(title, is_reports_view)) do
      content << content_tag(:label, class: "radio") do
        input_id = GroupsController::TaskStatusFilter::ALL
        radio_button_tag("search_filters[v2_tasks_status]", "", (selected_v2_task_status.blank? || selected_v2_task_status == input_id), id: input_id, class: "mentoring_connections_v2_behind_schedule") +
        "feature.mentoring_model.label.all_mentoring_connections".translate(Mentoring_Connections: _Mentoring_Connections)
      end
      content << content_tag(:label, class: "radio") do
        input_id = GroupsController::TaskStatusFilter::OVERDUE
        radio_button_tag("search_filters[v2_tasks_status]", input_id, (selected_v2_task_status == input_id), id: input_id, class: "mentoring_connections_v2_behind_schedule") +
        "feature.mentoring_model.label.overdue_connections".translate(Mentoring_Connections: _Mentoring_Connections)
      end
      content << content_tag(:label, class: "radio") do
        input_id = GroupsController::TaskStatusFilter::NOT_OVERDUE
        radio_button_tag("search_filters[v2_tasks_status]", input_id, (selected_v2_task_status == input_id), id: input_id, class: "mentoring_connections_v2_behind_schedule") +
        "feature.mentoring_model.label.ontrack_connections_v1".translate(Mentoring_Connections: _Mentoring_Connections)
      end
      content << content_tag(:label, class: "radio cjs_custom_task_status_filter_radio") do
        input_id = GroupsController::TaskStatusFilter::CUSTOM
        radio_button_tag("search_filters[v2_tasks_status]", input_id, (selected_v2_task_status == input_id), id: input_id, class: "btn-link mentoring_connections_v2_behind_schedule", data: { url: fetch_custom_task_status_filter_groups_path } ) +
        link_to(get_task_status_custom_filter_text(search_filters), "javascript:void(0);", id: "cjs_custom_task_status_filter_popup")
      end
      content << get_custom_task_status_filter_hidden_fields(search_filters)
      content_tag(:div, class: "filter_box clearfix") do
        content << link_to_function("display_string.Clear".translate, %Q[GroupSearch.clearTaskStatusFilter()], class: 'clear_filter btn btn-xs', id: "reset_filter_v2_tasks_status", style: 'display:none;')
        content << javascript_tag(%Q[GroupSearch.initializeTaskStatusFilter("#{j("display_string.And".translate)}")])
        safe_join(content, "")
      end
    end
  end

  def multiple_templates_filters(program, search_filters, is_reports_view=false)
    content = []
    selected_mentoring_models = search_filters.try(:[], :mentoring_models)
    title = "feature.multiple_templates.header.multiple_templates_title_v1".translate(Mentoring_Connection: _Mentoring_Connection)
    profile_filter_wrapper(title, selected_mentoring_models.blank?, true, false, get_profile_filter_wrapper_for_groups(title, is_reports_view)) do
      program.mentoring_models.each do |mentoring_model|
        content << content_tag(:label, class: "checkbox") do
          input_id = "mentoring_model_#{mentoring_model.id}"
          check_box_tag("search_filters[mentoring_models][]", mentoring_model.id, selected_mentoring_models.try(:include?, mentoring_model.id.to_s), id: input_id, onclick: "GroupSearch.applyFilters();", class: "multiple_templates_filters") +
          mentoring_model_pane_title(mentoring_model)
        end
      end
      content_tag(:div, class: "filter_box clearfix") do
        content << link_to_function("display_string.Clear".translate, %Q[GroupSearch.resetSidePaneFilters(".multiple_templates_filters");], class: 'clear_filter btn btn-xs', id: "reset_filter_mentoring_model_filters", style: 'display:none;')
        safe_join(content, "")
      end
    end
  end

  def closure_reason_filters(program, search_filters)
    content = []
    selected_closure_reasons = search_filters.try(:[], :closure_reasons)
    profile_filter_wrapper("feature.connection.header.Closure_reason".translate, selected_closure_reasons.blank?, true) do
      program.permitted_closure_reasons.includes(:translations).each do |closure_reason|
        content << content_tag(:label, class: "checkbox") do
          input_id = "closure_reason_#{closure_reason.id}"
          check_box_tag("search_filters[closure_reasons][]", closure_reason.id, selected_closure_reasons.try(:include?, closure_reason.id.to_s), id: input_id, onclick: "GroupSearch.applyFilters();", class: "closure_reason_filters") +
          closure_reason.reason
        end
      end
      content_tag(:div, class: "filter_box clearfix") do
        content << link_to_function("display_string.Clear".translate, %Q[GroupSearch.resetSidePaneFilters(".closure_reason_filters");], class: 'clear_filter btn btn-xs', id: "reset_filter_closure_reason_filters", style: 'display:none;')
        safe_join(content, "")
      end
    end
  end

  def display_mentoring_model_info(mentoring_model, from_list_view = false, for_csv = false, options = {})
    label_string = get_safe_string
    label_string = "feature.multiple_templates.header.connection_multiple_templates_title_v1".translate(Mentoring_Connection: _Mentoring_Connection) unless from_list_view
    content_string = mentoring_model_list_content(mentoring_model, from_list_view, for_csv)
    if !from_list_view && !for_csv
      if options[:display_vertically]
        return profile_field_container_wrapper(label_string, content_string, { class: "m-t-sm m-b-xs", wrapper_options: { class: "m-b-sm" } } )
      else
        return embed_display_line_item(label_string, content_string)
      end
    end
    return (label_string + content_string)
  end

  def mentoring_model_list_content(mentoring_model, from_list_view, for_csv)
    if mentoring_model.try(:title).present?
      for_csv ? mentoring_model_pane_title(mentoring_model) : link_to(mentoring_model_pane_title(mentoring_model), view_mentoring_model_path(mentoring_model))
    else
      from_list_view ? "" : "display_string.None".translate
    end
  end

  def get_formatted_choices_for_connection_question(choices, qid, selected_values)
    content = []
    index = 0
    choices.each do |english_choice, locale_choice|
      content << content_tag(:label, class: "choice_item clearfix checkbox") do
        check_box_tag("connection_questions[#{qid}][]", english_choice, selected_values.try(:include?, english_choice), id: "connection_questions_#{qid}_#{index}".to_html_id, class: 'profile_checkbox', index: "#{qid}_#{index}", onchange: "GroupSearch.applyFilters();") +
          content_tag(:div, locale_choice)
      end
      index += 1
    end
    safe_join(content)
  end

  def max_number_of_users_in_group_field(program, options = {})
    role = options[:role]
    return unless program.is_slot_config_enabled_for?(role)
    role_id = role.id
    role_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name)
    max_users_string = "feature.connection.maximum_users_to_join_v1".translate(:users => role_term.pluralized_term_downcase)
    max_users_label = role.slot_config_required? ? set_required_field_label(max_users_string) : max_users_string
    control_group do
      max_users_field_id = "max_#{role_id}"
      label_tag(max_users_field_id, max_users_label, :class => "control-label col-sm-3") +
      controls(class: "col-sm-9") do
       number_field_tag("group[membership_setting][#{role_id}]", options[:max_limit], :class => "form-control cjs_max_limit_validator #{'cjs_max_limit_required' if role.slot_config_required? }", :id => max_users_field_id, min: Group::MembershipSetting::MaxLimit::MINIMUM, step: 1) +
       content_tag(:div, "feature.connection.limit_includes_you".translate, :class => "help-block connection-limit-help-text #{'hide' unless options[:show_help_text]}", :id => "limit-help-text-#{role_id}") +
       (role.slot_config_required? ? javascript_tag("RequiredFields.addScopedField('scope_connection_questions', '#{max_users_field_id}')") : "")
      end
    end
  end

  def get_wizard_view_headers
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::DESCRIBE_MENTORING_CONNECTION] = { label: "feature.connection.wizard_header.description".translate(:Mentoring_Connection => UnicodeUtils.upcase(_Mentoring_Connection)) }
    wizard_info[Headers::ADD_MEMBERS] = { label: "feature.connection.wizard_header.add_members".translate }
    wizard_info
  end

  def group_listing_content(label, content, options = {})
    if options[:connection_answer] && options[:text_type]
      group_listing_format_text_connection_answer(label, content, options)
    else
      profile_field_container_wrapper(label, content, { class: "m-t-sm m-b-xs", wrapper_options: { class: "m-b-sm" } } )
    end
  end

  def group_listing_format_text_connection_answer(label, content, options)
    truncated_content, truncated = truncate_html(content, max_length: 350, status: true)
    if truncated
      id = options[:id]
      content = content_tag(:div) do
        content_tag(:div, id: "trunc_content_#{id}") do
          get_safe_string + truncated_content + " " +
          link_to("display_string.see_more_raquo_no_parentheses_html".translate, "javascript: void(0)", class: "see_more_toggle", data: { id: id } )
        end +
        content_tag(:div, class: "hide", id: "full_content_#{id}") do
          get_safe_string + content + " " +
          link_to("display_string.see_less_laquo_no_parentheses_html".translate, "javascript: void(0)", class: "see_less_toggle", data: { id: id } )
        end
      end
    end
    profile_field_container_wrapper(label, content, { class: "m-t-sm m-b-xs", wrapper_options: { class: "m-b-sm" } } )
  end

  def group_members_list(group, role, options = {})
    members = group.memberships.select { |membership| membership.role_id == role.id }.collect(&:user)
    members_to_show = options[:members_to_show] || MAX_MEMBERS_FOR_VIEW
    content = []
    if members.present?
      members_shown = members[0, members_to_show]
      members_hidden = members[(members_to_show)..-1] || []

      sub_content = safe_join(members_shown.collect{|m| link_to_user(m, {content_method: [:name, name_only: true]}) + owner_content_for_user_name(group, m)}, COMMON_SEPARATOR)
      if members_hidden.present?
        sub_content += content_tag(:span, class: "cjs_show_and_hide_toggle_container") do
          content_tag(:span, class: "cjs_show_and_hide_toggle_sub_selector cjs_show_and_hide_toggle_show") do
            (get_safe_string + " #{'display_string.and'.translate} " +
            link_to("display_string.more_with_count".translate(count: members_hidden.size), "javascript: void(0)"))
          end +
          content_tag(:span, class: "cjs_show_and_hide_toggle_sub_selector cjs_show_and_hide_toggle_content hide") do
            (get_safe_string + COMMON_SEPARATOR + safe_join(members_hidden.collect{|m| link_to_user(m) + owner_content_for_user_name(group, m)}, COMMON_SEPARATOR))
          end
        end
      end
      content << sub_content
    else
      content << content_tag(:span, "feature.connection.content.No_users_yet".translate(mentoring_connection: _mentoring_connection), class: "text-muted")
    end
    content << get_project_request_content_for_group(group, role, options) if options[:show_requests_and_slots]
    label = (members.size == 1) ? role.customized_term.term : role.customized_term.pluralized_term
    [label, safe_join(content, " ")]
  end

  def group_meeetings_status(group)
    return unless group.active? && group.can_manage_mm_meetings?(current_program.roles.for_mentoring)
    meetings = Meeting.get_meetings_for_view(group, true, wob_member, current_program)
    upcoming_meetings, completed_meetings = Meeting.recurrent_meetings(meetings)
    content =
      if meetings.blank?
       "feature.connection.content.no_meetings_yet".translate(meetings: _meetings)
      else
        meetings_count_text = "#{_Meetings} - #{completed_meetings.count} #{"feature.connection.header.Completed".translate}, #{upcoming_meetings.count} #{"feature.meetings.header.upcoming".translate}"
        append_text_to_icon("fa fa-calendar", meetings_count_text)
      end
    profile_field_container_wrapper("feature.connection.header.status.Status".translate, content, class: "m-t-sm m-b-xs", wrapper_options: { class: "m-b-sm" })
  end

  # This method is tested as part of tests of group_members_list
  def get_project_request_content_for_group(group, role, options = {})
    content = get_safe_string
    group_setting = group.setting_for_role_id(role.id, false)
    pending_requests_count = group.active_project_requests.select{|request| request.sender_role_id == role.id}.size
    show_pending_projects = group.open? && pending_requests_count > 0
    if show_pending_projects
      content += link_to(content_tag(:big, " #{pending_requests_count.to_s}"), ProjectRequest.get_project_request_path_for_privileged_users(current_user, filters: { project: group.name }), class: "font-bold text-danger") + " "
      content += link_to("#{'feature.connection.content.request_pending'.translate(count: pending_requests_count)} ", ProjectRequest.get_project_request_path_for_privileged_users(current_user, filters: { project: group.name }, from_quick_link: options[:from_quick_link]))
    end
    if group_setting.try(:max_limit).present?
      content += vertical_separator if show_pending_projects
      content += content_tag(:span) do
        "feature.connection.content.n_slots_left_v1".translate(count: group_setting.max_limit - group.memberships.select{|membership| membership.role_id == role.id}.size)
      end
    end
    content.present? ? "display_string.add_brackets_html".translate(string: content) : ""
  end

  def get_circle_remaining_slot_info_for_role(group, role_name)
    role = group.program.get_role(role_name)
    group_setting = group.setting_for_role_id(role.id)
    
    if group_setting.try(:max_limit).present?
      "feature.connection.content.n_slots_left_v1".translate(count: group_setting.max_limit - group.memberships.select{|membership| membership.role_id == role.id}.size)
    else
      "feature.connection.content.no_limit".translate
    end
  end

  def render_publish_circle_widget_slot_tooltip(group, role_name, mobile_view = false)
    role = group.program.get_role(role_name)
    tooltip_id = "slot_tooltip_#{group.id}_#{role.id}_#{mobile_view ? 'mobile' : 'web'}"
    tooltip_text = get_circle_remaining_slot_info_for_role(group, role_name)
    content_tag(:span, get_icon_content("fa fa-info-circle m-l-xs"), id: "#{tooltip_id}") + tooltip("#{tooltip_id}", tooltip_text)
  end

  def get_active_groups_navigation_links(groups_to_render, user, is_pbe)
    tab_content = []
    tabs_rendered = 0

    while tabs_rendered < groups_to_render.size
      link_path = is_pbe ? (groups_to_render[tabs_rendered].published? ? group_path(groups_to_render[tabs_rendered], src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION) : profile_group_path(groups_to_render[tabs_rendered], src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION)) : group_path(groups_to_render[tabs_rendered], src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION)

      tab_content << get_tab_link_content("fa-group", h(groups_to_render[tabs_rendered].name), link_path, {tab_class: hidden_on_mobile})
      tabs_rendered += 1
    end

    return tab_content
  end

  def get_groups_content_inside_connection_navigation_header(groups_to_render, all_groups_size, user, is_pbe = false)
    tab_content = get_active_groups_navigation_links(groups_to_render, user, is_pbe)
    closed_groups_size = user.groups.closed.size

    if all_groups_size > 0 || closed_groups_size > 0
      view_all_path, label = get_view_all_mentoring_connection_side_pane(all_groups_size, closed_groups_size, is_pbe)
      tab_content << content_tag(:li, content_tag(:hr, nil, class: "no-margins"))
      tab_content << get_tab_link_content("fa-list", label, view_all_path)
      tab_content << content_tag(:li, content_tag(:hr, nil, class: "no-margins"))
    end

    return tab_content
  end

  def get_meetings_link_for_connection_tab_header(user, tab_content)
    if user.can_be_shown_meetings_listing? && !user.program.calendar_enabled?
      tab_content << get_tab_link_content("fa-calendar", _Meetings, member_path(wob_member, :tab => MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION))
    end
    tab_content
  end

  def get_non_pbe_subtabs(user)
    active_groups = user.groups.active.select("groups.id, groups.name, groups.last_member_activity_at").order(last_member_activity_at: :desc)
    groups_to_render = active_groups.size == TabConstants::MAX_SUBTABS_FOR_CONNECTION_TAB ? active_groups[0..2] : active_groups[0..1]
    tab_content = get_groups_content_inside_connection_navigation_header(groups_to_render, active_groups.size, user)
    safe_join(get_meetings_link_for_connection_tab_header(user, tab_content), "")
  end

  def get_available_projects(user)
    roles_for_mentoring = user.roles.for_mentoring.collect(&:id)
    user.program.groups.open_connections.available_projects(roles_for_mentoring)
  end

  def get_pbe_subtabs(user, program)
    #We are using a group_by in available_projects scope. So size along with the scope will return a hash.
    available_projects = get_available_projects(user).pending_less_than(PENDING_PROJECT_DAYS.days.ago).size

    active_groups = user.groups.open_connections.select("groups.id, groups.name, groups.status").order(last_member_activity_at: :desc)
    groups_to_render = active_groups.size == TabConstants::MAX_SUBTABS_FOR_CONNECTION_TAB ? active_groups[0..2] : active_groups[0..1]

    tab_content = get_groups_content_inside_connection_navigation_header(groups_to_render, active_groups.size, user, true)

    if user.can_send_project_request?
      tab_content << get_tab_link_content("fa-search", "tab_constants.sub_tabs.discover".translate, find_new_groups_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION), {tab_badge_count: available_projects.keys.size, tab_badge_class: "badge-success"})
    else
      tab_content << get_tab_link_content("fa-globe", "tab_constants.sub_tabs.all_projects".translate(mentoring_connections: _mentoring_connections), find_new_groups_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION))
    end

    tab_content << get_tab_link_content("fa-plus-circle", user.can_create_group_without_approval? ? "tab_constants.sub_tabs.start_a_new_group".translate(mentoring_connection: _mentoring_connection) : "tab_constants.sub_tabs.propose_a_new_group".translate(mentoring_connection: _mentoring_connection), new_group_path(propose_view: true, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION)) if user.allow_to_propose_groups?
    tab_content << get_tab_link_content("fa-group", "tab_constants.sub_tabs.my_proposed_groups".translate(mentoring_connections: _mentoring_connections), groups_path(show: 'my', tab: Group::Status::PROPOSED, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION)) if user.can_propose_groups? && user.can_be_shown_proposed_groups?

    tab_content = get_meetings_link_for_connection_tab_header(user, tab_content)

    safe_join(tab_content, "")
  end

  def find_new_projects_title(user)
    if user.can_send_project_request?
      "feature.connection.action.find_new_projects".translate(mentoring_connections: _mentoring_connections)
    else
      "feature.connection.action.all_projects".translate(mentoring_connections: _mentoring_connections)
    end
  end

  def collapsible_find_new_filters(is_reports_view=false)
    content = []
    options = is_reports_view ? {render_panel: false} : {}
    profile_filter_wrapper("feature.connection.header.status.Status".translate, false, false, false, options) do
      content << content_tag(:div , class: "checkbox") do
        input_id = "available_to_join_filters"
        sub_label = "feature.connection.header.available_to_join".translate(mentoring_connections: _mentoring_connections)
        label_tag(:search_filters, sub_label, for: input_id, class: 'sr-only') +
        check_box_tag("search_filters[available_to_join]", DEFAULT_AVAILABLE_TO_JOIN_FILTER, true, id: input_id, onclick: "GroupSearch.toggleFindNewFilters();", class: "available_to_join_filters") +
        sub_label +
        check_box_tag("search_filters[available_to_join]", "all_projects", false, class: "all_projects_filters hide")
      end
      content_tag(:div, class: "filter_box clearfix") do
        content << link_to_function("display_string.Clear".translate, %Q[GroupSearch.resetSidePaneFilters('.all_projects_filters', '.available_to_join_filters');], class: 'clear_filter btn btn-xs', id: "reset_filter_available_to_join", style: 'display:none;')
        safe_join(content, "")
      end
    end
  end

  def render_join_button(group, options = {})
    return unless current_user.can_apply_for_join?(group)

    {
      label: "feature.connection.action.Join".translate(Mentoring_Connection: _Mentoring_Connection),
      url: new_project_request_path(group_id: group.id, format: :js, project_request: { from_page: :profile }, src: options[:src_path]),
      class: "btn btn-primary cjs_create_project_request",
      js_class: "cjs_create_project_request"
    }
  end

  def instantiate_group_profile_back_link(from_find_new, session_back_url)
    @back_link =
      if from_find_new.present?
        { label: find_new_projects_title(current_user), link: find_new_groups_path }
      elsif current_user.can_manage_connections?
        { label: _Mentoring_Connections, link: groups_path }
      elsif session_back_url.present?
        { label: _Mentoring_Connections, link: session_back_url }
      end
  end

  def instantiate_group_profile_title_badge_and_sub_title(group, user_is_member_or_can_join_pending_group)
    return if group.proposed? || group.rejected?

    @title_badge = get_group_label_for_end_user(current_user, group)
    return if @title_badge.present?

    @sub_title = "feature.connection.header.Profile".translate and return if group.published?

    return if user_is_member_or_can_join_pending_group

    @title_badge =
      if !current_user.is_admin? && group.pending?
        content_tag(:span, "feature.connection.header.status.Not_Started".translate, class: "label label-info")
      else
        render_group_status_logo(group)
      end
  end

  def render_group_status_logo(group)
    content, label_class = display_group_status_label_content[group.status]
    content_tag(:span, content, class: "label #{label_class}")
  end

  def render_group_name(group, user, options = {})
    options[:disable_link] ||= !(group.admin_enter_mentoring_connection?(user, super_console?) || options[:find_new] || options[:is_global])

    ## user will be false in case of organization_view (published groups)
    link_url = options[:disable_link] ? nil : generate_connection_links(group, user, options)
    link_url.present? ? link_to(group.name, link_url, class: "group_name #{options[:class]}") : group.name
  end

  def render_connection_profile(group, connection_questions)
    connection_information = get_safe_string
    connection_questions.each do |question|
      connection_information += content_tag :div, class: "m-b-sm" do
        content_tag(:h4, question.question_text, class: "m-t-sm m-b-xs") +
        content_tag(:div, formatted_common_answer(group.answer_for(question), question), class: "m-b-sm")
      end
    end
    connection_information
  end

  def generate_connection_links(group, user, options = {})
    ## The test cases for this method are covered in the render_group_name method
    ## user will be false in case of organization_view (published groups)
    if !user || (group.published? && can_access_groups_show?(group, user) && group.admin_enter_mentoring_connection?(user, super_console?))
      if options[:src]
        group_path(group, src: options[:src])
      else
        group_path(group)
      end
    elsif group.program.connection_profiles_enabled? && group.global?
      find_new_params = {}
      find_new_params.merge!(from_find_new: true) if options[:find_new]
      find_new_params.merge!(src: options[:src]) if options[:src]
      profile_group_path(group, find_new_params)
    end
  end

  def group_notes_label(options = {})
    label = "".html_safe
    tooltip_text = options[:bulk] ? "feature.connection.content.placeholder.bulk_create_new_note".translate(mentoring_connections: options[:mentoring_connections], admins: options[:admins]).html_safe : "feature.connection.content.placeholder.create_new_note".translate(mentoring_connection: options[:mentoring_connection], admins: options[:admins]).html_safe
    label += "feature.connection.content.notes".translate.html_safe
    label += " #{embed_icon("fa fa-lock", " ", id: "group_notes_#{options[:id]}")}".html_safe
    label += "#{tooltip("group_notes_#{options[:id]}", tooltip_text)}".html_safe
    return label.html_safe
  end

  def can_access_groups_show?(group, user)
    user.is_admin? || group.has_member?(user)
  end

  def connection_membership_terms(group, program = nil)
    membership_terms = {}
    program ||= group.program
    role_terms = RoleConstants.program_roles_mapping(program)
    group.memberships.includes(:role).each do |membership|
      membership_terms[membership.user_id] = role_terms[membership.role.name]
    end
    membership_terms
  end

  def render_memberships(group, role, is_clone = false)
    members_name_with_email = get_memberships(group, role, is_clone).collect do |membership|
      membership.user.name_with_email
    end
    members_name_with_email.join(",")
  end

  def initialize_memberships_for_select2(group, role, is_clone = true)
    members_name_with_email = get_memberships(group, role, is_clone).collect do |membership|
      membership.user.email_with_id_hash
    end
    members_name_with_email.to_json
  end

  def get_memberships(group, role, is_clone = false)
    @initial_memberships ||= {}
    @initial_memberships[role.id] ||= (is_clone ? group.memberships.select{|membership| membership.role_id == role.id} : group.memberships.where(role_id: role.id).includes({user: :member}))
  end

  def join_role_select_drop_down_field(group, user, join_as_roles)
    if join_as_roles.size > 1
      role_mapping = RoleConstants.program_roles_mapping(user.program)
      role_options = join_as_roles.collect{ |r| [role_mapping[r.name], r.id] }
      curr_role = group.memberships.where(:user_id => user.id).first.try(:role)
      selected_option = curr_role.present? ? [role_mapping[curr_role.name], curr_role.id] : role_options.first

      control_group do
        label_tag("group[join_as_role_id]", "feature.connection.content.select_role".translate(:mentoring_connection => _mentoring_connection), :class => "col-sm-3 control-label") +
        controls(class: "col-sm-9") do
          select_tag("group[join_as_role_id]", options_for_select(role_options, selected_option), class: "form-control")
        end
      end
    end
  end

  def display_group_proposed_data(group, my_connections_view = false)
    display_content = []
    display_content << display_group_data(formatted_time_in_words(group.created_at, no_ago: true, no_time: true), "feature.connection.header.proposed_label".translate, "fa fa-clock-o")
    unless my_connections_view
      display_content << content_tag(:span, "|", class: "text-muted p-l-xxs p-r-xxs")
      display_content << attach_group_created_by_info(group)
    end
    safe_join(display_content, "")
  end

  # Test cases for this are covered with the parent method **display_group_proposed_data**
  def attach_group_created_by_info(group)
    label = "feature.connection.header.proposed_by_label".translate
    content = if group.created_by.nil?
      "feature.connection.header.removed_user_label".translate
    else
      link_to_user(group.created_by, { content_method: [:name, name_only: true] } ) + owner_content_for_user_name(group, group.created_by)
    end
    display_group_data(content, label)
  end

  def get_group_label_for_end_user(user, group, options = {})
    group_labels = []
    group_labels <<
      if group.has_member?(user) && !options[:skip_my_group]
        {
          content: "feature.connection.content.label.my_connection".translate(Mentoring_Connection: _Mentoring_Connection),
          label_class: "label-success"
        }
      elsif user.has_pending_request?(group)
        {
          content: "feature.connection.content.label.request_pending".translate,
          label_class: "label-info"
        }
      elsif group.pending? && options[:skip_my_group]
        {
          content: "feature.connection.content.label.pending".translate(Mentoring_Connection: _Mentoring_Connection),
          label_class: "label-info"
        }
      elsif user.can_send_project_request? && group.pending? && group.available_roles_for_user_to_join(user).empty? && @current_program.mentoring_roles_with_permission(RolePermission::SEND_PROJECT_REQUEST).exists?
        {
          content: "feature.connection.content.label.no_slots".translate,
          label_class: "label-danger"
        }
      end

    labels_container(group_labels, tag: :span) if group_labels.present?
  end

  def group_end_users_actions_dropdown(user)
    actions_drop_down = []
    if user.can_send_project_request?
      actions_drop_down << {
        label: "feature.connection.action.find_new_projects".translate(mentoring_connections: _mentoring_connections),
        url: find_new_groups_path
      }
    end
    if user.allow_to_propose_groups?
      actions_drop_down << {
        label: user.can_create_group_without_approval? ? "tab_constants.sub_tabs.start_a_new_group".translate(mentoring_connection: _mentoring_connection) : "tab_constants.sub_tabs.propose_a_new_group".translate(mentoring_connection: _mentoring_connection),
        url: new_group_path(propose_view: true)
      }
    end
    actions_drop_down
  end

  def overdue_groups_filter_params(program)
    { tab: Group::Status::ACTIVE, search_filters: { v2_tasks_status: GroupsController::TaskStatusFilter::OVERDUE }, root: program.root }
  end

  def ontrack_groups_filter_params(program)
    { tab: Group::Status::ACTIVE, search_filters: { v2_tasks_status: GroupsController::TaskStatusFilter::NOT_OVERDUE }, root: program.root }
  end

  def get_user_text(groups)
    (groups.size == 1) ? link_to_user(groups.first.created_by) : "feature.connection.content.proposer".translate
  end

  def can_show_assign_owner_link?(groups)
    !((groups.size == 1) && groups.first.owners.include?(groups.first.created_by))
  end

  def side_pane_action_header_text(user_is_only_owner)
    user_is_only_owner ? "feature.connection.content.owner_actions".translate : 'common_text.side_pane.admin_actions_v1'.translate(Admin: _Admin)
  end

  def get_group_members_data_for_select2(group)
    members_hash = []
    group.members.select('users.id, users.member_id').each do |gm|
      members_hash << {id: gm.id, text: gm.name(name_only: true)}
    end
    members_hash.to_json
  end

  def get_group_members_list(group, group_roles, show_requests_and_slots, options ={})
    content = get_safe_string
    group_roles.each_with_index do |group_eligible_role, index|
      label, value = group_members_list(group, group_eligible_role, show_requests_and_slots: show_requests_and_slots)
      content += if options[:display_vertically]
        profile_field_container_wrapper(label, value, { class: "m-t-sm m-b-xs", wrapper_options: { class: "m-b-sm" } } )
      else
        embed_display_line_item(label, value)
      end
    end
    content
  end

  def get_engagement_surveys(program)
    program.surveys.of_engagement_type.select(:id).includes(:translations)
  end

  def get_survey_status_filter(program, survey_filters, is_reports_view=false)
    engagement_surveys = get_engagement_surveys(program)
    title = "feature.connection.header.survey_status_filter.labels.survey_status".translate
    if engagement_surveys.present?
      result = content_tag(:div) do
        profile_filter_wrapper(title, survey_filters[:survey_id].blank?, true, false, get_profile_filter_wrapper_for_groups(title, is_reports_view)) do
          content_tag(:div, id: "survey_status_filter_container") do
            get_survey_dropdown_for_status_filter(engagement_surveys, survey_filters, is_reports_view)
          end
        end
      end + javascript_tag(%Q[Groups.displayTaskStatusBox();])
      return result
    end
  end

  def get_survey_dropdown_for_status_filter(surveys, survey_filters, is_reports_view=false)
    content = content_tag(:div, :class => "m-b-sm", id: "filter_survey_name_status_container") do
      label_tag("filter_survey_name_status", "feature.connection.header.survey_status_filter.labels.group_response_as".translate(), :class => "control-label font-noraml sr-only") +
      select_tag("search_filters[survey_status][survey_id]", options_for_select(surveys.collect{|s| [s.name, s.id]}, survey_filters[:survey_id]),
          id: "filter_survey_name_status", :class => "form-control input-sm",
          prompt: "feature.connection.header.survey_status_filter.placeholder.select_survey".translate)
    end
    content += get_survey_tasks_status(survey_filters, is_reports_view)
    content += link_to_function("display_string.Clear".translate, %Q[GroupSearch.clearSurveyStatusFilter(); GroupSearch.applyFilters();], :class => 'clear_filter btn btn-xs hide', :id => "reset_filter_survey_status_filter")
  end

  def get_survey_tasks_status(survey_filters, is_reports_view=false)
    input_group_class_options = is_reports_view ? {input_group_class: "col-xs-12"} : {}
    content = content_tag(:div, :class => "m-b-sm #{"hide" unless survey_filters[:survey_task_status].present?}", id: "filter_survey_task_status_container") do
      control_group do
        label_tag("search_filters[survey_status][survey_task_status]", "feature.connection.header.survey_status_filter.labels.survey_task_status".translate, for: "survey_task_status",
          :class => "control-label font-noraml sr-only") +
        controls do
          construct_input_group({}, groups_filter_input_group_submit_options(get_input_group_options(is_reports_view)), input_group_class_options) do
            select_tag("search_filters[survey_status][survey_task_status]", options_for_select(get_task_status_filter_options, survey_filters[:survey_task_status]),
          id: "survey_task_status", :class => "form-control input-sm ",
          prompt: "common_text.prompt_text.Select".translate)
          end
        end
      end
    end
    content
  end

  def get_task_status_filter_options
    [
      ["feature.connection.header.survey_status_filter.labels.survey_task_status_complete".translate, MentoringModel::Task::StatusFilter::COMPLETED],
      ["feature.connection.header.survey_status_filter.labels.survey_task_status_not_completed".translate, MentoringModel::Task::StatusFilter::NOT_COMPLETED],
      ["feature.connection.header.survey_status_filter.labels.survey_task_status_overdue".translate, MentoringModel::Task::StatusFilter::OVERDUE]
    ]
  end

  def get_survey_response_filter(program, survey_filters, is_reports_view=false)
    engagement_surveys = get_engagement_surveys(program)
    title = "feature.connection.header.survey_response_filter.labels.survey_response".translate

    if engagement_surveys.present?
      questions = engagement_surveys.find(survey_filters[:survey_id]).get_questions_for_report_filters if survey_filters[:survey_id].present?
      result = content_tag(:div) do
        profile_filter_wrapper(title, survey_filters[:survey_id].blank?, true, false, get_profile_filter_wrapper_for_groups(title, is_reports_view)) do
          content_tag(:div, id: "survey_filter_container") do
            get_survey_dropdown(engagement_surveys, survey_filters, questions, is_reports_view)
          end
        end
      end + javascript_tag(%Q[Groups.displaySurveyQuestions();])
      return result
    end
  end

  def get_survey_dropdown(surveys, survey_filters, questions, is_reports_view=false)
    content = content_tag(:div, :class => "m-b-sm", id: "filter_survey_name_container") do
      label_tag("filter_survey_name", "feature.connection.header.survey_response_filter.labels.group_response_as_v1".translate(Mentoring_Connection: _Mentoring_Connection), :class => "control-label font-noraml") +
      select_tag("search_filters[survey_response][survey_id]", options_for_select(surveys.collect{|s| [s.name, s.id]}, survey_filters[:survey_id]),
          data: {url: fetch_survey_questions_groups_path(format: :js), is_reports_view: is_reports_view}, id: "filter_survey_name", :class => "form-control input-sm",
          prompt: "feature.connection.header.survey_response_filter.placeholder.select_survey".translate)
    end
    content += get_survey_questions(questions, survey_filters, is_reports_view) if survey_filters[:survey_id].present?
    content += link_to_function("display_string.Clear".translate, %Q[GroupSearch.clearSurveyFilter(); GroupSearch.applyFilters();], :class => 'clear_filter btn btn-xs hide', :id => "reset_filter_survey_filter")
  end

  def get_survey_questions(survey_questions, survey_filters = {}, is_reports_view=false)
    content = content_tag(:div, :class => "m-b-sm", id: "filter_survey_question_container") do
      label_tag("survey_question_dropdown", "feature.connection.header.survey_response_filter.labels.survey_question".translate, :class => "control-label font-noraml") +
      select_tag("search_filters[survey_response][question_id]", options_for_select(survey_questions.collect{|sq| [sq.question_text_for_display, sq.id]}, survey_filters[:question_id]),
              data: {url: fetch_survey_answers_groups_path(format: :js), is_reports_view: is_reports_view}, id: "survey_question_dropdown", :class => "form-control input-sm",
              prompt: "feature.connection.header.survey_response_filter.placeholder.select_question".translate)
    end + javascript_tag(%Q[Groups.displaySurveyAnswerBox();])
    content += get_survey_answer(survey_questions.find(survey_filters[:question_id]), survey_filters, is_reports_view) if survey_filters[:question_id].present?
    content
  end

  def get_survey_answer(question, survey_filters = {}, is_reports_view=false)
    choice_based = question.choice_based?
    answer_text = survey_filters[:answer_text]
    input_group_class_options = is_reports_view ? {input_group_class: "col-xs-12"} : {}
    content = content_tag(:div, id: "filter_survey_answer_container") do
      control_group do
        label_tag("search_filters[survey_response][answer_text]", "feature.connection.header.survey_response_filter.labels.survey_answer".translate, :class => "control-label font-noraml") +
        controls do
          construct_input_group({}, groups_filter_input_group_submit_options(get_input_group_options(is_reports_view)), input_group_class_options) do
            choice_based ? hidden_field_tag("search_filters[survey_response][answer_text]", "", class: "col-xs-12 no-padding", :id => "survey_answer_choice", data: {placeholder: "feature.connection.header.survey_response_filter.placeholder.select_choices".translate}) : text_field_tag("search_filters[survey_response][answer_text]", answer_text, class: "form-control input-sm")
          end
        end
      end
    end

    if choice_based
      values_and_choices = question.values_and_choices
      # As per select2 doc, select options should be passed as id: <value> text: <text_to_display>
      choices = values_and_choices.map{|qc_id, qc_text| {:id => qc_id, :text => qc_text}}
      choices_ids_string = choices.map{|c| c[:id]}.join(CommonQuestion::SELECT2_SEPARATOR)
      choices_texts_string = choices.map{|c| c[:text]}.join(CommonQuestion::SELECT2_SEPARATOR)
      content += javascript_tag(%Q[Groups.displaySurveyAnswerChoices('#{j(choices_ids_string)}', '#{j(choices_texts_string)}', '#{j(answer_text)}', '#{CommonQuestion::SELECT2_SEPARATOR}')])
    end

    content
  end

  def self.state_to_string_map
    {
      Group::Status::ACTIVE => "feature.connection.header.status.Active".translate,
      Group::Status::INACTIVE => "feature.connection.header.status.Inactive".translate,
      Group::Status::CLOSED => "feature.connection.header.status.Closed".translate,
      Group::Status::DRAFTED => "feature.connection.header.status.Drafted".translate,
      Group::Status::PENDING => "feature.connection.header.status.Pending".translate,
      Group::Status::PROPOSED => "feature.connection.header.status.Proposed".translate,
      Group::Status::REJECTED => "feature.connection.header.status.Rejected".translate,
      Group::Status::WITHDRAWN => "feature.connection.header.status.Withdrawn".translate
    }
  end

  def self.state_to_string_downcase_map
    {
      Group::Status::ACTIVE => "feature.connection.content.status.active".translate,
      Group::Status::INACTIVE => "feature.connection.content.status.inactive".translate,
      Group::Status::CLOSED => "feature.connection.content.status.closed".translate,
      Group::Status::DRAFTED => "feature.connection.content.status.drafted".translate,
      Group::Status::PENDING => "feature.connection.content.status.pending".translate,
      Group::Status::PROPOSED => "feature.connection.content.status.proposed".translate,
      Group::Status::REJECTED => "feature.connection.content.status.rejected".translate,
      Group::Status::WITHDRAWN => "feature.connection.content.status.withdrawn".translate
    }
  end

  def show_provide_rating_link?(group, user, viewer)
    return group.program.coach_rating_enabled? && group.published? && group.students.include?(viewer) && group.mentors.include?(user)
  end

  def display_notes(user_edit_view)
     !user_edit_view && @current_user.is_admin?
  end

  def render_alert_for_proposed_groups(user, group)
    content = if user.is_admin?
        "feature.connection.header.proposed_group_header_alert_for_admin".translate(mentoring_connection: _mentoring_connection)
      elsif group.has_member?(user)
        "feature.connection.header.proposed_group_header_alert_for_proposer".translate(mentoring_connection: _mentoring_connection, admin: _admin)
      end

    content_tag(:div, content, class: "font-600")
  end

  def can_show_pending_group_header_alert?(group, user, user_is_member_or_can_join_pending_group)
    user_is_member_or_can_join_pending_group || (group.pending? && user.is_admin?)
  end

  def render_alert_for_pending_groups(user, group)
    content = if group.start_date.present? && group.program.allow_circle_start_date?
        get_pending_group_alert_for_groups_with_start_date(user, group)
      else
        get_pending_group_alert_for_groups_without_start_date(user, group)
      end

    content_tag(:div, content, class: "font-600")
  end

  def get_pending_group_alert_for_groups_with_start_date(user, group)
    if group.has_past_start_date?(wob_member)
      get_alert_message_for_past_start_date_circles(user, group)
    else
      get_alert_message_for_future_start_date_circles(user, group)
    end
  end

  def get_pending_group_alert_for_groups_without_start_date(user, group)
    if user.is_owner_of?(group) || user.is_admin?
      alert = "feature.connection.header.group_not_started_yet".translate(group_term: _mentoring_connection)
      alert = "#{alert} #{"feature.connection.header.pending_group_header_alert_for_owners_and_admins_1".translate(group_term: _mentoring_connection, resources: _resources)}"
      "#{alert} #{"feature.connection.header.pending_group_header_alert_for_owners_and_admins_2".translate(group_term: _mentoring_connection)}"
    elsif group.has_member?(user)
      "feature.connection.header.pending_group_header_alert_for_members".translate(group_term: _mentoring_connection)
    else
      "feature.connection.header.pending_group_header_alert_for_non_members".translate(group_term: _mentoring_connection)
    end
  end

  def get_alert_message_for_past_start_date_circles(user, group)
    start_date = DateTime.localize(group.start_date, format: :short)
    if user.is_owner_of?(group) || user.is_admin?
      "feature.connection.header.pending_group_with_past_start_date_owners_and_admins_html".translate(:group => _mentoring_connection, start_date: start_date, set_start_date_url: link_to("feature.connection.content.set_a_new_start_date".translate, "javascript:void(0)", class: "cjs_set_or_edit_connection_start_date", data: {url: get_edit_start_date_popup_group_path(id: group.id, from_profile_flash: true)}))
    elsif group.has_member?(user)
      "feature.connection.header.pending_group_header_alert_for_members".translate(:group_term => _mentoring_connection)
    else
      "feature.connection.header.pending_group_header_alert_for_non_members".translate(:group_term => _mentoring_connection)
    end
  end

  def get_alert_message_for_future_start_date_circles(user, group)
    start_date = DateTime.localize(group.start_date, format: :short)
    if group.has_member?(user)
      "feature.connection.header.pending_group_with_future_start_date_for_members".translate(:group => _mentoring_connection, start_date: start_date)
    elsif user.is_admin?
      "feature.connection.header.pending_group_with_future_start_date_for_admin".translate(:group => _mentoring_connection, start_date: start_date)
    else
      "feature.connection.header.pending_group_with_future_start_date_for_non_members".translate(:group => _mentoring_connection, start_date: start_date)
    end
  end

  def render_find_new_group_link_text(user, group)
    return "" if user.is_owner_of?(group) || user.is_admin? || !user.can_view_find_new_projects? || get_available_projects(user).where.not(id: group.id).blank?

    click_here_link = link_to("display_string.Click_here".translate, find_new_groups_path)
    content_tag(:div, "feature.connection.header.click_here_to_explore_html".translate(click_here_link: click_here_link, mentoring_connections: _mentoring_connections).html_safe, class: "m-t-sm")
  end

  # returning list should have first all mentees, then all mentors and then any other role members
  def order_members_for_group_user_listing(group)
    ordered_members = []
    ordered_members += group.students
    ordered_members += group.mentors
    ordered_members += group.custom_users
    return ordered_members
  end

  def groups_filter_input_group_submit_options(options={})
    return {
      type: "btn",
      btn_options: {
        class: "btn btn-primary btn-sm no-margins #{options[:class]}",
        onclick: "return GroupSearch.applyFilters();"
      },
      content: "display_string.Go".translate
    }
  end

  def display_group_data(content, label = nil, icon_class = nil, label_class = nil)
    content_tag(:span) do
      concat content_tag(:span, label, class: "font-bold #{label_class}") if label.present?
      concat get_icon_content("#{icon_class} m-r-0 text-default") if icon_class.present?
      concat content.html_safe
    end
  end

  def get_circle_start_and_available_info_text_class(group, member)
    start_date = group.start_date if group.program.allow_circle_start_date?
    return "text-success" if group.pending? && start_date.present? && start_date >= Time.now
  end

  def get_circle_start_and_available_info(group, member)
    start_date = group.start_date if group.program.allow_circle_start_date?
    if group.active?
      return "feature.connection.header.started_label".translate, group.published_at
    elsif start_date.nil? || group.has_past_start_date?(wob_member)
      return "feature.connection.header.pending_label".translate, group.pending_at
    else
      return "feature.connection.header.start_label".translate, start_date
    end
  end

  def get_active_or_pending_group_display_info(group, user)
    if group.pending?
      label, date = get_circle_start_and_available_info(group, user.member)
      date = formatted_time_in_words(date, no_ago: true, no_time: true)
    else
      if group.has_member?(user) || user.is_admin?
        label, date = nil, formatted_time_in_words(group.published_at, no_ago: true, no_time: true) + " - " + content_tag(:span, get_group_expiry_content(group, true, show_expired_text: true), id: "cjs_expiry_#{group.id}")
      else
        label, date = "feature.connection.header.started_label".translate, formatted_time_in_words(group.published_at, no_ago: true, no_time: true)
      end
    end
    return label, date
  end

  def display_closed_group_data(group)
    if group.auto_terminated?
      content = ""
      label = "feature.connection.content.auto_closed".translate
    else
      content = group.closed_by.nil? ? _Admin : link_to_user(group.closed_by)
      label = "feature.connection.header.closed_label".translate
    end
    display_group_data(content, label)
  end

  def display_survey_response_link(answer, data, management_report=false)
    response_link = link_to(answer.survey.name, "javascript:void(0)",
      data: data,
      class: "cjs_show_response m-r-xs #{"font-bold" unless management_report}")
    response_link +=
      content_tag(:span, "display_string.on_date".translate(date: DateTime.localize(answer.updated_at, format: :short))) unless management_report

    content_tag(:li, class: "list-group-item no-horizontal-padding col-sm-12") do
      member_picture_v3(answer.user.member, {no_name: true, size: :small, new_size: :tiny, outer_class: "col-sm-1 no-padding "}, {class: "img-circle", size: "21x21"}) + content_tag(:div, response_link, class: "col-sm-9 m-l-xs no-padding")
    end
  end

  def options_for_bulk_send_message_to_groups(group_ids, program)
    program_roles = RoleConstants.program_roles_mapping(program, pluralize: true, no_capitalize: true)
    options = [
      get_option_for_bulk_send_message_to_groups(group_ids, program, Connection::Membership::SendMessage::ALL, program_roles)
    ]

    program.roles.for_mentoring.each do |role|
      options << get_option_for_bulk_send_message_to_groups(group_ids, program, role.name, program_roles)
    end

    options << get_option_for_bulk_send_message_to_groups(group_ids, program, Connection::Membership::SendMessage::OWNER, program_roles) if program.project_based?
    return options.select{|option| option.present?}
  end

  def get_option_for_bulk_send_message_to_groups(group_ids, program, type_or_role, program_roles)
    role_term = program_roles[type_or_role]
    users_count_string = get_users_count_string_for_bulk_send_message_to_groups_of_type(group_ids, program, type_or_role)
    if users_count_string.present?
      case type_or_role
      when Connection::Membership::SendMessage::ALL
        return ["feature.connection.content.send_message_to_all".translate(mentoring_connections: _mentoring_connections, users_count_string: users_count_string), type_or_role]
      when Connection::Membership::SendMessage::OWNER
        return ["feature.connection.content.send_message_to_owners".translate(mentoring_connections: _mentoring_connections, users_count_string: users_count_string), type_or_role]
      else
        return ["feature.connection.content.send_message_to_role".translate(role_term: role_term, mentoring_connections: _mentoring_connections, users_count_string: users_count_string), type_or_role]
      end
    else
      return []
    end
  end

  def get_users_count_string_for_bulk_send_message_to_groups_of_type(group_ids, program, type_or_role)
    count = Connection::Membership.user_ids_in_groups(group_ids, program, type_or_role).count
    count.zero? ? nil : "feature.connection.content.users_number".translate(count: count)
  end

  def construct_date_filter_for_groups(filter_name, input_box_name, daterange_values, options = {})
    content = get_safe_string
    content += profile_filter_wrapper filter_name, daterange_values.blank?, false, false, options do
      construct_daterange_picker("search_filters[#{input_box_name}]", daterange_values, options.merge(input_size_class: "input-sm", right_addon: groups_filter_input_group_submit_options(get_input_group_options(options[:is_reports_view])))) +
        link_to_function("feature.connection.action.reset".translate, %Q[DateRangePicker.clearInputs("#search_filters_#{input_box_name}")\; GroupSearch.applyFilters()\;], id: "reset_filter_#{input_box_name}", style: "display:none")
    end
    content
  end

  def generate_data_for_groups_date_filters(input_box_name, start_time = nil, end_time = nil, is_reports_view=false)
    case input_box_name
    when "expiry_date"
      filter_name = "feature.connection.header.Closes_on".translate
      daterange_presets = [DateRangePresets::NEXT_7_DAYS, DateRangePresets::NEXT_30_DAYS, DateRangePresets::CUSTOM]
      min_date = Date.current
      max_date = ""
    when "started_date"
      filter_name = "feature.connection.header.Started_on".translate
      daterange_presets = [DateRangePresets::LAST_7_DAYS, DateRangePresets::LAST_30_DAYS, DateRangePresets::CUSTOM]
      min_date = ""
      max_date = Date.current
    when "closed_date"
      filter_name = "feature.connection.header.Closed_on".translate
      daterange_presets = [DateRangePresets::LAST_7_DAYS, DateRangePresets::LAST_30_DAYS, DateRangePresets::CUSTOM]
      min_date = ""
      max_date = Date.current
    when "close_date"
      filter_name = "feature.connection.header.Close_date".translate
      daterange_presets = [DateRangePresets::LAST_7_DAYS, DateRangePresets::LAST_30_DAYS, DateRangePresets::TODAY, DateRangePresets::NEXT_7_DAYS, DateRangePresets::NEXT_30_DAYS, DateRangePresets::CUSTOM]
      min_date = ""
      max_date = ""
    end
    daterange_values = start_time.present? ? { start: start_time.to_date, end: end_time.to_date } : {}

    daterange_options = { presets: daterange_presets, min_date: min_date, max_date: max_date}
    daterange_options.merge!(get_profile_filter_wrapper_for_groups(filter_name, is_reports_view))
    daterange_options.merge!(is_reports_view: is_reports_view)
    return filter_name, input_box_name, daterange_values, daterange_options
  end

  def generate_connection_summary_expires(group)
    if group.closed?
      label = "feature.connection.header.Closed_on".translate
      value = formatted_time_in_words(group.closed_at, :no_ago => true, :no_time => true)
    else
      label = "feature.connection.header.Expires_on".translate
      value = content_tag(:span, formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true), class: "cjs_expiry_in_group")
    end
    value += fetch_date_change_action(group) unless group.closed_or_expired?
    embed_display_line_item(label, value, heading_class: "group_expires_on", content_class: "group_expires_in")
  end

  def select_box_in_checkin_form_for(hours_or_minutes, form, task_id, checkin_id)
    values_and_names =
    if hours_or_minutes == :hours
      selected = 0
      (0..100).map { |n| [n, n] }
    elsif hours_or_minutes == :minutes
      selected = 30
      (0..59).select { |num| (num % GroupCheckin::CHECKIN_MINUTE_STEP).zero? }.map { |n| [n, n] }
    end
    form.select hours_or_minutes, options_for_select(values_and_names, selected), {}, class: "fixed-spinner form-control", id: "checkin_#{hours_or_minutes}_#{task_id}_#{checkin_id}", style: "width:75px;"
  end

  def render_allow_to_join(groups, is_bulk_action = false)
    is_pending_project = Array(groups).all? { |group| group.project_based? && group.pending? }
    return unless is_pending_project && current_program.allows_users_to_apply_to_join_in_project?
    param_prefix = is_bulk_action ? "bulk_actions" : "group"
    field_name = "#{param_prefix}[membership_settings][allow_join]"
    field_label = current_program.slot_config_enabled? ? "feature.connection.content.allow_to_join_with_slots".translate(circle: _mentoring_connection) : "feature.connection.content.allow_to_join".translate(circle: _mentoring_connection)
    hidden_field_tag(field_name, false, id: nil) +
    content_tag(:label, class: "checkbox") do
      check_box_tag(field_name, true, true) + field_label
    end
  end

  def render_roles_for_join_settings(group)
    roles = group.program.roles.for_mentoring.with_permission_name(RolePermission::SEND_PROJECT_REQUEST).includes(customized_term: :translations)
    available_roles = group.available_roles_for_joining(roles.pluck(:id), dont_consider_slots: true)

    choices_wrapper("display_string.Roles".translate) do
      content = get_safe_string
      roles.each do |role|
        field_name = "group[role_permission][#{role.id}]"
        content += hidden_field_tag(field_name, false, id: nil) +
        content_tag(:label, class: "checkbox") do
          check_box_tag(field_name, true, role.in?(available_roles)) +
          role.customized_term.term
        end
      end
      content
    end
  end

  def group_start_date_with_set_start_date_content(group, start_date)
    if start_date.present?
      start_date_with_update_date_content(group, start_date)      
    else
      set_new_start_date_content(group)      
    end
  end

  def start_date_with_update_date_content(group, start_date)
    get_safe_string + content_tag(:span, DateTime.localize(start_date, format: :short), class: "#{'text-danger' if group.has_past_start_date?(wob_member)} m-r-xxs") + "(" + link_to("feature.connection.content.change_date".translate, "javascript:void(0)", class: "cjs_set_or_edit_connection_start_date", data: {url: get_edit_start_date_popup_group_path(id: group.id)}) + ")"
  end

  def set_new_start_date_content(group)
    get_safe_string + content_tag(:span, "feature.connection.content.Not_set".translate, class: "m-r-xxs") + "(" + link_to("feature.connection.content.set_date".translate, "javascript:void(0)", class: "cjs_set_or_edit_connection_start_date", data: {url: get_edit_start_date_popup_group_path(id: group.id)}) + ")"
  end

  def render_start_date_content(group, user)
    program = group.program
    return unless program.project_based? && user.can_be_shown_group_start_date?(group)

    start_date = group.start_date
    return if (!start_date.present? || group.has_past_start_date?(wob_member)) && !user.can_set_start_date_for_group?(group)

    content_tag(:div, :class => "m-b-sm cjs_circle_start_date_#{group.id}") do
      content_tag(:h4, "feature.connection.content.start_date_label".translate, :class => "m-t-sm m-b-xs") +
      content_tag(:div) do
        get_start_date_content(group, user, start_date)        
      end
    end
  end

  def get_start_date_content(group, user, start_date)
    if user.can_set_start_date_for_group?(group)
      group_start_date_with_set_start_date_content(group, start_date)
    else
      DateTime.localize(start_date, format: :short)
    end
  end

  def render_add_tasks_for_project_requests(form, project_request_ids)
    active_project_requests = current_program.project_requests.where(id: project_request_ids).joins(:group).where(groups: { status: Group::Status::ACTIVE_CRITERIA })
    return unless active_project_requests.present?

    users_count = active_project_requests.group_by(&:sender_id).size
    groups_count = active_project_requests.group_by(&:group_id).size
    add_tasks_label = content_tag(:span, "feature.project_request.content.bulk_accept_request_popup.add_tasks".translate(circles: _mentoring_connections), class: "m-l-sm")
    no_task_label = content_tag(:span, "feature.project_request.content.bulk_accept_request_popup.dont_add_tasks".translate(circles: _mentoring_connections), class: "m-l-sm")

    connection_term = groups_count == 1 ? _a_mentoring_connection : _mentoring_connections
    requests_for_active_groups = users_count == 1 ? "feature.connection.content.single_project_requestor".translate(count: groups_count, mentoring_connection_term: connection_term) : "feature.connection.content.multiple_project_requestors".translate(count: groups_count, users_count: users_count, mentoring_connection_term: connection_term)

    content_tag(:div, class: "m-t-md clearfix m-b-md") do
      content_tag(:div, "#{requests_for_active_groups} #{'feature.connection.content.choose_an_option'.translate}") +
      content_tag(:div, class: "m-l-md clearfix") do
        get_add_tasks_radio_button(form, add_tasks: add_tasks_label, no_task: no_task_label)
      end
    end
  end

  def get_add_tasks_radio_button(form, radio_options)
    radio_button_options = [{label: radio_options[:add_tasks], value: Group::AddOption::ADD_TASKS}, {label: radio_options[:no_task], value: Group::AddOption::NO_TASK}]
    content = get_safe_string
    radio_button_options.each do |options|
      content +=  content_tag(:span, class: "radio") do
                    r_id = "group_add_member_option_#{options[:value]}_#{radio_options[:id_suffix]}"
                    content_tag(:label, for: r_id) do
                      form.radio_button(:add_member_option, options[:value], checked: (options[:value] == Group::AddOption::ADD_TASKS), class: "radio_buttons", id: r_id) + options[:label]
                    end
                  end
    end
    control_group(class: "col-xs-12 no-padding m-b-xs") do
      choices_wrapper('feature.connection.content.choose_an_option'.translate) do
        content
      end
    end
  end

  def get_remove_tasks_radio_button(form, radio_options)
    radio_button_options = [{label: radio_options[:remove_tasks], value: Group::RemoveOption::REMOVE_TASKS}, {label: radio_options[:leave_tasks], value: Group::RemoveOption::LEAVE_TASKS_UNASSIGNED}]
    content = get_safe_string
    radio_button_options.each do |options|
      content +=  content_tag(:span, class: "radio") do
                    r_id = "group_remove_member_option_#{options[:value]}_#{radio_options[:id_suffix]}"
                    content_tag(:label, for: r_id) do
                      form.radio_button(:remove_member_option, options[:value], checked: (options[:value] == Group::RemoveOption::REMOVE_TASKS), class: "radio_buttons", id: r_id) + options[:label]
                    end
                  end
    end
    control_group(class: "col-xs-12 no-padding m-b-xs") do
      choices_wrapper('feature.connection.content.choose_an_option'.translate) do
        content
      end
    end
  end

  def get_publish_action(group, options = {src: ""})
    is_web_view = !options[:mobile_view]
    {
      label: append_text_to_icon("fa fa-check", options[:btn_text] || "feature.connection.action.Publish_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
      js: %Q[jQueryShowQtip(null, null, '#{fetch_publish_group_path(group, src: options[:src], ga_src: options[:ga_src])}','')],
      class: "btn btn-primary publish_group_#{group.id}_#{is_web_view ? 'web' : 'mobile'} #{options[:btn_class]}",
      btn_class_name: "btn btn-primary publish_group_#{group.id}_#{is_web_view ? 'web' : 'mobile'} #{options[:btn_class]}"
    }
  end

  def get_page_title_for_new_group_creation(propose_view, current_user)
    if propose_view
      current_user.can_create_group_without_approval? ? "feature.connection.header.start_a_new".translate(:Mentoring_Connection => _Mentoring_Connection) : "feature.connection.header.propose_a_new".translate(:Mentoring_Connection => _Mentoring_Connection) 
    else
      "feature.connection.header.new".translate(:Mentoring_Connection => _Mentoring_Connection)
    end
  end

  def fetch_date_change_action(group, options = {})
    if current_program.allow_to_change_connection_expiry_date? || current_user.can_manage_or_own_group?(group)
      action_label = options[:home_page] ? "feature.connection.action.extend".translate : "feature.connection.action.change".translate
      action_url = set_expiry_date_group_path(group)
      action_id = "set_expiry_date_#{group.id}"
    else
      action_label = "feature.connection.action.request_for_change_v1".translate
      action_url = contact_admin_path(:req_change_expiry => true, :group_id => group.id)
      action_id = "request_expiry_date_#{group.id}"
    end
    link_to_function action_label, %Q[jQueryShowQtip('#cjs_connection_summary', 600, '#{action_url}','',{modal: true})], :id => action_id
  end

  def get_grouped_select_options_for_closure_reasons(program)
    permitted_closure_reasons = program.permitted_closure_reasons.non_default
    select_options = {}
    select_options["feature.group_closure_reasons.category.completed_connections".translate(Mentoring_Connections: _Mentoring_Connections)] = permitted_closure_reasons.completed.map { |closure_reason| [closure_reason.reason, closure_reason.id] }
    select_options["feature.group_closure_reasons.category.incomplete_connections".translate(Mentoring_Connections: _Mentoring_Connections)] = permitted_closure_reasons.incomplete.map { |closure_reason| [closure_reason.reason, closure_reason.id] }

    grouped_options_for_select(select_options.select{|_k, v| v.present? }, permitted_closure_reasons.first.id)
  end

  def get_add_member_link(role, role_terms_hash_single, no_members_with_role)
    link_class = "btn btn-primary btn-xs pull-right cjs_add_member cjs_add_member_#{role.name}"
    unless @current_program.allow_one_to_many_mentoring?
      return "" if RoleConstants::MENTORING_ROLES.include?(role.name)
      link_class = "#{link_class} hide" unless no_members_with_role
    end
    link_to(get_icon_content("fa fa-user-plus") + "feature.group.action.add_member_v1".translate(role_name: role_terms_hash_single[role.name]), "javascript:void(0);", class: link_class, data: { role_name: role.name })
  end

  private

  def get_closed_group_actions(program)
    actions = [{ label: append_text_to_icon("fa fa-undo", "feature.connection.action.Reactivate_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)), class: "cjs_bulk_action_groups", url: "javascript:void(0)", data: { url: fetch_bulk_actions_groups_path, action_type: Group::BulkAction::REACTIVATE } }]
    return actions if program.project_based?
    action_type = Group::BulkAction::DUPLICATE
    bulk_limit = Group::BulkActionLimit[action_type]
    bulk_limit_exceeded_warning = "feature.connection.content.bulk_limit_exceeded".translate(count: bulk_limit, mentoring_connections_term: _mentoring_connections)
    label = append_text_to_icon("fa fa-copy", "feature.connection.action.duplicate_connection".translate(Mentoring_Connection: _Mentoring_Connections))
    actions << { label: label, class: "cjs_bulk_action_groups", url: "javascript:void(0)", data: { url: fetch_bulk_actions_groups_path, action_type: action_type, bulk_limit: bulk_limit, bulk_limit_exceeded_warning: bulk_limit_exceeded_warning }}
  end

  def get_role_limits(group, group_roles)
    role_limits = []
    group_roles.each do |role|
      group_setting = group.setting_for_role_id(role.id, false)
      slots_left = if group_setting.try(:max_limit).present?
        number_of_slots_left = group_setting.max_limit - group.memberships.select{|membership| membership.role_id == role.id}.size
        number_of_slots_left > 0 ? "feature.connection.content.slot_limit".translate(slots_left: number_of_slots_left, max_limit: group_setting.max_limit) : "feature.connection.content.n_slots_left_v1".translate(count: 0)
      else
        "feature.connection.content.no_limit".translate
      end
      role_limits << content_tag(:span, "#{role.customized_term.pluralized_term} : #{slots_left}", class: "m-t")
    end
    safe_join(role_limits, tag(:br))
  end

  def get_group_label_for_auto_complete(group, icon_class = nil)
    label = if group.pending?
      display_group_data(formatted_time_in_words(group.pending_at, no_ago: true, no_time: true), 'feature.connection.header.pending_label'.translate, icon_class)
    else
      display_group_data(formatted_time_in_words(group.published_at, no_ago: true, no_time: true), "#{'feature.connection.header.Started_on'.translate} : ", icon_class)
    end
    content_tag(:div, label, class: "#{'label label-success' unless icon_class.present?}")
  end

  def get_inconsistent_roles_reason(program, inconsistent_roles)
    reason_string = []
    program_roles_pluralized = RoleConstants.program_roles_mapping(program, pluralize: true, no_capitalize: true)
    program_roles = RoleConstants.program_roles_mapping(program, no_capitalize: true)
    inconsistent_roles.each do |role, users|
      users_sentence = get_safe_string + users.collect(&:name).to_sentence
      reason_string << "feature.group.user_no_longer_role".translate(user_names: users_sentence, count: users.size, role_name: program_roles[role.name], role_names: program_roles_pluralized[role.name])
    end
    reason_string.to_sentence
  end

  def expired_text(options = {})
    content_tag(:span, "feature.connection.content.expires_soon".translate, class: "label label-danger #{options[:class]}")
  end

  def get_dashboard_filters_in_groups_listing_flash(count, current_tab_count, filters, tab_number)
    ongoing_link = get_dashboard_filters_in_groups_listing_flash_ongoing_link(count, current_tab_count, filters, tab_number)
    closed_link = get_dashboard_filters_in_groups_listing_flash_closed_link(count, current_tab_count, filters, tab_number)
    time = "#{DateTime.localize(filters[:start_date].to_time, format: :abbr_short)} - #{DateTime.localize(filters[:end_date].to_time, format: :abbr_short)}"
    case filters[:type]
    when GroupsController::DashboardFilter::GOOD
      "feature.group.content.dashboard_filter.positive_html".translate(count: count, ongoing_count_link: ongoing_link, closed_count_link: closed_link, connection: _mentoring_connection, connections: _mentoring_connections, time: time)
    when GroupsController::DashboardFilter::NEUTRAL_BAD
      "feature.group.content.dashboard_filter.negative_html".translate(count: count, ongoing_count_link: ongoing_link, closed_count_link: closed_link, connection: _mentoring_connection, connections: _mentoring_connections, time: time)
    when GroupsController::DashboardFilter::NO_RESPONSE
      "feature.group.content.dashboard_filter.no_responses_html".translate(count: count, ongoing_count_link: ongoing_link, closed_count_link: closed_link, connection: _mentoring_connection, connections: _mentoring_connections, time: time)
    end
  end

  def get_dashboard_filters_in_groups_listing_flash_ongoing_link(count, current_tab_count, filters, tab_number)
    ongoing_count = (tab_number == Group::Status::ACTIVE) ? current_tab_count : (count - current_tab_count)
    link_to(ongoing_count, groups_path(tab: Group::Status::ACTIVE, dashboard: filters))
  end

  def get_dashboard_filters_in_groups_listing_flash_closed_link(count, current_tab_count, filters, tab_number)
    closed_count = (tab_number == Group::Status::CLOSED) ? current_tab_count : (count - current_tab_count)
    link_to(closed_count, groups_path(tab: Group::Status::CLOSED, dashboard: filters))
  end

  def get_view_all_mentoring_connection_side_pane(active_groups_count, closed_groups_size, is_pbe)
    options = { show: "my", src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION }
    label = "display_string.View_All".translate

    if active_groups_count > 0
      options[:tab] = Group::Status::ACTIVE if is_pbe
    elsif closed_groups_size > 0
      options.merge!({
          tab: Group::Status::CLOSED,
          view: Group::View::DETAILED,
       })
      label = "tab_constants.sub_tabs.closed".translate
    end
    return groups_path(options), label
  end

  def get_discussions_tab_label(tab_text, badge_count, icon_class, options = {})
    icon_content = get_icon_content("#{icon_class}")
    badge_count_label = get_badge_count_label(badge_count, options)
    tab_text_label = content_tag(:span, tab_text, class: "#{options[:text_class]} #{'hidden-xs' unless options[:show_in_dropdown]}")
    mobile_tab_text_label = options[:home_page] && !options[:show_in_dropdown] ? content_tag(:div, tab_text, class: "m-r-xxs visible-xs small m-t-xs font-bold") : ""
    if options[:show_in_dropdown]
      icon_content + tab_text_label + badge_count_label + mobile_tab_text_label
    else
      icon_content + badge_count_label + tab_text_label + mobile_tab_text_label
    end
  end

  def get_badge_count_label(badge_count, options = {})
    content_tag(:span, badge_count, class: "rounded label label-danger #{options[:badge_class]} #{options[:show_in_dropdown] ? 'm-l-xs m-t-3' : 'cui_count_label' }") if badge_count > 0
  end
end