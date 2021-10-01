class EventInviteObserver < ActiveRecord::Observer
  def after_create(event_invite)
    append_to_recent_activity(event_invite)
  end

  def after_update(event_invite)
    if event_invite.saved_change_to_status?
      append_to_recent_activity(event_invite)
    end
  end

  private

  # Append Recent Activity
  def append_to_recent_activity(event_invite)
    program_event = event_invite.program_event
    target = program_event.recent_activity_target || RecentActivityConstants::Target::ALL

    act_type = if event_invite.attending?
      RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT
    elsif event_invite.not_attending?
      RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT
    elsif event_invite.maybe_attending?
      RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE
    end

    ra = RecentActivity.create!(
      member: event_invite.user.member,
      ref_obj: program_event,
      action_type: act_type,
      target: target)
    ra.programs = [program_event.program]
    ra.save!
  end
end
