class ProgramEventObserver < ActiveRecord::Observer
  def after_create(program_event)
    program_event.set_users_from_admin_view!
    Delayed::Job.enqueue(ProgramEventCreateJob.new(program_event.id), queue: DjQueues::HIGH_PRIORITY)
  end

  def after_update(program_event)
    clear_rsvps(program_event) if program_event.published? && (program_event.saved_change_to_start_time? || program_event.saved_change_to_end_time?)
    existing_invitees = program_event.user_ids
    if program_event.saved_change_to_admin_view_id? && program_event.admin_view.present?
      program_event.set_users_from_admin_view!(status_changed: program_event.saved_change_to_status?, send_mails_for_newly_added: !program_event.saved_change_to_status?)
    end
    Delayed::Job.enqueue ProgramEventUpdateJob.new(program_event.id, program_event.saved_change_to_status?, program_event.block_mail, existing_invitees)
  end

  private

  def clear_rsvps(program_event)
    program_event.event_invites.destroy_all
    program_event.recent_activities.of_type([RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE]).destroy_all
  end
end