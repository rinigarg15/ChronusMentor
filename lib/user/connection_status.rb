module User::ConnectionStatus
  extend ActiveSupport::Concern
  
  module ConnectionStatus
    ONGOING = 'Ongoing'
    FLASH = 'Flash'
    BOTH = 'Both'
    NONE = 'Not Connected'

    def self.connected
      [ONGOING, FLASH, BOTH]
    end

    def self.not_connected
      [NONE]
    end
  end

  module TimeLine
    PAST = 'past'
    ONGOING = 'ongoing'
  end

  def current_connection_status
    connection_status(TimeLine::ONGOING)
  end

  def past_connection_status
    connection_status(TimeLine::PAST)
  end

  private

  def connection_status(timeline)
    if has_groups?(timeline) && has_meetings?(timeline)
      ConnectionStatus::BOTH
    elsif has_groups?(timeline)
      ConnectionStatus::ONGOING
    elsif has_meetings?(timeline)
      ConnectionStatus::FLASH
    else
      ConnectionStatus::NONE
    end
  end

  def has_groups?(timeline=TimeLine::PAST)
    (timeline == TimeLine::PAST) ? has_completed_groups? : has_ongoing_groups?
  end

  def has_meetings?(timeline=TimeLine::PAST)
    (timeline == TimeLine::PAST) ? has_completed_meetings? : has_upcoming_meetings?
  end

  def has_ongoing_groups?
    self.groups.active.any?
  end

  def has_completed_groups?
    self.groups.closed.any?
  end

  def has_upcoming_meetings?
    self.member.meetings.of_program(self.program).non_group_meetings.accepted_meetings.upcoming.any?
  end

  def has_completed_meetings?
    self.member.meetings.of_program(self.program).non_group_meetings.accepted_meetings.past.any?
  end
end