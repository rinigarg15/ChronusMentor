# == Schema Information
#
# Table name: mentor_requests
#
#  id                 :integer          not null, primary key
#  program_id         :integer
#  created_at         :datetime
#  updated_at         :datetime
#  status             :integer          default(0)
#  sender_id          :integer
#  receiver_id        :integer
#  message            :text(65535)
#  response_text      :text(65535)
#  group_id           :integer
#  show_in_profile    :boolean          default(TRUE)
#  type               :string(255)      default("MentorRequest")
#  delta              :boolean          default(FALSE)
#  closed_by_id       :integer
#  closed_at          :datetime
#  reminder_sent_time :datetime
#  sender_role_id     :integer
#  accepted_at        :datetime
#  acceptance_message :text(65535)
#

class AbstractRequest < ActiveRecord::Base
  self.table_name = 'mentor_requests'

  MENTOR_REQUEST = "mentor_request"
  MEETING_REQUEST = "meeting_request"
    
  class Filter
    TO_ME = 'me'
    BY_ME = 'by_me'
    ALL = 'all'

    def self.all
      [TO_ME, BY_ME, ALL]
    end

    ACTIVE = 'active'
    ACCEPTED = 'accepted'
    REJECTED = 'rejected'
    WITHDRAWN = 'withdrawn'
    CLOSED = 'closed'

    def self.states
      [ACTIVE, ACCEPTED, REJECTED, WITHDRAWN, CLOSED]
    end
  end

  # Status of the mentor request
  class Status
    NOT_ANSWERED = 0
    ACCEPTED = 1
    REJECTED = 2
    WITHDRAWN = 3
    CLOSED = 4

    STATE_TO_STRING = {
      NOT_ANSWERED => "pending",
      ACCEPTED => "accepted",
      REJECTED => "declined",
      WITHDRAWN => "withdrawn",
      CLOSED => "closed"
    }

    STRING_TO_STATE = {
      'active' => Status::NOT_ANSWERED,
      'pending' => Status::NOT_ANSWERED,
      'accepted' => Status::ACCEPTED,
      'declined' => Status::REJECTED,
      'rejected' => Status::REJECTED,
      'withdrawn' => Status::WITHDRAWN,
      'closed' => Status::CLOSED
    }

    STATUS_TO_SCOPE = {
      NOT_ANSWERED => :active,
      ACCEPTED => :accepted,
      REJECTED => :rejected,
      WITHDRAWN => :withdrawn,
      CLOSED => :closed
    }

    STRING_TO_SCOPE = {
      STATE_TO_STRING[NOT_ANSWERED] => :active,
      STATE_TO_STRING[ACCEPTED] => :accepted,
      STATE_TO_STRING[REJECTED] => :rejected,
      STATE_TO_STRING[WITHDRAWN] => :withdrawn,
      STATE_TO_STRING[CLOSED] => :closed
    }

    def self.all
      [NOT_ANSWERED, ACCEPTED, REJECTED, WITHDRAWN, CLOSED]
    end
  end

  module AllowedRequestTypeChange
    MENTOR_REQUEST_TO_MEETING_REQUEST = 1

    def self.all
      [MENTOR_REQUEST_TO_MEETING_REQUEST]
    end
  end

  module Rejection_type
    MATCHING = 1
    REACHED_LIMIT = 2
    BUSY = 3
    OTHERS = 4
  end

  belongs_to_program
  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :pending_notifications, as: :ref_obj, dependent: :destroy
  has_many :push_notifications, :as => :ref_obj

  validates :status, :program, presence: true
  validates :status, inclusion: Status.all
  validates :allowed_request_type_change, inclusion: AllowedRequestTypeChange.all, allow_nil: true

  # Fetches only not answered requests
  scope :active, -> { where( :status => Status::NOT_ANSWERED )}
  scope :inactive, -> { where("status != ?", Status::NOT_ANSWERED)}
  
  scope :for_program, Proc.new {|program| where({:program_id => program.id})}

  # Requests from the given student.
  scope :from_student, Proc.new {|student| where("sender_id = ?", student.id)}

  # Requests sent to the mentor
  scope :to_mentor, Proc.new {|mentor| where("receiver_id = ?", mentor.id)}

  # Requests from the given role.
  scope :with_role, Proc.new {|role| where("sender_role_id = ?", role.id)}

  scope :accepted, -> { where(:status => Status::ACCEPTED) }
  scope :rejected, -> { where( :status => Status::REJECTED )}
  scope :withdrawn, -> { where( :status => Status::WITHDRAWN )}
  scope :closed, -> { where( :status => Status::CLOSED )}
  scope :with_status_in, Proc.new {|statuses| where("status IN(?)", statuses)}

  # Note that you cannot do MentorRequest.accepted.rejected to get all answered requests
  scope :answered, -> { where( :status => [AbstractRequest::Status::ACCEPTED, AbstractRequest::Status::REJECTED] )}
  scope :created_in_date_range, Proc.new {|date_range| where({:created_at => date_range})}
  scope :updated_in_date_range, Proc.new {|date_range| where({:updated_at => date_range})}
  scope :accepted_in, Proc.new{|start_window, end_window| where({:accepted_at => start_window.utc..end_window.utc})}

  def self.closable(column_name)
    active.joins(:program).where("DATEDIFF(CURDATE(), mentor_requests.created_at) > programs.#{column_name}").readonly(false)
  end

  def active?
    status == AbstractRequest::Status::NOT_ANSWERED
  end

  def accepted?
    status == AbstractRequest::Status::ACCEPTED
  end

  def rejected?
    status == AbstractRequest::Status::REJECTED
  end

  def withdrawn?
    status == AbstractRequest::Status::WITHDRAWN
  end

  def closed?
    status == AbstractRequest::Status::CLOSED
  end

  def allow_request_type_change_from_mentor_to_meeting?
    allowed_request_type_change == AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST
  end

  def close!(reason)
    #Only active requests can be closed
    return unless self.active?
    self.response_text = reason
    self.status = AbstractRequest::Status::CLOSED
    self.closed_at = Time.now
    self.save!
  end
end
