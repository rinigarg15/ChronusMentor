class UpdateSentOnFieldInProgramInvitation< ActiveRecord::Migration[4.2]
  def change
    ProgramInvitation.where(sent_on: nil).find_each do |invitation|
      invitation.update_column(:sent_on, invitation.created_at)
    end
  end
end