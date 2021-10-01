MailerTag.register_tags(:meeting_tags) do |t|
  t.tag :url_meeting, :description => Proc.new{'feature.email.tags.meeting_tags.url_meeting.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    if @meeting.accepted?
      meeting_url(@meeting, subdomain: @organization.subdomain, root: @meeting.program.root, src: "upcoming", current_occurrence_time: @meeting.first_occurrence)
    else
      meeting_requests_url(subdomain: @organization.subdomain, root: @meeting.program.root, email_meeting_request_id: @meeting.meeting_request.id, email_action: MeetingRequestsController::EmailAction::SHOW, src: "upcoming", list: AbstractRequest::Status::STATUS_TO_SCOPE[@meeting.meeting_request.status])
    end
  end

  t.tag :meeting_topic, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_topic.description'.translate(:meeting => @_meeting_string )}, :example => Proc.new{'feature.email.tags.meeting_tags.meeting_topic.example'.translate} do
    @meeting.topic
  end

  t.tag :meeting_owner_name, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_owner_name.description'.translate}, :example => Proc.new{"William Smith"} do
    @meeting.owner.name
  end

  t.tag :meeting_start_date, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_start_date.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.meeting_start_date.example'.translate} do
    @current_occurrence_time.present? ? DateTime.localize(@current_occurrence_time.in_time_zone(@member.get_valid_time_zone), format: :short) : DateTime.localize(@meeting.start_time.in_time_zone(@member.get_valid_time_zone), format: :short)
  end

  t.tag :meeting_start_time, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_start_time.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.meeting_start_time.example'.translate} do
    DateTime.localize(@meeting.start_time.in_time_zone(@member.get_valid_time_zone), format: :short_time_small)
  end

  t.tag :meeting_timings, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_timings.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.meeting_timings.example'.translate} do
    if @meeting.occurrences.count == 1 && @meeting.schedule.exception_times.blank?
      same_day = DateTime.localize(@meeting.start_time.in_time_zone(@member.get_valid_time_zone), format: :short) == DateTime.localize(@meeting.end_time.in_time_zone(@member.get_valid_time_zone), format: :short)
      meeting_end_time = same_day ? DateTime.localize(@meeting.end_time.in_time_zone(@member.get_valid_time_zone), format: :short_time_small) : DateTime.localize(@meeting.end_time.in_time_zone(@member.get_valid_time_zone), format: :short_date_short_time)
      append_time_zone('feature.email.tags.meeting_tags.meeting_timings.start_to_end_time'.translate(start_time: DateTime.localize(@meeting.start_time.in_time_zone(@member.get_valid_time_zone), format: :short_date_short_time), end_time: meeting_end_time), @member)
    else
      meeting_start_time = DateTime.localize(@meeting.start_time.in_time_zone(@member.get_valid_time_zone), format: :short_time_small)
      meeting_end_time = DateTime.localize((@meeting.start_time+@meeting.schedule.duration).in_time_zone(@member.get_valid_time_zone), format: :short_time_small)
      time = (@current_occurrence_time.present? ? DateTime.localize(@current_occurrence_time.in_time_zone(@member.get_valid_time_zone), format: :short) : MeetingScheduleStringifier.new(@meeting).stringify) + ', ' + append_time_zone('feature.email.tags.meeting_tags.meeting_timings.start_to_end_time'.translate(start_time: meeting_start_time, end_time: meeting_end_time), @member)
      if @current_occurrence_time.present?
        time
      elsif @following_occurrence_time.present?
       "#{'feature.email.tags.meeting_tags.meeting_timings.all_following'.translate(meetings: @_meetings_string, following_time: DateTime.localize(@following_occurrence_time.in_time_zone(@member.get_valid_time_zone), format: :short))}"
      else
       "#{time} #{'feature.email.tags.meeting_tags.meeting_timings.starting_from'.translate(start_time: DateTime.localize(@meeting.occurrences.first.in_time_zone(@member.get_valid_time_zone), format: :short))}"
      end
    end
  end

  t.tag :meeting_description, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_description.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.meeting_description.example'.translate} do
    truncate_length = Meeting::DESCRIPTION_TRUNCATION_LENGTH_IN_MAILS
    description = @meeting.description.presence || "-"
    description = (description.truncate(truncate_length) + "(" + link_to('feature.email.tags.meeting_tags.read_more'.translate, url_meeting) + ")").html_safe  if description.size > truncate_length
    return description
  end

  t.tag :meeting_location, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_location.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.meeting_location.example'.translate} do
    @meeting.location.presence || "-"
  end

  t.tag :meeting_details, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_details.description'.translate}, :example => Proc.new{"<div id='attendee'>William Smith <span style='color:#1DD13E; font-size:0.9em'>" + "feature.email.tags.meeting_tags.meeting_details.attending".translate + "</span></div><div id='attendee'> John Smith <span style='color:#1DD13E; font-size:0.9em'>" + "feature.email.tags.meeting_tags.meeting_details.attending".translate + "</span></div>"} do
    meeting_content = []
    @meeting.member_meetings.each do |member_meeting|
      attendee = member_meeting.member
      response_object = member_meeting.get_response_object(@current_occurrence_time)
      if response_object.accepted?
        color = "#1DD13E"
        label = "app_constant.rsvp_terms.yes_v1".translate
      elsif response_object.rejected?
        color = "#F21621"
        label = "app_constant.rsvp_terms.no_v1".translate
      else
        color = "#F21621"
        label = "app_constant.rsvp_terms.no_response_v1".translate
      end
      meeting_content << content_tag(:div, :id => "attendee") do
        if @hide_attendee_rsvp
          h(attendee.name)
        else
          h(attendee.name) + content_tag(:span, " (#{label})", :style => "color: #{color}; font-size: 0.9em;")
        end
      end
    end
    safe_join(meeting_content)
  end

  t.tag :url_contact_admin, :description => Proc.new{'feature.email.tags.campaign_tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
    get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
  end
end