module MeetingRequestsHelper
  def meeting_request_actions(meeting_request, options = {})
    actions = []
    if meeting_request.active?
      actions << {label: get_icon_content("fa fa-ban") + "#{'feature.meeting_request.action.close_request'.translate}", class: "cjs_close_request cjs_individual_action_meeting_requests #{options[:btn_class]}", url: 'javascript:void(0)', data: {url: fetch_bulk_actions_meeting_requests_path, request_type: AbstractRequest::Status::CLOSED, meeting_request: meeting_request.id, is_manage_view: options[:is_manage_view]}}
    end
    dropdown_buttons_with_title_or_button_without_title(actions, {dropdown_title: 'display_string.Actions'.translate}.merge(options))
  end

  def dropdown_buttons_with_title_or_button_without_title(actions, options)
    if actions.size == 1
      options.delete(:dropdown_title)
      actions.first[:class] ||= ''
      actions.first[:class] += ' btn btn-primary'
    end
    dropdown_buttons_or_button(actions, options) unless actions.blank?
  end

  def get_meeting_request_action(meeting_request, mentor_viewing, filter, options = {})
    meeting = meeting_request.get_meeting
    return if (!options[:skip_expiry_check] && is_slot_expired?(meeting, options))
    user_in_context = mentor_viewing ? meeting_request.mentor : meeting_request.student
    secret_key = user_in_context.member.calendar_api_key
    program_id = meeting_request.program_id

    if mentor_viewing && meeting_request.active?
      if options[:accept_button]
        url = update_status_meeting_request_path(meeting_request, program: program_id, secret: secret_key, status: AbstractRequest::Status::ACCEPTED, filter: filter, slot_id: options[:slot].try(:id), src: options[:source].to_s, additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT)
      else
        url = update_status_meeting_request_path(meeting_request, program: program_id, secret: secret_key, status: AbstractRequest::Status::REJECTED, filter: filter, slot_id: options[:slot].try(:id))
      end

      action_button = options[:accept_button] ? link_to(append_text_to_icon("fa fa-user-plus", content_tag(:span, "feature.meeting_request.action.accept_request".translate, class: "hidden-xs #{'sr-only' if options[:show_mobile_view]}")), url, class: "cjs_accept_meeting_slot btn btn-primary btn-outline btn-sm", data: {disable_with: "display_string.Please_Wait".translate, method: :get}) : link_to(append_text_to_icon("fa fa-user-times", content_tag(:span, "feature.meeting_request.action.decline_request".translate, class: "hidden-xs #{'sr-only' if options[:show_mobile_view]}")), "javascript:void(0)", class: "btn btn-danger btn-outline btn-sm cjs_meeting_request_reject_link_#{meeting_request.id}")
    elsif meeting_request.active? && filter == AbstractRequest::Filter::BY_ME
      action_button = link_to(append_text_to_icon("fa fa-undo", content_tag(:span, 'feature.meeting_request.action.withdraw'.translate, class: "hidden-xs")), update_status_meeting_request_path(meeting_request, program: program_id, secret: secret_key, status: AbstractRequest::Status::WITHDRAWN, filter: filter), class: "btn btn-warning btn-sm cjs_withdraw_meeting_request")
    end
    if filter == AbstractRequest::Filter::ALL
      action_button = link_to(append_text_to_icon("fa fa-ban", content_tag(:span, 'feature.meeting_request.action.close_request'.translate, class: "hidden-xs")), "javascript:void(0)", class: "cjs_individual_action_meeting_requests btn btn-primary btn-sm", id: "cjs_close_request", :data => {:url => fetch_bulk_actions_meeting_requests_path, :request_type => AbstractRequest::Status::CLOSED, :meeting_request => meeting_request.id})
    end
    action_button
  end

  def is_slot_expired?(meeting, options)
    return options[:slot].start_time < Time.now if options[:slot].present?
    meeting.archived?(meeting.start_time)
  end

  def link_calendar(member, meeting_request, is_mentor_action)
    meeting = meeting_request.get_meeting
    (meeting_request.withdrawn? || meeting_request.rejected?) ? meeting_time_for_display(meeting) :
      link_to(meeting_time_for_display(meeting), member_path(member,
        tab: MembersController::ShowTabs::AVAILABILITY, meeting_id: meeting.id, src: "upcoming"),
        class: "cjs-tool-tip", data: {desc: "feature.meetings.content.view_in_meetings_v1".translate(:meetings => _meetings)})
  end

  def meeting_requests_bulk_actions
    bulk_actions = [
    ]
    if (@is_manage_view || (@filter_field == AbstractRequest::Filter::ALL)) && (@status_type == MeetingRequest::Filter::ACTIVE)
      bulk_actions << {:label => get_icon_content("fa fa-ban") + "feature.meeting_request.action.close_requests".translate, :url => "javascript:void(0)", :class => "cjs_bulk_action_meeting_requests", :id => "cjs_close_requests",
      :data => {url: fetch_bulk_actions_meeting_requests_path, request_type: AbstractRequest::Status::CLOSED, is_manage_view: @is_manage_view}}
    end
    build_dropdown_button("display_string.Actions".translate, bulk_actions, :btn_class => "cur_page_info", :btn_group_btn_class => "btn-white btn no-vertical-margins", :is_not_primary => true) unless bulk_actions.blank?
  end

  def get_meeting_request_acceptance_help_text(meeting_request)
    meeting = meeting_request.get_meeting
    if meeting.calendar_time_available?
      'feature.mentor_request.content.accept_popup.calendar_time_message'.translate(user_name: link_to_user(meeting_request.student, {no_link: true, no_hovercard: true}))
    else
      'feature.mentor_request.content.accept_popup.non_calendar_time_message'.translate(user_name: link_to_user(meeting_request.student, {no_link: true, no_hovercard: true}))
    end
  end

  def get_meeting_request_action_popup_and_popup_id(meeting_requests, meeting_request, status)
    action_popup = nil
    action_popup_id = nil

    unless meeting_requests.include?(meeting_request)
      if status == AbstractRequest::Status::ACCEPTED
        action_popup = { partial: "meeting_requests/accept_popup", locals: { meeting_request: meeting_request, is_mentor_action: true } }
      elsif status == AbstractRequest::Status::REJECTED
        action_popup = { partial: "meeting_requests/reject_popup", locals: { meeting_request: meeting_request, is_mentor_action: true, reject: true } }
      end
    end
    action_popup_id = get_meeting_request_action_popup_id(meeting_request, status)
    return action_popup, action_popup_id
  end

  def get_meeting_request_action_popup_id(meeting_request, status, options={})
    if status == AbstractRequest::Status::ACCEPTED
      options[:propose_slot] ? "modal_meeting_request_propose_link_#{meeting_request.id}" : "modal_meeting_request_accept_link_#{meeting_request.id}"
    elsif status == AbstractRequest::Status::REJECTED
      "modal_meeting_request_reject_link_#{meeting_request.id}"
    end
  end

  def get_tabs_for_meeting_requests_listing(active_tab)
    label_tab_mapping = {
      "feature.meeting_request.label.pending".translate => AbstractRequest::Filter::ACTIVE,
      "feature.meeting_request.label.accepted".translate => AbstractRequest::Filter::ACCEPTED,
      "feature.meeting_request.label.declined".translate => AbstractRequest::Filter::REJECTED,
      "feature.meeting_request.label.withdrawn".translate => AbstractRequest::Filter::WITHDRAWN,
      "feature.meeting_request.label.closed".translate => AbstractRequest::Filter::CLOSED
    }
    get_tabs_for_listing(label_tab_mapping, active_tab, url: manage_meeting_requests_path, param_name: :list)
  end
end