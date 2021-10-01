namespace :single_time do
  desc 'Populate last deactivated at for users'
  task :populate_last_deactivated_at => :environment do
    user_id_map = {}
    prev_time = Time.now
    UserStateChange.order(created_at: :desc).each do |transition|
      next if user_id_map[transition.user_id].present?
      state = transition.info_hash[:state]
      user_id_map[transition.user_id] = transition.created_at if state[:to] == User::Status::SUSPENDED && state[:from] != User::Status::SUSPENDED
    end
    end_time = Time.now
    puts "Built hash in #{end_time - prev_time}"
    prev_time = end_time
    User.where(id: user_id_map.keys).each do |user|
      user.update_columns(last_deactivated_at: user_id_map[user.id], skip_delta_indexing: true)
    end
    end_time = Time.now
    puts "Users updated in #{end_time - prev_time}"
    ElasticsearchReindexing.indexing_flipping_deleting([User.name])
  end
end