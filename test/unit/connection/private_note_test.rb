require_relative './../../test_helper.rb'

class Connection::PrivateNoteTest < ActiveSupport::TestCase
  def test_validate_member
    n = Connection::PrivateNote.new
    n.valid?

    assert n.errors[:connection_membership]
  end

  def test_has_one_owner
    assert_difference 'Connection::PrivateNote.count' do
      Connection::PrivateNote.create!(
        :connection_membership => fetch_connection_membership(:mentor, groups(:mygroup)),
        :text => "Hey, my note!"
      )
    end

    note = Connection::PrivateNote.last
    assert_equal fetch_connection_membership(:mentor, groups(:mygroup)).user, note.owner
  end
  
  def test_create_with_attachment
    assert_difference 'Connection::PrivateNote.count' do
      Connection::PrivateNote.create!(
        :connection_membership => fetch_connection_membership(:mentor, groups(:mygroup)),
        :text => "Hey, my note!",
        :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      )
    end

    note = Connection::PrivateNote.last
    assert note.attachment?
    assert_equal 'some_file.txt', note.attachment_file_name
  end

  def test_create_should_trigger_activity
    assert_difference 'groups(:mygroup).activities.count' do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Connection::PrivateNote.count' do
          @note = Connection::PrivateNote.create!(
            :connection_membership => fetch_connection_membership(:mentor, groups(:mygroup)),
            :text => "Hey, my note!",
            :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
          )
        end
      end
    end

    activity = groups(:mygroup).activities.last
    assert_equal RecentActivityConstants::Type::GROUP_PRIVATE_NOTE_CREATION,
                 activity.action_type
    assert_equal users(:f_mentor), activity.get_user(groups(:mygroup).program)
    assert_equal RecentActivityConstants::Target::NONE, activity.target
    assert_equal @note, activity.ref_obj
  end

  def test_scope_owned_by
    assert_equal [
        connection_private_notes(:mygroup_mentor_1),
        connection_private_notes(:mygroup_mentor_2)],
      Connection::PrivateNote.owned_by(users(:f_mentor))

    assert_equal [connection_private_notes(:group_2_student_1)],
      Connection::PrivateNote.owned_by(users(:student_2))

    assert_equal [], Connection::PrivateNote.owned_by(users(:student_7))
  end

  def test_scope_on_group
    assert_equal [
        connection_private_notes(:mygroup_student_1),
        connection_private_notes(:mygroup_student_2),
        connection_private_notes(:mygroup_student_3),
        connection_private_notes(:mygroup_mentor_1),
        connection_private_notes(:mygroup_mentor_2)],
      Connection::PrivateNote.on_group(groups(:mygroup))

    assert_equal [connection_private_notes(:group_2_student_1)],
    Connection::PrivateNote.on_group(groups(:group_2))
  end
  
  def test_new_for
    note = Connection::PrivateNote.new_for(
      groups(:group_2), users(:student_2), {:text => 'hello'})
    assert_equal groups(:group_2).membership_of(users(:student_2)), note.connection_membership
    assert_equal 'hello', note.text
    assert note.valid?

    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)
    note = Connection::PrivateNote.new_for(
      groups(:group_2), users(:student_2), {
        :text => 'hello',
        :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    })

    assert_equal groups(:group_2).membership_of(users(:student_2)), note.connection_membership
    assert_equal 'hello', note.text
    assert_false note.valid?

    note = Connection::PrivateNote.new_for(
      groups(:group_3), users(:student_2), {:text => 'hello'})
    assert_nil  note.connection_membership
    assert_equal 'hello', note.text
    assert_false note.valid?
  end
end
