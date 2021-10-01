# == Schema Information
#
# Table name: meeting_proposed_slots
#
#  id                 :integer          not null, primary key
#  meeting_request_id :integer          not null
#  start_time         :datetime
#  end_time           :datetime
#  location           :text(65535)
#  proposer_id        :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class MeetingProposedSlot < ActiveRecord::Base
  belongs_to :meeting_request
  belongs_to :proposer, class_name: "User"
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :proposer_id, presence: true
  scope :earliest_slots, -> {joins("INNER JOIN (SELECT meeting_request_id, MIN(start_time) AS latest_start_time FROM meeting_proposed_slots GROUP BY meeting_request_id) AS m1 ON meeting_proposed_slots.meeting_request_id = m1.meeting_request_id AND meeting_proposed_slots.start_time = m1.latest_start_time")}
  scope :between_time, Proc.new{|st,en| where(["start_time < ? and end_time > ?", en.utc.to_s(:db), st.utc.to_s(:db)])}

  def get_ics_file_url(user)
    meeting = meeting_request.try(:meeting)
    if meeting
      file_path = "/tmp/" + S3Helper.embed_timestamp("#{SecureRandom.hex(3)}_#{TEMP_FILE_NAME}")
      meeting.update_meeting_time(start_time, (end_time - start_time), {location: location, calendar_time_available: true, fake_update: true})
      File.write(file_path, meeting.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: user))
      meeting.reload
      S3Helper.transfer(file_path, MEETING_ICS_S3_PREFIX, APP_CONFIG[:chronus_mentor_common_bucket], {content_type: ICS_CONTENT_TYPE, url_expires: 7.days})
    end
  end
end
