class ProgramEventUpdateJob < Struct.new(:program_event_id, :status_changed, :block_mail, :existing_invitees)
  def perform
    program_event = ProgramEvent.find_by(id: program_event_id)
    if program_event.try(:published_upcoming?)
      if status_changed
        program_event.handle_new_published_event
      else
        program_event.append_to_recent_activity(RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE)
        if program_event.email_notification == true && !block_mail
          options = { send_now: true, users_ids: program_event.user_ids }
          options[:users_ids] &= existing_invitees if existing_invitees.present?
          ProgramEvent.notify_users(program_event, RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE, program_event.version_number, options)
        end
      end
    end
  end
end