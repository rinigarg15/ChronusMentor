# Problems with this approach.
# This might incrase the overall migration time. Adding it to DJ might solve, but let us see
class FlushPendingInboxNotifications< ActiveRecord::Migration[4.2]
  def up
    Organization.active.each do |organization|
      puts "Flushing pending inbox notifications for #{organization.name}"
        organization.members.active.joins(:pending_notifications).group("members.id").each do |member|
          ChronusMailer.aggregated_member_mail(member).deliver_now
          # Delete the notifications after sending them
          member.pending_notifications.destroy_all
      end
    end
  end

  def down
  end

end
