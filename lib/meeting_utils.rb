## Module contains methods common for meetings_controller and meeting_requests_controller
module MeetingUtils
  def construct_meeting(params, action_name, options)
    program = options[:program]
    options.merge!(meeting_params: options.extract!(:topic, :description, :attendee_ids)) if options[:is_dual_request_mode]
    meeting_params = build_from_params(params, action_name, options)
    meeting = program.meetings.new(meeting_params)
    set_meeting_attributes(meeting, options[:owner_member], options[:group].present?, options[:student_name].present?)
    meeting
  end

  def build_from_params(params, action_name, options)
    options[:new_action] = options.has_key?(:new_action) ? options[:new_action] : true
    meeting = options[:meeting]
    meeting_params = options[:meeting_params] || get_meeting_params(action_name)

    unless options[:is_dual_request_mode]
      merge_date(meeting, meeting_params, options[:new_action], options[:meeting_date_changed])
      merge_repeats_end_date(meeting_params)
      merge_attendee_ids(params, meeting_params, options.pick(:group, :meeting, :owner_member, :new_action))
    end

    merge_meeting_time_and_duration(params, meeting_params, options[:program], options[:is_non_time_meeting])
    meeting_params[:ics_sequence] = meeting.ics_sequence + 1 unless options[:new_action] || options[:is_non_time_meeting]
    meeting_params
  end

  private

  def set_meeting_attributes(meeting, owner_member, is_group_meeting, is_mentor_created_meeting)
    meeting.owner = owner_member
    meeting.time_zone = owner_member.get_valid_time_zone
    meeting.mentor_created_meeting = is_mentor_created_meeting
    set_meeting_memberships(meeting, is_group_meeting)
  end

  def set_meeting_memberships(meeting, is_group_meeting)
    return if is_group_meeting

    program = meeting.program
    owner_user = meeting.owner.user_in_program(program)
    guest_user = meeting.guests.first.user_in_program(program)
    if meeting.mentor_created_meeting
      meeting.mentee_id = guest_user.member.id
      meeting.requesting_mentor = owner_user
      meeting.requesting_student = guest_user
    else
      meeting.mentee_id = owner_user.member.id
      meeting.requesting_mentor = guest_user
      meeting.requesting_student = owner_user
    end
  end

  def get_meeting_params(action)
    return {} unless params[:meeting].present?

    meeting_params = params[:meeting].permit(Meeting::MASS_UPDATE_ATTRIBUTES[action])
    meeting_params[:repeats_on_week] = params[:meeting][:repeats_on_week] if params[:meeting][:repeats_on_week].present?
    meeting_params
  end

  def merge_date(meeting, meeting_params, new_action, meeting_date_changed = false)
    meeting_params[:date] = get_en_datetime_str(meeting_params[:date]) if meeting_params[:date].present?
    meeting_params[:date] = meeting.occurrences.first.start_time.strftime('time.formats.full_display_no_time'.translate) if !new_action && !meeting_date_changed
  end

  def merge_repeats_end_date(meeting_params)
    return unless meeting_params[:repeats_end_date].present?

    repeat_time = DateTime.strptime(get_en_datetime_str(meeting_params[:repeats_end_date]) + " " + meeting_params[:start_time_of_day], MentoringSlot.calendar_datetime_format).to_time.utc
    meeting_params[:repeats_end_date] = Time.zone.parse(DateTime.localize(repeat_time, format: :full_date_full_time))
  end

  def merge_attendee_ids(params, meeting_params, options)
    merge_attendee_ids_from_params(params, meeting_params)
    merge_attendee_ids_from_group(options[:group], options[:meeting], meeting_params, options[:owner_member], options[:new_action])
  end

  def merge_attendee_ids_from_params(params, meeting_params)
    return unless params.try(:[], :meeting).try(:[], :attendee_ids).present?

    meeting_params[:attendee_ids] = params[:meeting][:attendee_ids]
    meeting_params[:attendee_ids] = meeting_params[:attendee_ids].split(",") if meeting_params[:attendee_ids].is_a?(String)
    meeting_params[:attendee_ids].reject(&:empty?)
  end

  def merge_attendee_ids_from_group(group, meeting, meeting_params, owner_member, new_action)
    meeting_group = get_meeting_group(group, meeting, new_action)
    if meeting_group && (meeting_group.members.size == 2)
      meeting_params[:attendee_ids] = (new_action ? meeting_group.members.collect(&:member_id) : meeting.attendee_ids)
    elsif meeting_group || new_action
      meeting_params[:attendee_ids] ||= []
      meeting_params[:attendee_ids] << owner_member.id
    else
      meeting_params[:attendee_ids] = meeting.attendee_ids
    end
  end

  def get_meeting_group(group, meeting, new_action)
    meeting_group = group
    meeting_group ||= meeting.group unless new_action
    meeting_group
  end

  def merge_meeting_time_and_duration(params, meeting_params, program, is_non_time_meeting)
    if is_non_time_meeting
      meeting_params[:calendar_time_available] = false
      meeting_params.merge!(get_start_time_end_time_duration_for_non_time_meeting(program))
    else
      start_time_of_day = meeting_params.delete(:start_time_of_day)
      end_time_of_day = meeting_params.delete(:end_time_of_day)
      _next_day, start_time_next_day, end_time_next_day = view_context.is_next_day?(params[:meeting][:slot_start_time], params[:meeting][:slot_end_time], start_time_of_day, end_time_of_day, program.get_calendar_slot_time)
      meeting_params[:start_time], meeting_params[:end_time] = MentoringSlot.fetch_start_and_end_time(meeting_params.delete(:date), start_time_of_day, end_time_of_day, start_time_next_day, end_time_next_day)
      meeting_params[:duration] = meeting_params[:end_time] - meeting_params[:start_time]
    end
  end

  ## The below start_time, end_time are stored in the db for consistency and for neccessary time related validations / calendar setting validations
  ## This will be removed soon :)
  def get_start_time_end_time_duration_for_non_time_meeting(program)
    start_time = (Time.now.utc + program.calendar_setting.feedback_survey_delay_not_time_bound.days).round_to_next({timezone: 'utc'})
    duration =  program.calendar_setting.slot_time_in_minutes.zero? ? 1.hour : program.calendar_setting.slot_time_in_minutes.minutes
    end_time = start_time + duration

    { start_time: start_time, end_time: end_time, duration: duration }
  end
end