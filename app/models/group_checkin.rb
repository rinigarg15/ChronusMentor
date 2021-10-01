# == Schema Information
#
# Table name: group_checkins
#
#  id                   :integer          not null, primary key
#  comment              :text(65535)
#  checkin_ref_obj_id   :integer
#  checkin_ref_obj_type :string(255)
#  duration             :integer
#  date                 :datetime
#  user_id              :integer
#  program_id           :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  group_id             :integer
#  title                :string(255)
#

class GroupCheckin < ActiveRecord::Base

  CHECKIN_MINUTE_STEP = 15

  attr_accessor :hours, :minutes

  belongs_to :checkin_ref_obj, :polymorphic => true
  belongs_to :task, -> { where("checkin_ref_obj_type = 'MentoringModel::Task'") }, class_name: 'MentoringModel::Task', foreign_key: 'checkin_ref_obj_id'
  belongs_to :user
  belongs_to :group
  belongs_to :program

  validate :duration_minutes_range
  validates :date, :user, :group, :checkin_ref_obj_type, :checkin_ref_obj_id, :program, :title, presence: true

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:comment],
    :update => [:comment, :date]
  }

  def hours
    self.duration.present? ? (self.duration / 60) : 0
  end

  def minutes
    self.duration.present? ? (self.duration % 60) : 0
  end

  def self.meetings_checkin_creation
    program_ids = Program.includes(:enabled_db_features, organization: [:enabled_db_features, :disabled_db_features]).select(&:contract_management_enabled?).map(&:id)
    time_now = Time.now
    start_time = time_now - Meeting::CHECKIN_START_WINDOW
    end_time = time_now

    all_meetings = Meeting.in_programs(program_ids).group_meetings.slot_availability_meetings.includes(:group)
    completed_meetings = all_meetings.between_time(start_time, end_time)
    past_meetings = all_meetings.past.where("created_at > ?", start_time.utc.to_s(:db))
    valid_past_meetings = Meeting.recurrent_meetings(past_meetings, {get_merged_list: true, get_only_past_meetings: true})
    valid_completed_meetings = Meeting.recurrent_meetings(completed_meetings, {get_merged_list: true, with_endtime_in: true, end_time: end_time, start_time: start_time})
    BlockExecutor.iterate_fail_safe((valid_completed_meetings + valid_past_meetings).uniq) do |meetings_hash|
      meeting = meetings_hash[:meeting]
      current_occurrence_time = meetings_hash[:current_occurrence_time]

      BlockExecutor.iterate_fail_safe(meeting.member_meetings) do |member_meeting|
        group = meeting.group
        user = member_meeting.member.user_in_program(meeting.program_id)
        next if user.blank?

        response = member_meeting.get_response_object(current_occurrence_time)
        if self.can_create_checkin?(user, member_meeting, current_occurrence_time, response)
          self.create_meeting_checkin_obj(user, member_meeting, current_occurrence_time, meeting.program, meeting)
        end
      end
    end
  end

  def self.create_meeting_checkin_obj(user, member_meeting, current_occurrence_time, program, meeting)
    group = meeting.group
    checkin_obj = GroupCheckin.new
    checkin_obj.user_id = user.id
    checkin_obj.checkin_ref_obj = member_meeting
    checkin_obj.date = current_occurrence_time
    checkin_obj.program = program
    checkin_obj.duration = meeting.schedule.duration / 60
    checkin_obj.title = meeting.topic
    checkin_obj.group = group
    checkin_obj.save!
  end

  def self.can_create_checkin?(user, member_meeting , current_occurrence_time , response)
    #you should be making a checkin for a meeting if the user is a mentor , has not responded negetively
    # and a previous checkin with the same user id , member meeting id and date does not exist
    group = member_meeting.meeting.group
    cond1 = group.has_mentor?(user) && !(response && response.rejected?)
    #dont make a database query if not required
    return false unless cond1
    checkin_not_exists = !GroupCheckin.exists?(user_id: user.id,
      checkin_ref_obj_type: MemberMeeting.to_s,
      checkin_ref_obj_id: member_meeting.id,
      date: current_occurrence_time)
    return cond1 && checkin_not_exists
  end

  module KendoScopes

    def self.sort_mentors(dir)
      dir = (dir == 'asc') ? 'asc' : 'desc' #preventing sql injection attacks
      GroupCheckin.joins("LEFT JOIN users ON users.id = group_checkins.user_id").joins("LEFT JOIN members ON members.id = users.member_id").order("members.first_name #{dir}").order("members.last_name #{dir}").distinct
    end

    def self.sort_groups(dir)
      dir = (dir == 'asc') ? 'asc' : 'desc'  #preventing sql injection attacks
      GroupCheckin.joins("LEFT JOIN groups ON groups.id = group_checkins.group_id").order("groups.name #{dir}").distinct
    end

    def self.sort_type(dir)
      dir = (dir == 'asc') ? 'asc' : 'desc'  #preventing sql injection attacks
      GroupCheckin.order("checkin_ref_obj_type #{dir}")
    end

    def self.filter_mentors(filter)
      value = filter[:value]
      GroupCheckin.joins("LEFT JOIN users ON users.id = group_checkins.user_id").joins("LEFT JOIN members ON members.id = users.member_id").where("members.last_name LIKE ? OR members.first_name LIKE ?", "%#{value}%", "%#{value}%" )
    end

    def self.filter_user(filter)
      user_id = filter[:value]
      GroupCheckin.joins("LEFT JOIN users ON users.id = group_checkins.user_id").where("users.id = ?", user_id)
    end

    def self.filter_groups(filter)
      value = filter[:value]
      GroupCheckin.joins("LEFT JOIN groups ON groups.id = group_checkins.group_id").where("groups.name LIKE ?", "%#{value}%")
    end

    def self.filter_dates(filter)
      start_date = DateTime.parse(filter["start_date"])
      end_date = DateTime.parse(filter["end_date"]) + 1.day
      GroupCheckin.where("date >= ? and date < ?", start_date, end_date)
    end

    def self.filter_type(filter)
      value = filter[:value]
      case value
      when "Meeting"
        return GroupCheckin.where("checkin_ref_obj_type = ?", MemberMeeting.name)
      when "Task"
        return GroupCheckin.where("checkin_ref_obj_type = ?", MentoringModel::Task.name)
      else
        GroupCheckin.scoped
      end
    end
  end

  private

  def duration_minutes_range
    errors.add(:duration, "feature.group_checkin.error_message.duration_range_error_v1".translate) unless (duration % CHECKIN_MINUTE_STEP == 0 && duration >= CHECKIN_MINUTE_STEP)
  end
end