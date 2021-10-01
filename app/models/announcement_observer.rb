class AnnouncementObserver < ActiveRecord::Observer
  def after_create(announcement)
    if announcement.published?
      after_publish(announcement)
    end
  end

  def after_update(announcement)
    return unless announcement.published?

    if announcement.saved_change_to_status?
      after_publish(announcement)
    elsif announcement.notify?
      Announcement.delay.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, announcement.version_number, announcement.notify_immediately?)
      Push::Base.queued_notify(PushNotification::Type::ANNOUNCEMENT_UPDATE, announcement)
    end
  end

  private

  def after_publish(announcement)
    append_to_recent_activity(announcement)
    return unless announcement.notify?

    Announcement.delay.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version_number, announcement.notify_immediately?)
    Push::Base.queued_notify(PushNotification::Type::ANNOUNCEMENT_NEW, announcement)
  end

  # Append Recent Activity
  def append_to_recent_activity(announcement)
    # Find out the target
    # TODO : adding ra for community users
    target = announcement.recent_activity_target
    return unless target.present?

    RecentActivity.create!(
      programs: [announcement.program],
      member: announcement.admin.member,
      ref_obj: announcement,
      action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      target: target)
  end
end
