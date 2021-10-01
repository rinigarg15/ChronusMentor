namespace :single_time do
  desc 'Set view count of the resources to zero in demo'
  task demo_set_resource_view_count_zero: :environment do
    Resource.where(view_count: nil).update_all(view_count: 0)
  end
end
