class AddIndexToProgramInvitation< ActiveRecord::Migration[4.2]
  def change
    add_index :program_invitations, :program_id, name: :index_on_program_id_for_program_invitations
  end
end