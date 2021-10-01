require_relative './../../../test_helper'

class CronTasks::AdminViewCacheRefresherTest < ActiveSupport::TestCase

  def test_perform
    AdminViewUserCache.expects(:refresh_admin_view_user_ids_cache).once
    CronTasks::AdminViewCacheRefresher.new.perform
  end
end