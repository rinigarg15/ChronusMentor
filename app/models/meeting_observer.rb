class MeetingObserver < ActiveRecord::Observer
  
  def after_create(meeting)
    return unless meeting.active?
    mark_attending_params = [meeting, skip_rsvp_change_email: meeting.skip_rsvp_change_email, skip_mail_for_calendar_sync: true, rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC]
    meeting.create_meeting_requests(meeting.skip_email_notification)
    meeting.owner.mark_attending!(*mark_attending_params) if meeting.owner.present?

    if meeting.archived?
      meeting.guests.each do |m|
        m.mark_attending!(*mark_attending_params)
      end
    elsif meeting.create_ra != false
      meeting.append_to_recent_activity_stream(RecentActivityConstants::Type::MEETING_CREATED)
    end
  end

  def after_update(meeting)
    if meeting.active? && (meeting.saved_change_to_location? || meeting.saved_change_to_topic? || meeting.saved_change_to_description?)
      meeting.append_to_recent_activity_stream(RecentActivityConstants::Type::MEETING_UPDATED)
    end
    meetings = [meeting]
    valid_meetings = Meeting.recurrent_meetings(meetings, {get_merged_list: true})
    occurrences = []
    valid_meetings.each do |m|
      occurrences.push(m[:current_occurrence_time])
    end
    checkins = GroupCheckin.joins("Left join member_meetings on group_checkins.checkin_ref_obj_id = member_meetings.id and group_checkins.checkin_ref_obj_type = 'MemberMeeting'")
    checkins = checkins.joins("left join meetings on meetings.id = member_meetings.meeting_id").where("meetings.id = #{meeting.id}")
    if meeting.active?
      checkins.each do |checkin|
        checkin.destroy unless occurrences.include? checkin.date 
      end
    else 
      checkins.destroy_all
    end
  end

  def before_create(meeting)
    unless meeting.schedule.present?
      meeting.update_schedule
    end
    if meeting.schedule.present? && !meeting.occurrences.present?
      meeting.errors.add(:occurrences, "flash_message.user_flash.meeting_creation_failure_no_occurrences_v1".translate(:meeting => meeting.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase))
      raise ActiveRecord::RecordInvalid.new(meeting)
    end
    meeting.start_time = meeting.occurrences.first.start_time
    meeting.end_time = meeting.occurrences.last.end_time
  end

  def after_save(meeting)
    reindex_followups(meeting)
  end

  def after_destroy(meeting)
    reindex_followups(meeting)
  end

  private

  def reindex_followups(meeting)
    Meeting.es_reindex(meeting)
  end

end