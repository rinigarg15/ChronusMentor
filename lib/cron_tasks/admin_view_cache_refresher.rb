module CronTasks
  class AdminViewCacheRefresher
    include Delayed::RecurringJob

    def perform
      AdminViewUserCache.refresh_admin_view_user_ids_cache
    end
  end
end