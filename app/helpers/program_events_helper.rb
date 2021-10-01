module ProgramEventsHelper
  def fetch_user_info(user, questions, user_info)
    answer = user.answer_for(questions)
    value = case user_info
    when "experience"
      answer.present? && (experience = answer.experiences.first) ? "#{experience.company}" : ""
    when "education"
      answer.present? && (education = answer.educations.first) ? "#{education.school_name}" : ""
    when "location"
      answer.present? && (location = answer.location) ? location.full_address : ""
    when "join_date"
      "common_text.Member_since".translate(:since_time => DateTime.localize(user.created_at, format: :full_month_year))
    end
    return value
  end

  def get_image_class(user, program_event, status)
    user_invite = program_event.event_invites.for_user(user).first
    (user_invite.present? && status == user_invite.status) ? "" : "hide"
  end

  def users_invited_label(program_event)
    users_count = program_event.program_event_users.count
    str = content_tag(:div, class: 'inline') do
      concat "feature.program_event.label.users_number".translate(count: users_count)
      if program_event.admin_view.present? && current_user.is_admin?
        concat " ( #{link_to("feature.program_event.label.view_details_html".translate(:arrow => get_icon_content("fa fa-chevron-down")), 'javascript:void(0)', :class => 'cjs_see_more_event_details')}".html_safe
        concat "#{link_to("feature.program_event.label.hide_details_html".translate(:arrow => get_icon_content("fa fa-chevron-up")), 'javascript:void(0)', :class => 'cjs_see_less_event_details hide')})".html_safe
      end
    end
    if program_event.admin_view.present? && current_user.is_admin?
      str << content_tag(:div, class: 'cjs_invited_details help-block m-b-0 hide') do
        admin_view_link = link_to(program_event.admin_view_title, admin_view_path_with_source(:show, admin_view: program_event.admin_view))
        if program_event.admin_view_fetched_at.present?
          concat "feature.program_event.description.users_invited_from_view_with_date_html".translate(admin_view_title_link: admin_view_link, date: DateTime.localize(program_event.admin_view_fetched_at, format: :abbr_short))
        else
          concat "feature.program_event.description.users_invited_from_view_html".translate(admin_view_title_link: admin_view_link)
        end
      end
    end
    str
  end

  def get_event_status_text(tab_number=ProgramEventConstants::Tabs::UPCOMING)
    case tab_number
    when ProgramEventConstants::Tabs::DRAFTED
      "feature.program_event.label.drafted".translate
    when ProgramEventConstants::Tabs::PAST
      "feature.program_event.label.past".translate
    else
      "feature.program_event.label.upcoming".translate
    end
  end

  def get_invite_reponse_text(status)
    response = case status
    when EventInvite::Status::YES
      "feature.program_event.content.attended".translate
    when EventInvite::Status::NO
      "feature.program_event.content.not_attend".translate
    when EventInvite::Status::MAYBE
      "feature.program_event.content.may_have_attended".translate
    end
    "feature.program_event.content.invite_response_text".translate(:response => response)
  end

  def invite_response_label(program_event, status, size)
    case status
    when EventInvite::Status::YES
      program_event.archived? ? "feature.program_event.label.Attended".translate : "feature.program_event.label.Attending".translate
    when EventInvite::Status::NO
      program_event.archived? ? "feature.program_event.label.Not_attended".translate : "feature.program_event.label.Not_attending".translate
    when EventInvite::Status::MAYBE
      program_event.archived? ? "feature.program_event.label.May_have_attended".translate : "feature.program_event.label.May_be_Attending".translate
    end
  end

  def get_reponse_label_tab_pane(program_event, tab_number)
    case tab_number
    when ProgramEventConstants::ResponseTabs::ATTENDING
      program_event.archived? ? "feature.program_event.label.Attended".translate : "feature.program_event.label.Attending".translate
    when ProgramEventConstants::ResponseTabs::NOT_ATTENDING
      program_event.archived? ? "feature.program_event.label.Not_attended".translate : "feature.program_event.label.Not_attending".translate
    when ProgramEventConstants::ResponseTabs::MAYBE_ATTENDING
      program_event.archived? ? "feature.program_event.label.May_have_attended".translate : "feature.program_event.label.May_be_Attending".translate
    when ProgramEventConstants::ResponseTabs::NOT_RESPONDED
      "feature.program_event.label.Not_responded".translate
    when ProgramEventConstants::ResponseTabs::INVITED
      "feature.program_event.label.Invited".translate
    end
  end

  def get_reponse_label_for_invited_list(program_event, user)
    event_invite = program_event.event_invites.for_user(user).first
    return content_tag(:span, "feature.program_event.label.Not_responded".translate, class: "small text-muted") if event_invite.blank?

    case event_invite.status
    when EventInvite::Status::YES
      content_tag(:span, append_text_to_icon("fa fa-check", (program_event.archived? ? "feature.program_event.label.Attended".translate : "feature.program_event.label.Attending".translate)), class: "label navy-bg text-white")
    when EventInvite::Status::NO
      content_tag(:span, append_text_to_icon("fa fa-times", (program_event.archived? ? "feature.program_event.label.Not_attended".translate : "feature.program_event.label.Not_attending".translate)), class: "label red-bg text-white")
    when EventInvite::Status::MAYBE
      content_tag(:span, append_text_to_icon("fa fa-exclamation", (program_event.archived? ? "feature.program_event.label.May_have_attended".translate : "feature.program_event.label.May_be_Attending".translate)), class: "label label-default")
    end
  end

  def event_date_for_display(program_event)
    get_time_for_time_zone(program_event.start_time, wob_member.get_valid_time_zone, "full_display_no_time_with_day".to_sym)
  end

  def get_event_time_in_time_zone(program_event, time_zone)
    event_time = if program_event.end_time.present?
      "#{get_time_for_time_zone(program_event.start_time, time_zone, "short_time_small".to_sym)} #{'display_string.to_for_dates_only'.translate} #{get_time_for_time_zone(program_event.end_time, time_zone, "short_time_small_with_zone".to_sym)}"
    else
      get_time_for_time_zone(program_event.start_time, time_zone, "short_time_small_with_zone".to_sym)
    end
  end

  def is_datetime_equal_in_zones(time, member_time_zone, event_time_zone, format)
    get_time_for_time_zone(time, member_time_zone, format.to_sym) ==
      get_time_for_time_zone(time, event_time_zone, format.to_sym)
  end

  def event_datetime_for_display_in_email(program_event, member = wob_member)
    event_time_zone = program_event.time_zone
    member_time_zone = member.time_zone
    date = get_time_for_time_zone(program_event.start_time, member_time_zone.presence || event_time_zone, "short".to_sym)
    time = if member_time_zone.present?
             get_event_time_in_time_zone(program_event, member_time_zone)
           else
             get_event_time_in_time_zone(program_event, event_time_zone)
           end
    [date, time].join(' ')
  end

  def event_time_for_display(program_event, member = wob_member)
    start_time = program_event.start_time
    event_time_zone = program_event.time_zone
    member_time_zone = member.get_valid_time_zone

    event_time_in_member_time_zone = get_event_time_in_time_zone(program_event, member_time_zone)

    # If program event time zone and member time zone are same or program event time zone is absent
    if event_time_zone.blank? || is_datetime_equal_in_zones(start_time, member_time_zone, event_time_zone, "short_time_small")
      event_time_in_member_time_zone
    else
      event_time_in_event_time_zone = get_event_time_in_time_zone(program_event, event_time_zone)
      # If time zones are different, we check for the dates on conversion
      if is_datetime_equal_in_zones(start_time, member_time_zone, event_time_zone, "date_range")
        "#{event_time_in_member_time_zone} (#{event_time_in_event_time_zone})".html_safe
      else
        "#{event_time_in_member_time_zone} (#{get_time_for_time_zone(start_time, event_time_zone, "abbr_short".to_sym)} #{event_time_in_event_time_zone})".html_safe
      end
    end
  end

  def event_location_for_display(program_event)
    program_event.location.present? ? program_event.location : 'common_text.Not_specified'.translate
  end

  def program_event_popover(program_event)
    content_tag(:div, get_icon_content('fa fa-calendar')+ event_date_for_display(program_event), :class => "m-b")+
    content_tag(:div, get_icon_content('fa fa-clock-o')+ event_time_for_display(program_event), :class => "m-b")+
    content_tag(:div, get_icon_content('fa fa-map-marker')+ h(event_location_for_display(program_event)), :class => "m-b")
  end

  def get_admin_views_options(admin_views, program_event)
    options = collect_admin_views_hash(admin_views)
    if !program_event.new_record? && !program_event.admin_view
      deleted_admin_view_title = "#{program_event.admin_view_title} (#{'display_string.deleted'.translate})"
      options.unshift({ id: program_event.admin_view_id, title: h(deleted_admin_view_title) })
    end
    chr_json_escape(options.to_json)
  end

  def get_confirm_message_for_event_guest_list_update(program_event)
    program = program_event.program
    added_count, removed_count = program_event.get_current_admin_view_changes
    admin_view_title = program_event.admin_view_title

    include_invite_email_note = added_count > 0 && program_event.email_notification? && !program.email_template_disabled_for_activity?(NewProgramEventNotification)
    include_delete_email_note = removed_count > 0 && !program.email_template_disabled_for_activity?(ProgramEventDeleteNotification)

    general_note = get_event_guest_list_update_note(admin_view_title, added_count, removed_count)
    email_note = get_event_guest_list_update_email_note(include_invite_email_note, include_delete_email_note, added_count, removed_count)

    note = general_note.presence || ""
    note = "#{note} #{email_note}" if email_note
    note.html_safe
  end

  def get_empty_users_message(with_search_content)
    message = with_search_content ? "feature.user.content.no_users_found".translate : "feature.user.content.no_users_found_for_current_tab".translate
    content_tag(:div, message, class: "clearfix p-sm text-center")
  end

  def get_program_events_timezone_selector_locals_hash(program_event, new_record_or_draft)
    locals = new_record_or_draft ? {} : {
      tz_area_class: "cjs_selector_time_zone_area",
      tz_identifier_class: "cjs_selector_time_zone_identifier",
      track_change: true
    }
    locals.merge!({
      object: program_event,
      tz_identifier_element_name: "program_event[time_zone]",
      additional_container_label_class: "col-sm-3",
      container_input_class: "col-sm-9",
      default_selected_time_zone: wob_member.get_valid_time_zone
    })
  end

  private

  def get_event_guest_list_update_note(admin_view_title, added_count, removed_count)
    n_added_users = "feature.program_event.label.users_number_v2".translate(count: added_count)
    n_removed_users = "feature.program_event.label.users_number_v2".translate(count: removed_count)

    if added_count > 0 && removed_count > 0
      "feature.program_event.content.added_to_removed_from_guest_list_confirmation".translate(view: admin_view_title, n_added_users: n_added_users, n_removed_users: n_removed_users)
    elsif added_count > 0
      "feature.program_event.content.added_to_guest_list_confirmation".translate(view: admin_view_title, n_added_users: n_added_users)
    elsif removed_count > 0
      "feature.program_event.content.removed_from_guest_list_confirmation".translate(view: admin_view_title, n_removed_users: n_removed_users)
    end
  end

  def get_event_guest_list_update_email_note(include_invite_email_note, include_delete_email_note, added_count, removed_count)
    added_users = "display_string.user".translate(count: added_count)
    removed_users = "display_string.user".translate(count: removed_count)
    invite_email_link = link_to("feature.program_event.content.event_invite_notification".translate, edit_mailer_template_path(NewProgramEventNotification.mailer_attributes[:uid]))
    delete_email_link = link_to("feature.program_event.content.event_delete_notification".translate, edit_mailer_template_path(ProgramEventDeleteNotification.mailer_attributes[:uid]))

    if include_invite_email_note && include_delete_email_note
      "feature.program_event.content.added_to_removed_from_guest_list_email_note_html".translate(added_users: added_users, removed_users: removed_users, invite_email_link: invite_email_link, delete_email_link: delete_email_link)
    elsif include_invite_email_note
      "feature.program_event.content.added_to_guest_list_email_note_html".translate(added_users: added_users, invite_email_link: invite_email_link)
    elsif include_delete_email_note
      "feature.program_event.content.removed_from_guest_list_email_note_html".translate(removed_users: removed_users, delete_email_link: delete_email_link)
    end
  end

  def get_program_event_link(program_event, options={})
    link_to truncate(program_event.title.gsub(/([\n\t])/, " "), :length => ProgramEvent::TITLE_LENGTH), program_event_path(program_event), class: options[:class]
  end
end