#USAGE
# rake single_time:remove_invalid_ref_obj_pending_notification PENDING_NOTIFICATION_IDS='2021414, 2021422, 2021420, 2021415, 2021424, 2021417, 2018699, 2021413, 2021421, 2021419, 2021423, 2021416, 2021418, 2018700'
namespace :single_time do
  desc 'Remove deleted ref object entries in pending_notifications table'
  task remove_invalid_ref_obj_pending_notification: :environment do
    pending_notification_ids = ENV['PENDING_NOTIFICATION_IDS'].split(',').map(&:to_i)
    PendingNotification.where(id: pending_notification_ids).each do |notification|
      if notification.ref_obj.present?
        puts "#{notification.id} contains the ref object. Hence not deleting.."
      else
        notification.destroy
      end
    end
  end
end
