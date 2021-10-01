module ProjectRequestsHelper

  OPTIONS_FOR_ACTION = {
      AbstractRequest::Status::ACCEPTED => { label_key: "display_string.Accept", icon: "fa-check" },
      AbstractRequest::Status::REJECTED => { label_key: "display_string.Reject", icon: "fa-times", reason_key: 'feature.project_request.content.bulk_reject_request_popup.rejection_reason' },
      AbstractRequest::Status::WITHDRAWN => { label_key: "feature.project_request.content.withdraw_request_popup.action.withdraw_request", icon: "fa-undo", reason_key: 'feature.project_request.content.withdrawal_reason' },
      AbstractRequest::Status::CLOSED => { reason_key: 'feature.project_request.content.closing_reason' }
  }

  def project_requests_bulk_actions(ga_src, is_manage_view)
    action_class = "cjs_bulk_action_project_requests"
    bulk_actions = [
      get_project_request_action(AbstractRequest::Status::ACCEPTED, class: action_class, id: "cjs_bulk_accept_request", ga_src: ga_src, is_manage_view: is_manage_view),
      get_project_request_action(AbstractRequest::Status::REJECTED, class: action_class, id: "cjs_bulk_reject_request", ga_src: ga_src, is_manage_view: is_manage_view)
    ]

    build_dropdown_button("display_string.Actions".translate, bulk_actions, btn_class: "cur_page_info", btn_group_btn_class: "btn-white", is_not_primary: true)
  end

  def actions_for_project_requests_listing(request, options = {})
    actions = []
    if request.active?
      action_class = "cjs_action_project_requests"
      data = { id: request.id }
      actions << get_project_request_action(AbstractRequest::Status::ACCEPTED, class: "#{action_class}", data: data, ga_src: options[:ga_src], is_manage_view: options[:is_manage_view])
      actions << get_project_request_action(AbstractRequest::Status::REJECTED, class: "#{action_class} cjs_reject_request", data: data, ga_src: options[:ga_src], is_manage_view: options[:is_manage_view])
      actions << get_project_request_action(AbstractRequest::Status::WITHDRAWN, class: "#{action_class} cjs_reject_request", data: data, ga_src: options[:ga_src], is_manage_view: options[:is_manage_view]) if current_user == request.sender
    end
    dropdown_buttons_or_button(actions, dropdown_title: 'display_string.Actions'.translate, :btn_class => options[:btn_class], :dropdown_menu_class => options[:dropdown_menu_class], :responsive_primary_btn_class => options[:responsive_primary_btn_class])
  end

  def get_withdraw_project_request_action_button(project_request, ga_src)
    return unless project_request.active?
    withdraw_action = get_project_request_action(AbstractRequest::Status::WITHDRAWN, additional_class: "cjs_action_project_requests cjs_withdraw_request m-t-sm", data: { id: project_request.id }, ga_src: ga_src)
    dropdown_buttons_or_button([withdraw_action])
  end

  def get_status_filter_for_project_requests(filter_options, status_filter_first)
    profile_filter_wrapper "feature.project_request.content.filters.Status".translate, false, true, status_filter_first, id: "status" do
      content = get_safe_string

      ProjectRequest::STATUS_KEYS.each do |status|
        should_be_checked = filter_options[:status] == status || (status == AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED] && filter_options[:status].blank?)
        label = "feature.project_request.status.#{status.capitalize}".translate
        content += content_tag(:label, class: 'radio') do
          radio_button_tag("filters[status]", status, should_be_checked, class: "submit_project_request_filters") + label
        end
      end

      content += link_to("display_string.reset".translate, "javascript: void(0)", id: "reset_filter_status", class: "hide reset_filters")
      content
    end
  end

  def get_view_filter_for_project_requests(filter_options)
    profile_filter_wrapper "feature.project_request.content.filters.view".translate, false, true, true, id: "view" do
      content = get_safe_string
      ProjectRequest::VIEW.all.each do |view|
        should_be_checked = filter_options[:view].to_i == view || (view == ProjectRequest::VIEW::TO && filter_options[:view].blank?)
        label = get_label_for_view_filter(view, should_be_checked)
        content += content_tag(:label, class: 'radio') do
          radio_button_tag("filters[view]", view, should_be_checked, class: "submit_project_request_filters") + label
        end
      end

      content + link_to("display_string.reset".translate, "javascript: void(0)", id: "reset_filter_view", class: "hide reset_filters")
    end
  end

  # 'Requestor' and 'Project' filters
  def get_search_filter_for_project_requests(field_name, filter_params, is_first = false, collapsed = true, options = {})
    input_id = options[:id] || "filters_#{field_name}"
    value = filter_params[field_name].to_s
    title = "feature.project_request.content.filters.#{field_name}".translate(Mentoring_Connection: _Mentoring_Connection)
    filter_field_element = label_tag(:filters, title, for: input_id, class: 'sr-only') + text_field(:filters, field_name, value: value, id: input_id, class: "form-control input-sm") + link_to("display_string.Clear".translate, "javascript: void(0)", class: 'clear_filter btn btn-xs hide', id: "reset_filter_#{field_name}")
    profile_filter_wrapper(title, collapsed, true, is_first, options) do
      options[:skip_go_button].present? ? filter_field_element : construct_input_group([], get_go_button_for_project_request_filter, {}){ filter_field_element }
    end
  end

  def show_find_new_project?(user, filter_params)
    (user.can_manage_project_requests?) || (!user.has_owned_groups?) || (!user.can_manage_project_requests? && filter_params.present? && (filter_params[:view].to_i == ProjectRequest::VIEW::FROM))
  end

  def get_reason_for_project_request_non_acceptance(project_request)
    return unless project_request.rejected? || project_request.closed? || project_request.withdrawn?
    reason_label = OPTIONS_FOR_ACTION[project_request.status][:reason_key].translate
    profile_field_container_wrapper("#{reason_label}", (project_request.response_text.present? ? project_request.response_text : content_tag(:i, "common_text.Not_specified".translate)), heading_tag: :h4, class: "m-t-xs m-b-xs")
  end

  def get_reject_or_withdraw_project_request_messages_hash(status, project_request_count)
    status == AbstractRequest::Status::REJECTED ? get_reject_project_request_messages_hash(project_request_count) : get_withdraw_project_request_messages_hash
  end

  def get_tabs_for_project_requests_listing(active_tab)
    label_tab_mapping = {
      'feature.project_request.status.Pending'.translate => ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::NOT_ANSWERED],
      'feature.project_request.status.Accepted'.translate => ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::ACCEPTED],
      'feature.project_request.status.Rejected'.translate => ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::REJECTED],
       'feature.project_request.status.Withdrawn'.translate => ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::WITHDRAWN],
      'feature.project_request.status.closed'.translate => ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::CLOSED]
    }
    get_tabs_for_listing(label_tab_mapping, active_tab, url: manage_project_requests_path, param_name: :status)
  end

  private

  def get_go_button_for_project_request_filter
    {
      type: "btn",
      btn_options: {
        class: "btn btn-primary btn-sm no-margins submit_project_request_filters"
      },
      content: "display_string.Go".translate,
      class: "filter_actions form-actions"
    }
  end

  def get_reject_project_request_messages_hash(project_request_count)
    {
      modal_header: "feature.project_request.content.bulk_reject_request_popup.title".translate(count: project_request_count),
      placeholder_for_reason: "feature.project_request.content.bulk_reject_request_popup.placeholder.reason".translate(count: project_request_count, mentoring_connection: _mentoring_connection),
      label_for_reason: "feature.project_request.content.bulk_reject_request_popup.rejection_reason".translate,
      submit_text: "feature.project_request.content.bulk_reject_request_popup.action.reject_request".translate(count: project_request_count)
    }
  end

  def get_withdraw_project_request_messages_hash
    {
      modal_header: "feature.project_request.content.withdraw_request_popup.action.withdraw_request".translate,
      placeholder_for_reason: "feature.project_request.content.withdraw_request_popup.placeholder.reason".translate(mentoring_connection: _mentoring_connection),
      label_for_reason: "feature.project_request.content.withdraw_request_popup.withdrawal_reason".translate,
      submit_text: "feature.project_request.content.withdraw_request_popup.action.withdraw_request".translate
    }
  end

  def get_project_request_action(type, options = {})
    label = OPTIONS_FOR_ACTION[type][:label_key].translate
    icon = OPTIONS_FOR_ACTION[type][:icon]
    data = { url: fetch_actions_project_requests_path(src: options[:ga_src], is_manage_view: options[:is_manage_view]), request_type: type }
    data.merge!(options[:data]) if options[:data].present?
    {
      label: append_text_to_icon("fa #{icon}", label),
      url: "javascript:void(0)",
      class: options[:class],
      id: options[:id],
      additional_class: options[:additional_class],
      data: data
    }
  end

  def get_label_for_view_filter(view, should_be_checked)
    label = (view == ProjectRequest::VIEW::TO) ? "feature.mentor_request.content.filter.requests_to_me_v2".translate : "feature.mentor_request.content.filter.requests_by_me_v2".translate
    should_be_checked ? content_tag(:b, label) : label
  end
end
