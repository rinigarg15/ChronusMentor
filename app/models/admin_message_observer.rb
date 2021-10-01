class AdminMessageObserver < ActiveRecord::Observer
  def after_create(admin_message)
    if admin_message.parent_id
      root_id = admin_message.parent.root_id.zero? ? admin_message.parent_id : admin_message.parent.root_id
      admin_message.update_attribute(:root_id, root_id)
    else
      admin_message.update_attribute(:root_id, admin_message.id)
    end
    send_emails(admin_message) unless admin_message.no_email_notifications
  end

  private

  def send_emails(admin_message)
    # Notify all admins (except the sender, if the sender is also an admin) about the new message
    if admin_message.user_to_admin?
      # We are not sending push notification for this case since we do not have admin messages page in mobile client.
      options = { send_now: true, sender: admin_message.get_sender }
      if admin_message.for_program?
        admins = admin_message.program.admin_users.active_or_pending
        notif_type = RecentActivityConstants::Type::ADMIN_MESSAGE_NOTIFICATION
      else
        admins = admin_message.program.members.admins.active
        notif_type = RecentActivityConstants::Type::NEW_ADMIN_MESSAGE_TO_MEMBER
      end
      admins_except_sender = admins.select { |admin| admin != options[:sender] }
      admins_except_sender.each do |admin|
        admin.delay(queue: DjQueues::HIGH_PRIORITY).send_email(admin_message, notif_type, options)
      end
    # System generated mails like facilitation messages
    elsif admin_message.auto_email?
      notif_type = admin_message.campaign_message ? RecentActivityConstants::Type::USER_CAMPAIGN_EMAIL_NOTIFICATION : RecentActivityConstants::Type::AUTO_EMAIL_NOTIFICATION
      AbstractMessage.delay(queue: DjQueues::HIGH_PRIORITY).send_email_notifications(admin_message.id, notif_type, send_now: true)
      Push::Base.queued_notify(PushNotification::Type::MESSAGE_SENT_ADMIN, admin_message)
    elsif admin_message.admin_to_registered_user?
      AbstractMessage.delay(queue: DjQueues::HIGH_PRIORITY).send_email_notifications(admin_message.id, admin_message.inbox_message_notification_type, {}, { parallel_processing: true, batch_processing: true })
      Push::Base.queued_notify(PushNotification::Type::MESSAGE_SENT_ADMIN, admin_message)
    elsif admin_message.admin_to_offline_user?
      AdminMessage.delay(queue: DjQueues::HIGH_PRIORITY).send_new_message_to_offline_user_notification(admin_message.id)
    end
  end
end