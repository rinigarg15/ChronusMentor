module MeetingsHelper

  DateRangeFormat = ->{ "date.formats.date_range".translate }
  SEE_MORE_LIMIT = 3

  def meeting_attendees_for_display(meeting, current_occurrence_time, options = {})
    meeting_area = options[:meeting_area] || false
    attendees = []
    participants = meeting.guests

    add_meeting_owner(meeting, current_occurrence_time, meeting_area, attendees)
    add_participants(participants, meeting, current_occurrence_time, meeting_area, attendees)

    unless meeting.group_meeting?
      removed_user_image, removed_user_name = get_user_image_and_name(removed_user: true, meeting_area: meeting_area)
      removed_user_for_display = render_meeting_attendees(meeting_area, get_attendee_name_and_rsvp_info(removed_user_name, nil)) {removed_user_image}

      attendees.prepend(removed_user_for_display) unless meeting.can_display_owner?
      attendees << removed_user_for_display if participants.empty?
    end

    content_tag(:div, %Q[#{"feature.meetings.content.attendees".translate} (#{"display_string.ordinal".translate(number: attendees.size, ordinal: nil)})], class: "font-bold p-b-xs #{options[:attendees_label_class]}") +
    render_attendees(meeting, attendees)
  end

  def get_all_attendees_modal_footer
    link_to "display_string.Close".translate, "javascript:void(0)", class: "btn btn-sm btn-white", data: { dismiss: "modal" }
  end

  def render_meeting_attendees(meeting_area, name_rsvp)
    content_tag(:div, class: "#{meeting_area ? 'col-sm-offset-2 m-b-sm' : 'p-b-xxs' }") do
      content_tag(:div, class: "media-left") do
        yield
      end +
      name_rsvp
    end
  end

  def get_choose_time_label_key(options = {})
    program = options[:program] || @current_program
    force_value = options[:force_value]
    (force_value.nil? ? program.try(:enhanced_meeting_scheduler_enabled?) : force_value) ? "available_slots_with_zone" : "pick_a_time_with_zone"
  end

  def get_skype_icon_for_attendee(attendee, meeting)
    user = attendee.user_in_program(meeting.program) if attendee.present?
    return get_safe_string unless attendee && user && (attendee.id != wob_member.id) && user.skype_id.present? && meeting.program.organization.skype_enabled? && meeting.has_member?(wob_member)
    content_tag(:span, link_to(embed_icon("fa fa-skype fa-info") + set_screen_reader_only_content("feature.user.label.Skype".translate), "skype:" + user.skype_id + "?call", :class => "cjs_meeting_area_skype_call"), class: "m-l-xs #{hidden_on_mobile}")
  end

  def get_attendee_name_and_rsvp_info(name_content, rsvp_html, meeting_area = false, attendee = nil, meeting = nil)
    if meeting_area
      content_tag(:div, class: "media-body") do
        content_tag(:div, content_tag(:span, name_content) + get_skype_icon_for_attendee(attendee, meeting) + content_tag(:span, rsvp_html, class: "small"), class: "m-t-xxs")
      end
    else
      content_tag(:div, class: "media-body") do
        content_tag(:div, class: "m-t-xxs") do
          content_tag(:span, name_content) + content_tag(:span, rsvp_html, class: "p-l-xxs")
        end
      end
    end
  end

  def get_x_minute_meeting_text(program)
    %Q[#{program.get_calendar_slot_time} #{"feature.profile.content.minute".translate(count: 1)}]
  end

  def get_member_response_icon_for_meeting(member, meeting, current_occurrence_time)
    member_meeting = meeting.member_meetings.find { |member_meeting| member_meeting.member_id == member.id }
    return unless member_meeting.present?
    response = member_meeting.get_response_object(current_occurrence_time).attending
    icon_html = get_safe_string
    tooltip_class = "rsvp_response_#{member_meeting.id}_tooltip_#{SecureRandom.hex(4)}"
    icon_html +=
      case response
      when MemberMeeting::ATTENDING::YES
        content_tag(:span, get_icon_content("fa-lg fa fa-check-circle text-navy"), class: "#{tooltip_class}") + tooltip("#{tooltip_class}", "app_constant.rsvp_terms.yes_v1".translate, false, is_identifier_class: true)
      when MemberMeeting::ATTENDING::NO
        content_tag(:span, get_icon_content("fa-lg fa fa-times-circle text-danger"), class: "#{tooltip_class}") + tooltip("#{tooltip_class}", "app_constant.rsvp_terms.no_v1".translate, false, is_identifier_class: true)
      when MemberMeeting::ATTENDING::NO_RESPONSE
        content_tag(:span, get_icon_content("fa-lg fa fa-question-circle text-muted"), class: "#{tooltip_class}") + tooltip("#{tooltip_class}", "app_constant.rsvp_terms.no_response_v1".translate, false, is_identifier_class: true)
      end
    return icon_html
  end

  def get_user_image_and_name(options = {})
    meeting = options[:meeting]
    meeting_area = options[:meeting_area]
    user_image, user_name = if meeting.present? && meeting.can_display_owner?
      [
        member_picture_v3(meeting.owner, { no_name: true, size: :small, new_size: :tiny }, { class: "img-circle", size: attendee_image_size(meeting_area), meeting_area: "#{true if meeting_area }" }),
        content_tag(:span, link_to_user(meeting.owner.user_in_program(meeting.program)))
      ]
    else
      [
        image_tag(UserConstants::DEFAULT_PICTURE[:small], class: "img-circle", size: attendee_image_size(meeting_area)),
        options[:removed_user] ? "feature.meetings.content.removed_user".translate : ""
      ]
    end
  end

  def get_member_pictures_with_links(meeting, member, questions, meeting_index, feedback_of_meeting ={})
    program = meeting.program
    user_data = []
    user = member.users.find{|user| user.program_id == program.id} if member.present?
    user_data << content_tag(:div) do
      user_feedback = (feedback_of_meeting || {})[user.try(:id)]
      content = content_tag(:span, (user.present? ? member_picture_v3(member, { no_name: true, size: :small, new_size: :small }, { class: "img-circle", size: "35x35" }) : image_tag(UserConstants::DEFAULT_PICTURE[:small], class: "img-circle", size: "35x35")), :class => "#{'inline has-next' if user_feedback.present?}") 
      if user_feedback.present? 
        content += content_tag(:div, get_icon_content("fa fa-comments feedback_img pointer text-info", :data => {toggle: "modal" , target: "#report_view_feedback_#{meeting_index}_#{member.id}"}), title: "feature.reports.label.view_mentoring_session_feedback_v1".translate )
        content += (render :partial => "meetings/feedbacks", :locals => {survey_questions: questions, :meeting_index => meeting_index, member: member, :meeting => meeting, :feedbacks_answers => user_feedback.index_by(&:common_question_id)})
      end
      content
    end
    safe_join(user_data, "")
  end

  def get_meeting_state(meeting)
    if meeting.completed?
      return "feature.meetings.header.completed".translate
    elsif meeting.cancelled?
      return "feature.meetings.header.canceled".translate
    elsif meeting.archived?
      return "feature.meetings.header.overdue".translate
    else
      return "feature.meetings.header.upcoming".translate
    end
  end

  def get_meeting_state_class(meeting)
    if meeting.completed?
      return "label label-primary"
    elsif meeting.cancelled?
      return "label label-warning"
    elsif meeting.archived?
      return "label label-danger"
    else
      return "label label-success"
    end
  end

  #Method to get the msg when a user accepts a flash meeting
  def get_meeting_accept_message(meeting, meeting_count, current_time, is_logged_in, user)
    change_link = link_to("display_string.Change".translate,  edit_member_path(user.member, scroll_to: "max_meeting_slots_"+meeting.program.id.to_s, focus_settings_tab: true, subdomain: meeting.program.organization.subdomain))
    if user.user_setting.try(:max_meeting_slots).present?
      if ((user.user_setting.max_meeting_slots - meeting_count) <= 0)
        message = "feature.meetings.content.successful_connect_footer_limit_reached_html".translate(meeting: pluralize_only_text(meeting_count, _meeting, _meetings), current_month:  DateTime.localize(current_time, format: :month_year), Change_limit: change_link, count: meeting_count)
      else
        message = "feature.meetings.content.successful_connect_footer_html".translate(meeting: pluralize_only_text(meeting_count, _meeting, _meetings), current_month: DateTime.localize(current_time, format: :month_year), Change_limit: change_link, count: meeting_count, meeting_request_limit: user.user_setting.max_meeting_slots - meeting_count)
      end
    else
      message = ""
    end
    if is_logged_in
      content_tag(:div, class: "text-center text-muted", style: "font-weight:bold") do
        message
      end
    else
      message
    end
  end

  def get_response_with_icon_class_for_RSVP(response)
    case response
      when MemberMeeting::ATTENDING::YES
        append_text_to_icon("fa fa-fw fa-check", "app_constant.rsvp_terms.yes_v1".translate)
      when MemberMeeting::ATTENDING::NO
        append_text_to_icon("fa fa-ban", "app_constant.rsvp_terms.no_v1".translate)
      when MemberMeeting::ATTENDING::NO_RESPONSE
        "app_constant.rsvp_terms.no_response_v1".translate
    end
  end

  def attendee_image_size(meeting_area)
    meeting_area ? "35x35" : "21x21"
  end

  def meeting_duration(meeting)
    "(#{meeting.formatted_duration})"
  end

  def get_meeting_html_id(meeting_hsh)
    "meeting_#{meeting_hsh[:meeting].id}_#{meeting_hsh[:current_occurrence_time].to_i}"
  end

  def meeting_time_for_display(meeting, current_occurrence_time = nil)
    return content_tag(:span, "feature.meetings.content.meeting_time_not_set".translate(:Meeting => _Meeting), class: 'text-danger') unless meeting.calendar_time_available?
    time = current_occurrence_time ? current_occurrence_time : meeting.start_time
    (get_safe_string + append_time_zone(DateTime.localize(time, format: :full_display), wob_member) + " " +
      content_tag(:span, meeting_duration(meeting), {:class => "text-muted"}, false))
  end

  def get_valid_times(meeting, slot_duration, allowed_individual_slot_duration)
    all_times = generate_slots_list(Meeting::SLOT_TIME_IN_MINUTES)
    st_index = all_times.index(meeting.start_time_of_the_day)
    en_index = all_times.index(DateTime.localize(meeting.start_time + slot_duration, format: :short_time_small))
    en_index = all_times.length - 1 if en_index == 0
    return [all_times[st_index..st_index], all_times[en_index..en_index]] if meeting.state.present?
    last_start_time_index = (allowed_individual_slot_duration/Meeting::SLOT_TIME_IN_MINUTES)
    en_index = all_times.length - 1 if en_index == 0
    if st_index > en_index - last_start_time_index
      start_time_arr = all_times[st_index..-2].map{ |x| [x.to_s, x.to_s] }
      start_time_arr += all_times[0..(en_index - last_start_time_index)].map{ |x| [x.to_s + " (" + "feature.meetings.form.next_day".translate + ")", x.to_s]}
      end_time_arr =  all_times[(st_index + last_start_time_index)..-2].map{ |x| [x.to_s, x.to_s] }
      end_time_arr += all_times[0..en_index].map{ |x| [x.to_s + " (" + "feature.meetings.form.next_day".translate + ")", x.to_s] }
      return [start_time_arr, end_time_arr]
    end
    [all_times[st_index..(en_index - last_start_time_index)], all_times[(st_index + last_start_time_index)..en_index]]
  end

  def is_next_day?(slot_start_time, slot_end_time, start_time, end_time, allowed_individual_slot_duration)
    all_times = generate_slots_list(Meeting::SLOT_TIME_IN_MINUTES)
    st_index = all_times.index(slot_start_time)
    en_index = all_times.index(slot_end_time)
    return [false, false, false] if st_index.nil? || en_index.nil?
    last_start_time_index = (allowed_individual_slot_duration/Meeting::SLOT_TIME_IN_MINUTES)
    en_index = all_times.length - 1 if en_index == 0
    start_time_next_day =  end_time_next_day = next_day = false
    if st_index > en_index - last_start_time_index
      next_day = true
      if !start_time.nil? && !end_time.nil?
        start_time_next_day = all_times[0..(en_index - last_start_time_index)].include? start_time
        end_time_next_day = all_times[0..en_index].include? end_time
      end
    end
    return [next_day, start_time_next_day, end_time_next_day]
  end

  def get_all_time_values(start_time, end_time)
    start_time_options, end_time_options = start_time.transpose[0], end_time.transpose[0]
    start_time_val, end_time_val = start_time.transpose[1], end_time.transpose[1]
    all_time_val = get_all_time_for_end_time((start_time_val + end_time_val))
    all_time = get_all_time_for_end_time((start_time_options + end_time_options))
    return [all_time, all_time_val]
  end

  def get_new_meetings_header
    "feature.meetings.action.add_meeting_v1".translate(:Meeting => _Meeting)
  end

  def get_members_with_links(meeting)
    program = meeting.program
    users = []
    meeting.members.each do |member|
      user = member.user_in_program(program)
      users << content_tag(:div) do
        content = content_tag(:span, (user.present? ? link_to_user(user,:content_text => member.name(:name_only => true)) : "feature.reports.label.removed_user".translate))
        content
      end
    end
    safe_join(users, "")
  end

  def compute_duration_display(duration)
    duration_string = ""
    total_minutes = (duration * 60).to_i
    hours = total_minutes/60
    minutes = total_minutes - (hours * 60)
    duration_string << "#{"common_text.hour".translate(count: hours)} " if hours > 0
    duration_string << "#{"common_text.minute".translate(count: minutes)}" if minutes > 0
    duration_string = "common_text.hour".translate(count: 0) if duration_string.blank?
    return duration_string
  end

  def location_specified?(slot_location)
    slot_location != "-"
  end

  def generate_attrs(slot)
    slot_start_time = DateTime.localize(slot[:start].to_time, format: :full_date_full_time)
    slot_end_time = DateTime.localize(slot[:end].to_time, format: :full_date_full_time)
    {
      :data => {
        :start_time_of_day => slot_start_time,
        :end_time_of_day => slot_end_time,
        :attendee_ids => slot[:new_meeting_params][:mentor_id],
        :location => slot[:location],
        :url => new_meeting_path(format: :js)
      }
    }
  end

  def available_time_format(start_time, end_time, format = :short_time)
    DateTime.localize(start_time, format: format) + " - " + DateTime.localize(end_time, format: format)
  end

  def embed_yes_no_button(member_meeting, content_text, status, src, options = {})
    option_hash = { class: "#{options[:button_class]} btn btn-outline btn-sm cjs_rsvp_confirm #{'cjs_group_meeting' if @group.present?}" }

    update_rsvp_link = if @group.nil?
      update_from_guest_meeting_path(member_meeting.meeting, attending: status, member_id: member_meeting.member.id, current_occurrence_time: options[:current_occurrence_time], src: src, outside_group: options[:outside_group], from_connection_home_page_widget: options[:from_connection_home_page_widget])
    else
      update_from_guest_meeting_path(member_meeting.meeting, group_id: @group.id, attending: status, member_id: member_meeting.member.id, current_occurrence_time: options[:current_occurrence_time], src: src, outside_group: options[:outside_group], from_connection_home_page_widget: options[:from_connection_home_page_widget])
    end

    edit_meeting_time_url = edit_meeting_path(member_meeting.meeting, current_occurrence_time: options[:current_occurrence_time], show_recurring_options: member_meeting.meeting.recurrent?, set_meeting_time: true, meeting_area: (src == MemberMeeting::RSVP_SOURCE::MEETING_AREA), outside_group: options[:outside_group], ei_src: EngagementIndex::Src::UpdateMeeting::RSVP_RESCHEDULE, from_connection_home_page_widget: options[:from_connection_home_page_widget])

    option_hash[:class] = "#{option_hash[:class]} cjs_rsvp_accepted" if status == MemberMeeting::ATTENDING::NO
    option_hash.merge!({data: {url: update_rsvp_link, msg: get_rsvp_no_popup(member_meeting), editTimeUrl: edit_meeting_time_url, meetingSelector: get_meeting_html_id({meeting: member_meeting.meeting, current_occurrence_time: options[:current_occurrence_time]})}})

    link_to(content_tag(:span, content_text, class: "m-l-xs m-r-xs"), "javascript:void(0)", option_hash)
  end

  def render_meeting_location_details(meeting, wob_member, options = {})
    icon_options = options[:meeting_area].present? ? {} : {media_padding_with_icon: true}
    margin_class = "m-r-md" if options[:meeting_area].present?
    meeting_id = get_meeting_html_id({meeting: meeting, current_occurrence_time: options[:current_occurrence_time]})

    if meeting.location.present?
      append_text_to_icon("fa fa-map-marker #{margin_class}", chronus_auto_link(h(meeting.location)), icon_options)
    elsif meeting.location_can_be_set_by_member?(wob_member, options[:current_occurrence_time])
      append_text_to_icon("fa fa-map-marker m-t-xs #{margin_class}", link_to("feature.meetings.action.set_location".translate, "javascript:void(0)", data: {url: edit_meeting_path(meeting, {show_recurring_options: meeting.recurrent?, current_occurrence_time: options[:current_occurrence_time], set_meeting_time: true, set_meeting_location: true, meeting_area: options[:meeting_area], from_connection_home_page_widget: options[:from_connection_home_page_widget]})}, class: "cjs_set_meeting_location_#{meeting_id} btn btn-xs btn-white text-muted"), icon_options)
    else
      append_text_to_icon("fa fa-map-marker #{margin_class}", content_tag(:span, 'feature.meetings.content.no_location'.translate, class: 'text-muted'), icon_options)
    end
  end

  def embed_yes_no_text(member_meeting_response, member_meeting, src, options = {})
    meeting = member_meeting.meeting
    group = meeting.group
    class_text = ""
    displayed_text = member_meeting_response.accepted? ? "feature.meetings.header.attending".translate : (member_meeting_response.rejected? ? "feature.meetings.header.not_attending".translate : "app_constant.rsvp_terms.no_response_v1".translate)


    option_hash = { class: "cjs_rsvp_confirm #{'cjs_group_meeting' if group.present?} p-l-xxs #{"hide" if (meeting.archived?(options[:current_occurrence_time]) || (group.present? && !group.active?))}" }

    class_text << (member_meeting_response.accepted? ? " fa fa-check" : (member_meeting_response.rejected? ? " fa fa-times": " fa fa-ban"))
    class_text = "#{class_text} #{'m-r-sm' if src == MemberMeeting::RSVP_SOURCE::MEETING_AREA}"

    update_rsvp_link = if @group.nil?
      update_from_guest_meeting_path(meeting, attending: get_updated_status(member_meeting_response), member_id: member_meeting.member.id, current_occurrence_time: options[:current_occurrence_time], src: src, updating_rsvp: true, outside_group: options[:outside_group], from_connection_home_page_widget: options[:from_connection_home_page_widget])
    else
      update_from_guest_meeting_path(meeting, group_id: @group.id, attending: get_updated_status(member_meeting_response), member_id: member_meeting.member.id, current_occurrence_time: options[:current_occurrence_time], src: src, updating_rsvp: true, outside_group: options[:outside_group], from_connection_home_page_widget: options[:from_connection_home_page_widget])
    end

    edit_meeting_time_url = edit_meeting_path(meeting, current_occurrence_time: options[:current_occurrence_time], outside_group: options[:outside_group], show_recurring_options: meeting.recurrent?, set_meeting_time: true, meeting_area: (src == MemberMeeting::RSVP_SOURCE::MEETING_AREA), ei_src: EngagementIndex::Src::UpdateMeeting::RSVP_RESCHEDULE, from_connection_home_page_widget: options[:from_connection_home_page_widget])

    option_hash[:class] = "#{option_hash[:class]} cjs_rsvp_accepted" if member_meeting_response.accepted?
    option_hash.merge!({data: {url: update_rsvp_link, msg: get_rsvp_no_popup(member_meeting), editTimeUrl: edit_meeting_time_url, meetingSelector: get_meeting_html_id({meeting: meeting, current_occurrence_time: options[:current_occurrence_time]})}})

    content_tag(:div, append_text_to_icon(class_text, displayed_text.html_safe + link_to("feature.meetings.header.change".translate, "javascript:void(0)", option_hash), :media_padding_with_icon => true) )
  end

  def get_updated_status(member_meeting_response)
    member_meeting_response.accepted? ? MemberMeeting::ATTENDING::NO : MemberMeeting::ATTENDING::YES
  end

  def get_rsvp_no_popup(member_meeting)
    (!member_meeting.is_owner? && member_meeting.meeting.owner.present?) ? "feature.meetings.content.sure_to_attend_meeting_v3_html".translate(meeting: _meeting, owner_name: link_to(member_meeting.meeting.owner.try(:name), member_path(member_meeting.meeting.owner))) : "feature.meetings.content.sure_to_attend_meeting_v3_owner".translate(meeting: _meeting)
  end

  def get_update_from_guest_flash(member_meeting, member_meeting_response, owner_name)
    flash[:notice] = if member_meeting_response.accepted?
      !member_meeting.is_owner? && owner_name.present? ? "flash_message.group_flash.meeting_rsvp_update_yes_html".translate(owner_name: owner_name) : "flash_message.group_flash.meeting_rsvp_update_yes_owner".translate
    else
      !member_meeting.is_owner? && owner_name.present? ? "flash_message.group_flash.meeting_rsvp_update_no_html".translate(owner_name: owner_name) : "flash_message.group_flash.meeting_rsvp_update_no_owner".translate
    end
    return flash[:notice]
  end

  def state_not_displayed(meeting, edit_time_only)
    return (meeting.group_meeting? || edit_time_only || !meeting.archived?)
  end

  def get_ga_class(source)
    case source
    when Survey::SurveySource::MAIL
      "cjs_source_mail"
    when Survey::SurveySource::HOME_PAGE_WIDGET
      "cjs_source_home_page"
    when Survey::SurveySource::MEETING_LISTING
      ""
    else
      "cjs_meeting_area"
    end
  end

  def show_rsvp_buttons?(meeting, member_meeting_response, current_occurrence_time)
    group = meeting.group
    return member_meeting_response.not_responded? && !meeting.archived?(current_occurrence_time) && (group.blank? || group.active?)
  end

  def get_all_time_for_end_time(all_time)
    length = all_time.size
    if all_time[0] == "12:00 am" && all_time[length - 1] == "12:00 am"
      return all_time[1..(length - 1)].uniq
    else
      return all_time.uniq
    end
  end

  def get_meeting_text(meeting)
    meeting.completed? ? "feature.meetings.header.completed".translate : (meeting.cancelled? ? "feature.meetings.header.canceled".translate : "feature.meetings.header.past".translate)
  end

  def get_sync_calendar_instructions
    sync_url = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/files/Steps_for_syncing_Mentoring_Calendar_with_Email_Clients_V2.pdf"
    "feature.calendar.content.ical_instruction_html".translate(url: link_to("display_string.Click_here".translate, sync_url, :target => '_blank'))
  end

  def get_meeting_dropdown_edit_delete(meeting, meeting_id, current_occurrence_time, show_recurring_options, group, options = {})
    dropdown_actions = []
    if meeting.can_be_edited_by_member?(wob_member)
      dropdown_actions << {
        label: append_text_to_icon("fa fa-pencil-square-o text-default", "display_string.Edit".translate),
        class: 'edit cjs_meeting_edit_details cjs_meeting_area_listing_event',
        js: %Q[MeetingForm.showEditMeetingQtip("#{meeting_id}", "#{edit_meeting_path(meeting, current_occurrence_time: current_occurrence_time, show_recurring_options: show_recurring_options, outside_group: options[:outside_group], ei_src: options[:ei_src], from_connection_home_page_widget: options[:from_connection_home_page_widget])}", #{options[:from_popup] ? true : false})]
      }
    end

    if meeting.can_be_deleted_by_member?(wob_member)
      destroy_url, destroy_popup_url = get_destroy_urls(meeting, current_occurrence_time, additional_params: { outside_group: options[:outside_group], from_connection_home_page_widget: options[:from_connection_home_page_widget] })
      from_popup = options[:from_popup] ? true : false

      dropdown_actions << {
        label: append_text_to_icon("fa fa-trash text-default","display_string.Delete".translate),
        js: %Q[MeetingForm.handleDelete("#{meeting_id}", "#{j destroy_url}", "#{j get_meeting_delete_confirmation}", { recurring: #{show_recurring_options}, destroyPopupUrl: "#{j destroy_popup_url}", fromPopup: #{from_popup} });],
        class: 'delete'
      }
    end

    dropdown_options = {
      btn_class: "pull-right",
      dropdown_title: "",
      is_not_primary: true,
      btn_group_btn_class: "btn-white btn-sm"
    }
    dropdown_buttons_or_button(dropdown_actions, dropdown_options)
  end

  def get_meeting_delete_confirmation
    "#{'common_text.confirmation.sure_to_delete_this'.translate(title: _meeting)} #{'common_text.confirmation.cant_be_undone'.translate}"
  end

  def get_meeting_actions(meeting_id, meeting, wob_member, current_occurrence_time)
    content = get_safe_string
    destroy_url, destroy_popup_url = get_destroy_urls(meeting, current_occurrence_time, additional_params: { meeting_area: true })

    if meeting.can_be_edited_by_member?(wob_member)
      content += link_to(append_text_to_icon("fa fa-pencil text-default", "feature.meetings.action.edit_details".translate), "javascript:void(0)", class: "edit btn-sm btn btn-white edit_meeting_popup cjs_meeting_area_listing_event cjs_meeting_edit_details cjs_meeting_area m-b-xs btn-block-xxs pull-right m-r-xs")
    end

    if meeting.can_be_deleted_by_member?(wob_member)
      content += link_to_function(
                  append_text_to_icon("fa fa-trash", "feature.meetings.action.delete_meeting_v1".translate(Meeting: _Meeting)),
                  %Q[MeetingForm.handleDelete("#{meeting_id}", "#{j destroy_url}", "#{j get_meeting_delete_confirmation}", { recurring: #{meeting.recurrent?}, destroyPopupUrl: "#{j destroy_popup_url}", fromPopup: false });],
                  class: "delete btn-sm btn btn-outline btn-danger m-b-xs btn-block-xxs pull-right m-r-xs")
    end
    content
  end

  def get_destroy_urls(meeting, current_occurrence_time, options = {})
    group_id = meeting.group.try(:id)
    destroy_url = meeting_path(meeting, { group_id: group_id, delete_option: Meeting::EditOption::ALL, current_occurrence_time: current_occurrence_time, format: :js }.merge(options[:additional_params]))
    destroy_popup_url = get_destroy_popup_meeting_path(meeting, { group_id: group_id, current_occurrence_time: current_occurrence_time }.merge(options[:additional_params]))
    [destroy_url, destroy_popup_url]
  end

  def meeting_content(options={})
    render(:partial => "meetings/meeting_content", :locals => {:options => options})
  end

  def time_to_calendar_date_format(time)
    DateTime.localize(time, format: :full_display_no_time)
  end

  def is_meeting_notification_enabled(meeting)
    is_calendar_meeting = meeting.calendar_time_available
    return (is_calendar_meeting && meeting.program.is_mailer_template_enabled(MeetingRequestStatusAcceptedNotification.mailer_attributes[:uid])) || ((!is_calendar_meeting) && meeting.program.is_mailer_template_enabled(MeetingRequestStatusAcceptedNotificationNonCalendar.mailer_attributes[:uid]))
  end

  def meetings_mini_popup_details_tab_heading
    content_tag(:span, "feature.meetings.header.enter_topic_and_description".translate, :class => "#{hidden_on_mobile} cjs_visit_details_tab") +
    content_tag(:span, "feature.meetings.header.enter_details".translate, :class => "#{hidden_on_web} cjs_visit_details_tab")
  end

  def meetings_mini_popup_select_times_tab_heading(user)
    if user.is_opted_for_slot_availability?
      content_tag(:span, "feature.meetings.header.select_meeting_times".translate(Meeting: _Meeting), :class => "#{hidden_on_mobile} cjs_calendar_meeting") + content_tag(:span, "feature.meetings.header.select_times".translate(Meeting: _Meeting), :class => "#{hidden_on_web} cjs_calendar_meeting")
    else content_tag(:span, "feature.meetings.header.propose_meeting_times".translate(Meeting: _Meeting), :class => "#{hidden_on_mobile} cjs_ga_meeting") + content_tag(:span, "feature.meetings.header.propose_times".translate(Meeting: _Meeting), :class => "#{hidden_on_web} cjs_ga_meeting")
    end
  end

  def get_reschedule_meeting_link(meeting, wob_member, meeting_selector)
    return unless meeting.can_be_edited_by_member?(wob_member)

    reschedule_text = content_tag(:span) do
      content_tag(:span, 'feature.meetings.content.reschedule'.translate, class: 'visible-xs') +
      content_tag(:span, 'feature.meetings.content.rsvp_reschedule'.translate(Meeting: _Meeting), class: 'hidden-xs')
    end

    link_to reschedule_text, "javascript:void(0)", class: "btn btn-primary Rsvp_accepted_reschedule", data: {meetingSelector: "#{meeting_selector}"}
  end

  def get_decline_meeting_link(meeting, meeting_selector)
    decline_text = content_tag(:span) do
      content_tag(:span, 'feature.meetings.content.decline'.translate, class: 'visible-xs') +
      content_tag(:span, 'feature.meetings.content.rsvp_decline'.translate(Meeting: _Meeting), class: 'hidden-xs')
    end

    link_to decline_text, "javascript:void(0)", class: "btn btn-white Rsvp_accepted_decline", data: {meetingSelector: "#{meeting_selector}", dismiss: "modal"}
  end

  def get_meetings_mini_popup_header(user)
    tabs = []

    tabs << {
      label: meetings_mini_popup_details_tab_heading,
      url: "#cjs_select_meeting_details_tab_content",
      active: true,
      link_options: {
        data: {
          toggle: "tab"
        }
      }
    }

    tabs << {
      label: meetings_mini_popup_select_times_tab_heading(user),
      url: "#select_meeting_time_tab_content",
      active: false,
      tab_class: "cjs_meeting_times_tab"
    }

    inner_tabs(tabs)
  end

  def get_non_responding_member_meetings_label(member, group)
    if group.active?
      non_responding_member_meetings = member.get_upcoming_not_responded_meetings_count(group.program, group)
      content_tag(:span, (non_responding_member_meetings > 0 ) ? non_responding_member_meetings : "", :class => "label label-danger rounded cjs_non_responding_member_meetings cui_count_label")
    else
      ""
    end
  end

  def get_meeting_end_times_for_edit(end_time, meeting)
    meeting_start_time = meeting.start_time_of_the_day
    start_time_index = end_time.find_index(meeting_start_time) unless end_time.last.eql?(meeting_start_time)
    start_time_index ? end_time[start_time_index+1..-1] : end_time
  end

  def get_mentee_availability_text_proposed_slot_popup(member)
    member.availability_not_set_message.present? ? (get_safe_string + "feature.meetings.content.mentee_availability_text".translate(:mentee_name => member.name) + content_tag(:span, member.availability_not_set_message, class: "m-l-xs")) : "feature.meetings.content.update_and_notify_mentee_help_text".translate(:meeting => _meeting, :mentee_name => member.name)
  end

  def get_meeting_creation_date(meeting)
    meeting_creation_time = meeting.created_at
    meeting_request = meeting.meeting_request
    meeting_creation_time = meeting_request.accepted_at if meeting_request.present? && meeting_request.accepted_at.present?
    return meeting_creation_time
  end

  def get_meeting_creation_date_text(meeting)
    meeting_creation_time = get_meeting_creation_date(meeting)
    get_icon_content("fa fa-clock-o no-margins") + content_tag(:span, "feature.meetings.content.created_on".translate, :class => "m-r-xs") + DateTime.localize(meeting_creation_time, format: :full_display_no_time_with_day_short)
  end

  def get_current_and_next_month_text(member)
    current_time = Time.now.in_time_zone(member.get_valid_time_zone)
    next_month_time = current_time.next_month

    if current_time.year == next_month_time.year
      "feature.meetings.content.current_and_next_month_text".translate(current_month: DateTime.localize(current_time, format: :month), next_month: DateTime.localize(next_month_time, format: :month_year))
    else
      "feature.meetings.content.current_and_next_month_text".translate(current_month: DateTime.localize(current_time, format: :month_year), next_month: DateTime.localize(next_month_time, format: :month_year))
    end
  end

  def get_recurrent_meeting_icon_tooltip_text(meeting)
    start_time = DateTime.localize(meeting.start_time.in_time_zone(wob_member.get_valid_time_zone), format: :short_time_small)
    end_time = DateTime.localize((meeting.start_time+meeting.schedule.duration).in_time_zone(wob_member.get_valid_time_zone), format: :short_time_small)
    time = MeetingScheduleStringifier.new(meeting).stringify + ', ' + append_time_zone('feature.email.tags.meeting_tags.meeting_timings.start_to_end_time'.translate(start_time: start_time, end_time: end_time), wob_member)
    return "#{time} #{'feature.email.tags.meeting_tags.meeting_timings.starting_from'.translate(start_time: DateTime.localize(meeting.occurrences.first.in_time_zone(wob_member.get_valid_time_zone), format: :short))}"
  end

  def get_filter_count_label(count)
    content_tag(:span, count, class: 'label label-success hide cjs-report-filter-count')
  end

  def get_caret_class(percentage)
    if percentage > 0 
      return "text-navy"
    elsif percentage < 0
      return "text-danger"
    else
      return "text-warning"
    end
  end

  def get_caret_class_for_admin_dashboard(percentage)
    percentage > 0 ? "text-navy" : "text-default"
  end

  def get_caret(percentage)
    if percentage > 0 
      return get_icon_content("fa fa-caret-up")
    elsif percentage < 0
      return get_icon_content("fa fa-caret-down")
    elsif percentage == 0
      return get_icon_content("fa fa-unsorted")
    end
  end

  def get_meeting_area_src(src)
    case src
    when Survey::SurveySource::MENTORING_CALENDAR
      return EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MENTORING_CALENDAR
    when Survey::SurveySource::MEETING_LISTING
      return EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_LISTING
    end
  end

  def get_tabs_for_mentoring_sessions_listing(active_tab)
    label_tab_mapping = {
      "feature.meetings.header.scheduled".translate => Meeting::ReportTabs::SCHEDULED,
      "feature.meetings.header.upcoming".translate => Meeting::ReportTabs::UPCOMING,
      "feature.meetings.header.past".translate => Meeting::ReportTabs::PAST
    }
    get_tabs_for_listing(label_tab_mapping, active_tab, url: mentoring_sessions_path, param_name: :tab)
  end

  def get_error_flash_for_calendar_sync_v2(error_list, selected_date)
    if error_list.present?
      formatted_error_list = error_list.uniq.collect{ |error| content_tag(:li, ERB::Util.html_escape(error)) }.join.html_safe
      'feature.calendar_sync_v2.content.invalid_slots_error_html'.translate(error_list: j(content_tag(:ul, formatted_error_list)))
    else
      'feature.calendar_sync_v2.content.no_free_slots_available'.translate(picked_date: j(selected_date))
    end
  end

  def get_unread_messages_text(meeting, meeting_messages_hash)
    unread_messages_size = meeting_messages_hash[:unread][meeting.id].to_i
    unread_messages_size > 0 ? content_tag(:span, 'feature.meetings.content.unread_messages'.translate(count: unread_messages_size), class: "label red-bg text-white badge m-l-sm") : ""
  end

  def can_show_meeting_messages?(meeting, meeting_messages_hash)
    !meeting.group_meeting? && meeting_messages_hash.present? && meeting_messages_hash[:all][meeting.id].to_i > 0
  end

  def can_show_meeting_notes?(meeting, meeting_notes_hash)
    meeting_notes_hash.present? &&  meeting_notes_hash[meeting.id].to_i > 0
  end

  private

  def render_attendees(meeting, attendees)
    see_more_count = attendees.size - SEE_MORE_LIMIT
    if see_more_count > 0
      content = render(partial: "meetings/all_attendees", locals: { meeting: meeting, attendees: attendees })
      content += safe_join(attendees[0..SEE_MORE_LIMIT-1], "")
      content += link_to(
        "display_string.See_All".translate,
        "javascript:void(0)", data: { target: "#all_attendees_#{meeting.id}", toggle: "modal" }, class: "small font-bold p-l-lg")
      content
    else
      safe_join(attendees, "")
    end
  end

  def add_meeting_owner(meeting, current_occurrence_time, meeting_area, attendees)
    if meeting.can_display_owner?
      owner_image, owner_name = get_user_image_and_name(meeting: meeting, meeting_area: meeting_area)
      owner_response_html = get_member_response_icon_for_meeting(meeting.owner, meeting, current_occurrence_time) if meeting.owner.present?
      name_and_rsvp = get_attendee_name_and_rsvp_info(owner_name, owner_response_html, meeting_area, meeting.owner, meeting)
      attendees << render_meeting_attendees(meeting_area, name_and_rsvp) {owner_image}
    end
  end

  def add_participants(participants, meeting, current_occurrence_time, meeting_area, attendees)
    return unless participants.present?
    participants.each do |participant|
      name_link = participant.user_in_program(meeting.program).nil? ? (participant.name) : link_to_user(participant.user_in_program(meeting.program))
      response_html = get_member_response_icon_for_meeting(participant, meeting, current_occurrence_time)
      name_and_rsvp = get_attendee_name_and_rsvp_info(name_link, response_html, meeting_area, participant, meeting)
      attendees << render_meeting_attendees(meeting_area, name_and_rsvp) do
        member_picture_v3(participant, { no_name: true, size: :small, new_size: :tiny }, { class: "img-circle", size: attendee_image_size(meeting_area), meeting_area: "#{true if meeting_area }"})
      end
    end
  end

end
