module AnnouncementsHelper

  def get_delete_or_discard_text(announcement, options = {}) 
    if announcement.published?
      options[:capitalize] ? "display_string.Delete".translate : "display_string.delete".translate
    elsif announcement.drafted?
      options[:capitalize] ? "display_string.Discard".translate : "display_string.discard".translate
    end
  end

  def get_options_for_email_notifications(selected)
    options_for_select([
      ["feature.announcements.content.immediately".translate, UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE],
      ["feature.announcements.content.digest".translate,      UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY   ],
      ["feature.announcements.content.dont_send".translate,   UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND]
    ], selected)
  end

  def get_announcement_recipients(announcement)
    announcement.recipient_roles.empty? ? "--" : announcement.recipient_roles_str
  end

  def get_announcement_title(announcement)
    announcement.title.present? ? truncate(announcement.title.gsub(/([\n\t])/, " "), :length => ProgramEvent::TITLE_LENGTH) : "feature.announcements.label.no_title".translate
  end

  def announcement_expiration_date(expiration_date)
    expiration_date ? get_time_for_time_zone(expiration_date, wob_member.get_valid_time_zone, "%b #{expiration_date.day.ordinalize}") : "--"
  end

  def get_label_class(expiration_date)
    return "label-warning" if expiration_date.present? && expiration_date <= Time.now.utc + Announcement::EXPIRATION_WARNING.week
  end
end