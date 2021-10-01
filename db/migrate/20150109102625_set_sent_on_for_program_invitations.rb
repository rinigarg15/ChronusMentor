class SetSentOnForProgramInvitations< ActiveRecord::Migration[4.2]
  def up
    ProgramInvitation.where("sent_on IS NULL").each do |pi|
      pi.skip_observer = true
      pi.sent_on = pi.created_at
      pi.save!
    end
  end

  def down
  end
end
