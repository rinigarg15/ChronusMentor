module Program::Dashboard::CommunityAnnouncementsEventsReport
  extend ActiveSupport::Concern

  included do
    include AnnouncementsHelper
    include ProgramEventsHelper
  end

  def community_announcement_event_report_enabled?
    self.is_report_enabled?(DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS)
  end

  private

  def get_announcements_and_events_data
    {announcements: get_active_announcements_data, events: get_upcoming_events_data} 
  end

  def get_active_announcements_data
    data = []
    active_announcements = self.announcements.published.not_expired.ordered.includes(:recipient_roles).first(Announcement::UPCOMING_COUNT)
    return data if active_announcements.empty?
    data << {display_expires_on: false}
    active_announcements.each do |announcement|
      announcement_hash = {}
      announcement_hash[:announcement] = announcement
      announcement_hash[:for] = get_announcement_recipients(announcement)
      data.first[:display_expires_on] = true if announcement.expiration_date.present?
      data << announcement_hash
    end
    data
  end

  def get_upcoming_events_data
    data = []
    return data unless self.program_events_enabled?
    upcoming_events = self.program_events.published.upcoming.includes(:event_invites).first(Announcement::UPCOMING_COUNT)
    upcoming_events.each do |program_event|
      event_hash = {}
      event_hash[:program_event] = program_event
      event_hash[:attending] = program_event.get_attending_size
      data << event_hash
    end
    data
  end
end