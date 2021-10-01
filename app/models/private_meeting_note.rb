# == Schema Information
#
# Table name: connection_private_notes
#
#  id                      :integer          not null, primary key
#  text                    :text(65535)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  created_at              :datetime
#  updated_at              :datetime
#  ref_obj_id              :integer
#  type                    :string(255)
#

class PrivateMeetingNote < AbstractNote

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to :member_meeting,
             :foreign_key => 'ref_obj_id',
             :class_name => 'MemberMeeting'

  has_one :owner,
          :through => :member_meeting,
          :source => :member,
          :class_name => 'Member'

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates :member_meeting, presence: true

  def self.new_for(meeting, wob_member, attributes)
    PrivateMeetingNote.new(
      attributes.merge(:ref_obj_id => meeting.member_meetings.find_by(member_id: wob_member.id).id))
  end

  def can_be_edited_or_deleted_by_member?(member)
    meeting = self.member_meeting.meeting
    self.owner == member && meeting.active? && meeting.has_member?(member)
  end
end
