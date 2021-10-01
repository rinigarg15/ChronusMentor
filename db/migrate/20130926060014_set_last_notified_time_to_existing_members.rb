# This db migration sets value of last_notified_time to the existing members
class SetLastNotifiedTimeToExistingMembers< ActiveRecord::Migration[4.2]
  def up
  	# Setting the init time in such a way that irrespective of member notification settings (all / daily / weekly), the cron sends any pending notifications for the first time.
  	Member.update_all(:last_notified_time => 8.days.ago)
  end

  def down
  end
end
