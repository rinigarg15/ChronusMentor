class AddLocaleToProgramInvitations< ActiveRecord::Migration[4.2]
  def change
    add_column :program_invitations, :locale, :string
  end
end
