class MemberMeetingObserver < ActiveRecord::Observer

  def self.post_status_update(member_meeting_id, ra_action_type, rsvp_from_app)
    member_meeting = MemberMeeting.find_by(id: member_meeting_id)
    return if member_meeting.nil?

    meeting = member_meeting.meeting

    return if meeting.nil?

    if meeting.calendar_time_available? && !member_meeting.is_owner?
      MemberMeetingObserver.append_to_recent_activity_stream(member_meeting, ra_action_type)
    end

    if meeting.can_be_synced?
      member_meeting_user = member_meeting.user
      
      meeting.member_meetings.where.not(id: member_meeting.id).each do |guest_member_meeting|
        ChronusMailer.meeting_rsvp_notification(guest_member_meeting.user, member_meeting).deliver_now
      end

      ChronusMailer.meeting_rsvp_notification_to_self(member_meeting_user, member_meeting).deliver_now if rsvp_from_app
    elsif !member_meeting.is_owner?
      ChronusMailer.meeting_rsvp_notification(meeting.owner.user_in_program(meeting.program), member_meeting).deliver_now if meeting.owner_and_owner_user_present?
    end
  end

  def self.append_to_recent_activity_stream(member_meeting, ra_action_type)
    RecentActivity.create!(
      :programs => [member_meeting.meeting.program],
      :ref_obj => member_meeting.meeting,
      :action_type => ra_action_type,
      :member => member_meeting.member,
      :target => RecentActivityConstants::Target::USER,
      :for => member_meeting.meeting.owner,
      :message => member_meeting.meeting.topic
    )
  end

  def after_update(member_meeting)
    meeting = member_meeting.meeting
    rsvp_from_app = member_meeting.perform_sync_to_calendar

    if meeting.active? && !meeting.archived? && member_meeting.saved_change_to_attending? && !member_meeting.skip_rsvp_change_email && !member_meeting.skip_mail_for_calendar_sync
      ra_constant = member_meeting.rejected? ? RecentActivityConstants::Type::MEETING_DECLINED : RecentActivityConstants::Type::MEETING_ACCEPTED
      MemberMeetingObserver.delay(queue: DjQueues::HIGH_PRIORITY).post_status_update(member_meeting.id, ra_constant, rsvp_from_app)
    end

    if meeting.can_be_synced? && member_meeting.saved_change_to_attending? && rsvp_from_app
      Meeting.delay(queue: DjQueues::HIGH_PRIORITY).update_calendar_event_rsvp(meeting.id)
    end
  end

  def after_destroy(member_meeting)
    meeting = member_meeting.meeting
    return unless meeting.present?
    if !meeting.group_meeting? && member_meeting.other_members.empty?
      meeting.update_columns(active: false, skip_delta_indexing: true)
    end
    es_reindex_meeting(member_meeting)
  end

  def after_save(member_meeting)
    es_reindex_meeting(member_meeting)
  end

  def es_reindex_meeting(member_meeting)
    # Elasticsearch delta indexing should happen in es_reindex method so that indexing for update_column/update_all or delete/delete_all will be taken care.
    if member_meeting.saved_change_to_attending? || member_meeting.new_record? || member_meeting.destroyed?
      MemberMeeting.es_reindex(member_meeting)
    end
  end
end
