class RemoveDeletedAtFromMembershipRequests < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      membership_request_ids = MembershipRequest.where.not(deleted_at: nil).pluck(:id)
      recent_activity_ids = RecentActivity.where(ref_obj_id: membership_request_ids, ref_obj_type: MembershipRequest.name).pluck(:id)

      DataScrubber.new.scrub_recent_activities(recent_activity_ids)
      MembershipRequest.where(id: membership_request_ids).delete_all
    end
  end

  def down
  end
end