require_relative './../../test_helper.rb'

class Connection::PrivateNotesControllerTest < ActionController::TestCase
  def test_index_permission_denied
    current_program_is :albers
    current_member_is :f_admin
    @request.session[:work_on_behalf_user] = users(:f_mentor).id
    @request.session[:work_on_behalf_member] = users(:f_mentor).member_id

    assert_permission_denied do
      get :index, params: { :group_id => groups(:mygroup).id}
    end
  end

  def test_index_permission_denied_private_journal_disabled    
    current_user_is :f_mentor
    programs(:albers).update_attribute(:allow_private_journals, false)
    
    assert_permission_denied do
      get :index, params: { :group_id => groups(:mygroup).id}
    end
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    assert_permission_denied do
      post :create, params: { :group_id => groups(:mygroup).id, :connection_private_note => {:text => "I am a mentor, ha ha ha"}}
    end

    id = Connection::PrivateNote.last
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    assert_permission_denied do
      put :update, params: { :id => id, :group_id => groups(:mygroup).id, :connection_private_note => {:text => "I am a mentor, ha ha ha"}}
    end

    assert_permission_denied do
      post :destroy, params: { :id => id, :group_id => groups(:mygroup).id}
    end
  end

  def test_index
    current_user_is :f_mentor

    get :index, params: { :group_id => groups(:mygroup).id}
    assert_equal :private_notes, assigns(:mentoring_context)

    assert_template 'index'
    assert_equal_unordered [
        connection_private_notes(:mygroup_mentor_1),
        connection_private_notes(:mygroup_mentor_2)],
      assigns(:private_notes)
    assert_equal groups(:mygroup), assigns(:group)
  end
  
  def test_create_success
    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).once
    assert_difference 'Connection::PrivateNote.count' do
      post :create, params: { :group_id => groups(:mygroup).id,
        :connection_private_note => {
          :text => "I am a mentor, ha ha ha"
        }
      }
    end

    assert_redirected_to group_connection_private_notes_path(groups(:mygroup))
  end

  def test_create_failure_text_empty
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    assert_no_difference 'Connection::PrivateNote.count' do
      post :create, params: { :group_id => groups(:mygroup).id,
        :connection_private_note => {}
      }
    end

    assert_redirected_to group_connection_private_notes_path(groups(:mygroup))
    assert assigns(:private_note)
    assert assigns(:private_note).errors[:text]
  end

  def test_create_failure_max_attachment_size
    current_user_is :f_mentor

    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    assert_no_difference 'Connection::PrivateNote.count' do
      post :create, params: { :group_id => groups(:mygroup).id,
      :connection_private_note => {
        :text => "Nice text",
        :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      }}
    end

    assert_redirected_to group_connection_private_notes_path(groups(:mygroup))
    assert_blank assigns(:private_note).errors[:text]
    assert assigns(:private_note).errors[:attachment]
  end

  def test_create_failure_attachment_type_unsupported
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    assert_no_difference 'Connection::PrivateNote.count' do
      post :create, params: { :group_id => groups(:mygroup).id,
      :connection_private_note => {
        :text => "Nice text",
        :attachment => fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')
      }}
    end

    assert_redirected_to group_connection_private_notes_path(groups(:mygroup))
    assert_blank assigns(:private_note).errors[:text]
    assert_equal "Attachment content type is restricted and Attachment file name is invalid", flash[:error]
    assert assigns(:private_note).errors[:attachment]
  end

  def test_create_failure_attachment_type_big
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    assert_no_difference 'Connection::PrivateNote.count' do
      post :create, params: { :group_id => groups(:mygroup).id,
      :connection_private_note => {
        :text => "Nice text",
        :attachment => fixture_file_upload(File.join('files', 'TEST.JPG'), 'image/jpeg')
      }}
    end

    assert_redirected_to group_connection_private_notes_path(groups(:mygroup))
    assert_blank assigns(:private_note).errors[:text]
    assert assigns(:private_note).errors[:attachment]
  end

  def test_update_success
    current_user_is :not_requestable_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).once
    put :update, xhr: true, params: { :group_id => groups(:group_3).id,
      :id => connection_private_notes(:group_3_mentor_1).id,
      :connection_private_note => {
        :text => "New text"
      }
    }

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "note_#{connection_private_notes(:group_3_mentor_1).id}",
      :updated => 1)
    assert assigns(:private_note).valid?
  end

  def test_update_failure_for_text
    current_user_is :not_requestable_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    put :update, xhr: true, params: { :group_id => groups(:group_3).id,
      :id => connection_private_notes(:group_3_mentor_1).id,
      :connection_private_note => {
        :text => ""
      }
    }

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "edit_note_#{connection_private_notes(:group_3_mentor_1).id}",
      :updated => 1)
    assert_false assigns(:private_note).valid?
  end

  def test_update_failure_for_text_should_not_replace_attachment
    current_user_is :not_requestable_mentor

    connection_private_notes(:group_3_mentor_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:group_3_mentor_1).save!
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    put :update, xhr: true, params: { :group_id => groups(:group_3).id,
      :id => connection_private_notes(:group_3_mentor_1).id,
      :connection_private_note => {
        :text => "",
        :attachment => nil
      }
    }

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "edit_note_#{connection_private_notes(:group_3_mentor_1).id}",
      :updated => 1)
    assert_false assigns(:private_note).valid?

    # Old attachment should be intact.
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?
  end

  def test_update_failure_for_attachment
    current_user_is :not_requestable_mentor

    connection_private_notes(:group_3_mentor_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:group_3_mentor_1).save!
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?

    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    put :update, xhr: true, params: {
      :group_id => groups(:group_3).id,
      :id => connection_private_notes(:group_3_mentor_1).id,
      :connection_private_note => {
        :text => "Proper text",
        :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      }}

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "edit_note_#{connection_private_notes(:group_3_mentor_1).id}",
      :updated => 1)

    assert assigns(:private_note).errors.any?

    # Old attachment should be intact.
    connection_private_notes(:group_3_mentor_1).reload
    assert connection_private_notes(:group_3_mentor_1).attachment?
    assert_equal 'some_file.txt', connection_private_notes(:group_3_mentor_1).attachment_file_name
  end

  def test_update_failure_for_attachment_unsupported
    current_user_is :not_requestable_mentor

    connection_private_notes(:group_3_mentor_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:group_3_mentor_1).save!
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    put :update, xhr: true, params: {
      :group_id => groups(:group_3).id,
      :id => connection_private_notes(:group_3_mentor_1).id,
      :connection_private_note => {
        :text => "Proper text",
        :attachment => fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')
      }}

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "edit_note_#{connection_private_notes(:group_3_mentor_1).id}",
      :updated => 1)

    assert assigns(:private_note).errors.any?

    # Old attachment should be intact.
    connection_private_notes(:group_3_mentor_1).reload
    assert connection_private_notes(:group_3_mentor_1).attachment?
    assert_equal 'some_file.txt', connection_private_notes(:group_3_mentor_1).attachment_file_name
  end

  def test_update_remove_attachment_success
    current_user_is :not_requestable_mentor

    connection_private_note = connection_private_notes(:group_3_mentor_1)
    connection_private_note.attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_note.save!
    assert connection_private_note.reload.attachment?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).once
    put :update, xhr: true, params: {
      :group_id => groups(:group_3).id,
      :id => connection_private_note.id,
      :connection_private_note => {
        :text => "Proper text"
      },
      :remove_attachment => true
    }

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "note_#{connection_private_note.id}",
      :updated => 1)

    # No errors.
    assert assigns(:private_note).errors.empty?
    connection_private_note = Connection::PrivateNote.find(connection_private_note.id)
    assert_false connection_private_note.reload.attachment?
  end

  def test_update_remove_attachment_and_add_another_success
    current_user_is :not_requestable_mentor

    connection_private_notes(:group_3_mentor_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:group_3_mentor_1).save!
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).once
    put :update, xhr: true, params: {
      :group_id => groups(:group_3).id,
      :id => connection_private_notes(:group_3_mentor_1).id,
      :connection_private_note => {
        :text => "Proper text",
        :attachment => fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
      },
      :remove_attachment => true
    }

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "note_#{connection_private_notes(:group_3_mentor_1).id}",
      :updated => 1)

    # No errors.
    assert assigns(:private_note).errors.empty?
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?
    assert_equal 'test_file.css', connection_private_notes(:group_3_mentor_1).attachment_file_name
  end

  def test_update_remove_attachment_failure
    current_user_is :not_requestable_mentor

    connection_private_notes(:group_3_mentor_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:group_3_mentor_1).save!
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    put :update, xhr: true, params: {
      :group_id => groups(:group_3).id,
      :id => connection_private_notes(:group_3_mentor_1).id,
      :connection_private_note => {
        :text => ""
      },
      :remove_attachment => true
    }

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "edit_note_#{connection_private_notes(:group_3_mentor_1).id}",
      :updated => 1)

    assert assigns(:private_note).errors.any?
    assert connection_private_notes(:group_3_mentor_1).reload.attachment?
    assert_equal 'some_file.txt', connection_private_notes(:group_3_mentor_1).attachment_file_name
  end

  def test_update_remove_attachment_failure_with_new_attachment
    current_user_is :not_requestable_mentor

    connection_private_note = connection_private_notes(:group_3_mentor_1)
    
    connection_private_note.attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_note.save!
    assert connection_private_note.reload.attachment?

    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL).never
    put :update, xhr: true, params: {
      :group_id => groups(:group_3).id,
      :id => connection_private_note.id,
      :connection_private_note => {
        :text => "Hello",
        :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      },
      :remove_attachment => true
    }

    assert_redirected_to group_connection_private_notes_path(groups(:group_3),
      :anchor => "edit_note_#{connection_private_note.id}",
      :updated => 1)

    connection_private_note = Connection::PrivateNote.find(connection_private_note.id)
    assert assigns(:private_note).errors.any?
    assert_false connection_private_note.attachment?
    assert_nil connection_private_note.attachment_file_name
  end
  
  def test_destroy
    current_user_is :not_requestable_mentor

    assert_difference 'Connection::PrivateNote.count', -1 do
      delete :destroy, params: { :group_id => groups(:group_3).id,
        :id => connection_private_notes(:group_3_mentor_1).id
      }
    end

    assert_redirected_to group_connection_private_notes_path(groups(:group_3))   
  end
end
