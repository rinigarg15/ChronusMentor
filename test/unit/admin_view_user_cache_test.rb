require_relative '../test_helper'

class AdminViewUserCacheTest < ActiveSupport::TestCase
  def test_validations
    admin_view_user_cache = AdminViewUserCache.new
    assert_false admin_view_user_cache.valid?
    assert_equal ["can't be blank"], admin_view_user_cache.errors.messages[:admin_view_id]

    admin_view_user_cache.admin_view_id = admin_views(:admin_views_1).id
    assert admin_view_user_cache.valid?
  end

  def test_refresh_admin_view_user_cache_ids_cache
    AdminView.any_instance.expects(:generate_view).with("", "", false).returns([1, 2, 3]).times(AdminViewUserCache.count)
    time = DateTime.now
    DateTime.stubs(:now).returns(time)
    AdminViewUserCache.refresh_admin_view_user_ids_cache
    AdminViewUserCache.find_each do |admin_view_user_cache|
      assert_equal "1,2,3", admin_view_user_cache.user_ids
      assert_equal time.utc.to_s, admin_view_user_cache.last_cached_at.to_datetime.utc.to_s
    end
  end

  def test_get_admin_view_user_ids
    admin_view_user_cache = AdminViewUserCache.first
    admin_view_user_cache.update_column(:user_ids, "1,2,3")
    assert_equal [1,2,3], admin_view_user_cache.get_admin_view_user_ids
  end
end