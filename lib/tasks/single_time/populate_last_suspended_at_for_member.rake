namespace :single_time do
  desc 'Populate last suspended at for members'
  task :populate_last_suspended_at_for_members => :environment do
    prev_time = Time.now
    last_suspended_map = User.connection.select_all(User.select("member_id, MAX(last_deactivated_at) AS last_deactivated_at").group(:member_id)).rows.to_h
    Member.suspended.find_each do |member|
      member.update_columns(last_suspended_at: last_suspended_map[member.id], skip_delta_indexing: true) if last_suspended_map[member.id]
    end
    puts "Updated in #{Time.now - prev_time} seconds"
    ElasticsearchReindexing.indexing_flipping_deleting([Member.name])
  end
end