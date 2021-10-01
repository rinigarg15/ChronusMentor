# == Schema Information
#
# Table name: admin_view_user_caches
#
#  id                  :integer          not null, primary key
#  admin_view_id       :integer
#  last_cached_at      :datetime
#  user_ids            :longtext
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class AdminViewUserCache < ActiveRecord::Base
  belongs_to :admin_view
  validates :admin_view_id, presence: true

  def self.refresh_admin_view_user_ids_cache
    BlockExecutor.iterate_fail_safe(AdminViewUserCache.includes(:admin_view)) do |admin_view_user_cache|
      admin_view = admin_view_user_cache.admin_view
      user_ids = admin_view.generate_view("", "", false).to_a
      current_time = DateTime.now.utc
      admin_view_user_cache.update_columns(user_ids: user_ids.join(COMMA_SEPARATOR), last_cached_at: current_time, updated_at: current_time)
    end
  end

  def get_admin_view_user_ids
    self.user_ids.to_s.split(COMMA_SEPARATOR).collect(&:to_i)
  end
end