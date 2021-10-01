namespace :single_time do
  desc 'Populate last suspended at for members'
  task populate_last_suspended_at_for_dormant_suspended_members: :environment do
    prev_time = Time.now
    members_scope = Member.suspended.where(last_suspended_at: nil)
    member_ids = members_scope.collect(&:id)
    DelayedEsDocument.skip_es_delta_indexing do
      members_scope.update_all("last_suspended_at = updated_at")
    end
    puts "Updated #{member_ids.count} members in #{Time.now - prev_time} seconds"
    DelayedEsDocument.delayed_bulk_partial_update_es_documents(Member, member_ids, [:last_suspended_at], [])
  end
end