class CleanupContentChangerMemberIdForNonExistentMembersFromMailerTemplate< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      all_member_ids = Member.pluck(:id)
      Mailer::Template.where.not(content_changer_member_id: all_member_ids).update_all(content_changer_member_id: nil)
    end
  end

  def down
    # do nothing
  end
end
