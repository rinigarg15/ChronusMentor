class AddRemainderJobsForPendingProgramInvitations < ActiveRecord::Migration[4.2]

  def up
    start_time = Time.now
    Program.active.each do |program|
      campaign = program.program_invitation_campaign
      unless campaign.nil?
        program.program_invitations.pending.each do |program_invitation|
          if program_invitation.is_sender_admin?
            status = campaign.statuses.create!(:abstract_object_id => program_invitation.id)
            invitation_sent_on = program_invitation.sent_on.nil? ? program_invitation.created_at : program_invitation.sent_on
            status.update_attributes(:created_at => invitation_sent_on)
            campaign.campaign_messages.each do |campaign_message|
              run_at = invitation_sent_on + campaign_message.duration.days
              if run_at >= start_time
                campaign_message.create_jobs({abstract_object_id: program_invitation.id, run_at: run_at})
              end
            end
          end
        end
      end
    end
  end

  def down
  end
end
