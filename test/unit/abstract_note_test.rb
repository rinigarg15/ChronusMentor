require_relative './../test_helper.rb'

class AbstractNoteTest < ActiveSupport::TestCase
  def test_validate_text
    n = Connection::PrivateNote.new
    n.valid?
    assert n.errors[:text]
  end

  def test_validate_attachment_on_create
    note = Connection::PrivateNote.new(
      :connection_membership => fetch_connection_membership(:mentor, groups(:mygroup)),
      :text => "Hey, my note!",
      :attachment_file_name => 'some_file.txt',
      :attachment_file_size => 21.megabytes
    )
 
    assert_false note.valid?
    assert note.errors[:attachment]
    note = nil
    note = Connection::PrivateNote.new(
      :connection_membership => fetch_connection_membership(:mentor, groups(:mygroup)),
      :text => "Hey, my note!",
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    )

    assert note.valid?
  end

  def test_file_attachment_type_not_recognized
    note = Connection::PrivateNote.new(
      :connection_membership => fetch_connection_membership(:mentor, groups(:mygroup)),
      :text => "Hey, my note!",
      :attachment => fixture_file_upload(File.join("files", "test_php.php"), "application/x-php")
    )
    assert_false note.valid?
    
  end

  def test_file_attachment_size_too_big
    note = Connection::PrivateNote.new(
      :connection_membership => fetch_connection_membership(:mentor, groups(:mygroup)),
      :text => "Hey, my note!",
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    )
    note.attachment_file_size = 21.megabytes
    assert_false note.valid?
    
  end
end