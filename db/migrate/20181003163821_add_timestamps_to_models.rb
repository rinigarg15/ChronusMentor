class AddTimestampsToModels < ActiveRecord::Migration[5.1]
  TABLES_TO_ADD_TIMESTAMPS = [:cm_email_event_logs, :facilitation_delivery_logs, :features, :feed_exporters, :forums, :moderatorships, :organization_features, :permissions, :profile_pictures, :program_event_users, :program_invitations, :received_mails, :role_permissions, :sections, :taggings, :tags, :user_activities, :user_stats]
  TABLES_TO_IGNORE_CREATED_AT = [:program_invitations, :taggings]

  def up
    ChronusMigrate.ddl_migration do
      TABLES_TO_ADD_TIMESTAMPS.each do |table|
        Lhm.change_table table do |t|
          t.add_column :created_at, :datetime unless TABLES_TO_IGNORE_CREATED_AT.include?(table)
          t.add_column :updated_at, :datetime
        end
      end
    end

    ChronusMigrate.data_migration(has_downtime: false) do
      users_created_at = ProgramInvitation.where("use_count > ?", 0).joins("INNER JOIN members ON members.email = program_invitations.sent_to").joins("INNER JOIN users ON members.id = users.member_id AND program_invitations.program_id = users.program_id").pluck("program_invitations.id", "users.created_at").to_h
      ProgramInvitation.where("use_count > ?", 0).select(:id).each do |invitation|
        next unless users_created_at[invitation.id]
        invitation.update_column(:updated_at, users_created_at[invitation.id])
      end
      ProgramInvitation.where(updated_at: nil).update_all("updated_at=created_at")
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      TABLES_TO_ADD_TIMESTAMPS.each do |table|
        Lhm.change_table table do |t|
          t.remove_column :created_at unless TABLES_TO_IGNORE_CREATED_AT.include?(table)
          t.remove_column :updated_at
        end
      end
    end
  end
end