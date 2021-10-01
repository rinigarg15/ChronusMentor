class AddIndexOnCodeForProgramInvitations< ActiveRecord::Migration[4.2]
  def change
    add_index :program_invitations, :code, name: :index_on_code_for_program_invitations
  end
end
