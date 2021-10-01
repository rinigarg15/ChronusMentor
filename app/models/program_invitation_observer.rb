class ProgramInvitationObserver < ActiveRecord::Observer

  def before_create(program_invitation)
    return if program_invitation.skip_observer

    if program_invitation.invitee_already_member?
      program_invitation.errors.add(:program_invitation, "activerecord.errors.models.program_invitation.invalid_record".translate)
      throw(:abort)
    else
      program_invitation.sent_on = program_invitation.created_at
    end
  end

  def after_create(program_invitation)
    return if program_invitation.skip_observer

    campaign = program_invitation.get_current_programs_program_invitation_campaign
    program_invitation.send_invitation(campaign, skip_sending_instantly: false, is_sender_admin: program_invitation.is_sender_admin?)
  end

  def after_update(program_invitation)
    return if program_invitation.skip_observer

    campaign = program_invitation.get_current_programs_program_invitation_campaign
    if program_invitation.saved_change_to_use_count? && program_invitation.is_sender_admin?
      campaign.stop_program_invitation_campaign(program_invitation)
    elsif program_invitation.saved_change_to_sent_on?
      program_invitation.send_invitation(campaign, skip_sending_instantly: false, is_sender_admin: program_invitation.is_sender_admin?)
    end
  end
end