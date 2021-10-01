class AddAllowUsersToMarkConnectionPublicToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_users_to_mark_connection_public, :boolean, :default => false

    Program.all.each do |program|
      program.update_attributes!(:allow_users_to_mark_connection_public => true) if program.connection_profiles_enabled?
    end
  end
end
