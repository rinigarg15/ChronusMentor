# == Schema Information
#
# Table name: event_invites
#
#  id                 :integer          not null, primary key
#  status             :integer
#  reminder           :boolean          default(FALSE)
#  program_event_id   :integer
#  user_id            :integer
#  created_at         :datetime
#  updated_at         :datetime
#  reminder_sent_time :datetime
#

class EventInvite < ActiveRecord::Base

  module Status
    YES   = 0
    NO    = 1
    MAYBE = 2

    def self.title(status)
      case status
      when YES then "display_string.Yes".translate
      when NO then "display_string.No".translate
      when MAYBE then "display_string.Maybe".translate
      else "feature.program_event.label.Not_responded".translate
      end
    end

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  CALENDAR_EVENT_TO_PROGRAM_EVENT_RSVP_MAP_ICS = {
    ProgramEvent::CalendarEventPartStatValues::ACCEPTED => Status::YES,
    ProgramEvent::CalendarEventPartStatValues::DECLINED => Status::NO,
    ProgramEvent::CalendarEventPartStatValues::TENTATIVE => Status::MAYBE
  }

  belongs_to :user
  belongs_to :program_event

  validates :user, :program_event, :status, presence: true
  validates :status, inclusion: { in: Status.all }

  scope :attending, -> { where(status: Status::YES) }
  scope :not_attending, -> { where(status: Status::NO) }
  scope :maybe_attending, -> { where(status: Status::MAYBE) }

  scope :for_user, Proc.new {|user| where(user_id: user.id) }
  scope :needs_reminder, -> { where(status: [Status::YES, Status::MAYBE], reminder: true, reminder_sent_time: nil) }

  def attending?
    self.status == Status::YES
  end

  def not_attending?
    self.status == Status::NO
  end

  def maybe_attending?
    self.status == Status::MAYBE
  end

  def handle_rsvp_from_program_event_and_calendar_event(event_rsvp)
    existing_rsvp = self.status
    new_rsvp = EventInvite::CALENDAR_EVENT_TO_PROGRAM_EVENT_RSVP_MAP_ICS[event_rsvp]
    if new_rsvp.present? && existing_rsvp != new_rsvp
      self.update_attributes!(status: new_rsvp)
    end
  end
end
