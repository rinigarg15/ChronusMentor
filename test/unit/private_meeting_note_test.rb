require_relative './../test_helper.rb'

class PrivateMeetingNoteTest < ActiveSupport::TestCase

  def test_association_member_meeting
    private_meeting_note = connection_private_notes(:meeting_mentor_student_1)
    assert_equal private_meeting_note.member_meeting, meetings(:f_mentor_mkr_student).member_meetings.first
  end

  def test_associtaion_member
  	private_meeting_note = connection_private_notes(:meeting_mentor_student_1)
  	assert_equal private_meeting_note.owner, Member.find(meetings(:f_mentor_mkr_student).member_meetings.first.member_id)
  end

  def test_validate_member_meeting
    n = PrivateMeetingNote.new
    n.valid?

    assert n.errors[:member_meeting]
  end

  def test_new_for
    meeting = meetings(:f_mentor_mkr_student)
    member = members(:f_mentor)
    member_meeting = meeting.member_meetings.where(member_id: member.id).first
    note = PrivateMeetingNote.new_for(
      meeting, member, {:text => 'hello'})
    
    assert_equal meetings(:f_mentor_mkr_student).member_meetings.where(:member_id => members(:f_mentor).id).first, note.member_meeting
    assert_equal 'hello', note.text
    assert note.valid?
    
    member = members(:mkr_student)
    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)
    member_meeting = meeting.member_meetings.where(member_id: member.id).first
    note = PrivateMeetingNote.new_for(
     meeting, member, {
        :text => 'hello',
        :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    })

    assert_equal meetings(:f_mentor_mkr_student).member_meetings.where(:member_id => members(:mkr_student).id).first, note.member_meeting
    assert_equal 'hello', note.text
    assert_false note.valid?
  end
end