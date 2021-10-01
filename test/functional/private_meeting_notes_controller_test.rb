require_relative './../test_helper.rb'

class PrivateMeetingNotesControllerTest < ActionController::TestCase
  def test_index
    current_user_is :f_mentor
    get :index, params: { meeting_id: meetings(:f_mentor_mkr_student).id, current_occurrence_time: meetings(:f_mentor_mkr_student).start_time}
    assert_equal_unordered [
        connection_private_notes(:meeting_mentor_student_1),
        connection_private_notes(:meeting_mentor_student_4),
        connection_private_notes(:meeting_mentor_student_5),
        connection_private_notes(:meeting_mentor_student_2),
        connection_private_notes(:meeting_mentor_student_3)], assigns(:private_meeting_notes)

    assert_equal meetings(:f_mentor_mkr_student), assigns(:meeting)
  end

  def test_create_success_flash_meeting
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    time = 50.minutes.ago.change(usec: 0)
    meeting = create_meeting(program: program, topic: "Arbit Topic", start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:f_mentor).id, force_non_group_meeting: true)

    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).once
    assert_difference "Scrap.count", 1 do
      assert_difference 'PrivateMeetingNote.count' do
        post :create, xhr: true, params: { meeting_id: meeting.id,
          private_meeting_note: {
            text: "I am a mentor, ha ha ha",
            notify_attendees: true,
            attachment: fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
          }
        }
      end
    end
    assert assigns(:notify_attendees)
    scrap = Scrap.last
    assert_equal "I am a mentor, ha ha ha", scrap.content
    assert_equal "Good unique name shared a note in Arbit Topic", scrap.subject
    assert_equal "test_file.css", scrap.attachment_file_name
  end

  def test_create_success_flash_meeting_with_out_scrap
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    time = 50.minutes.ago.change(usec: 0)
    meeting = create_meeting(program: program, topic: "Arbit Topic", start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:f_mentor).id, force_non_group_meeting: true)

    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).once
    assert_no_difference "Scrap.count" do
      assert_difference 'PrivateMeetingNote.count' do
        post :create, xhr: true, params: { meeting_id: meeting.id,
          private_meeting_note: {
            text: "I am a mentor, ha ha ha",
            attachment: fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
          }
        }
      end
    end
  end

  def test_create_success_group_meeting
    meeting = meetings(:f_mentor_mkr_student)

    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).once
    assert_difference 'PrivateMeetingNote.count' do
      post :create, xhr: true, params: { meeting_id: meeting.id,
        private_meeting_note: {
          text: "I am a mentor, ha ha ha"
        }
      }
    end
  end

  def test_create_failure_text_empty
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).never
    assert_no_difference 'PrivateMeetingNote.count' do
      post :create, xhr: true, params: { meeting_id: meetings(:f_mentor_mkr_student).id, private_meeting_note: { text: '' } }
    end
    assert assigns(:private_meeting_note).errors[:text]
  end

  def test_create_failure_max_attachment_size
    current_user_is :f_mentor

    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).never
    assert_no_difference 'PrivateMeetingNote.count' do
      post :create, xhr: true, params: { meeting_id: meetings(:f_mentor_mkr_student).id,
      private_meeting_note: {
        text: "Nice text",
        attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      }}
    end

    assert_blank assigns(:private_meeting_note).errors[:text]
    assert assigns(:private_meeting_note).errors[:attachment]
  end

  def test_create_failure_attachment_type_unsupported
    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).never
    assert_no_difference 'PrivateMeetingNote.count' do
      post :create, xhr: true, params: { meeting_id: meetings(:f_mentor_mkr_student).id,
      private_meeting_note: {
        text: "Nice text",
        attachment: fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')
      }}
    end

    assert_blank assigns(:private_meeting_note).errors[:text]
    assert assigns(:private_meeting_note).errors[:attachment]
  end

  def test_create_failure_attachment_type_big
    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).never
    assert_no_difference 'PrivateMeetingNote.count' do
      post :create, xhr: true, params: { meeting_id: meetings(:f_mentor_mkr_student).id,
      private_meeting_note: {
        text: "Nice text",
        attachment: fixture_file_upload(File.join('files', 'TEST.JPG'), 'image/jpeg')
      }}
    end

    assert_blank assigns(:private_meeting_note).errors[:text]
    assert assigns(:private_meeting_note).errors[:attachment]
  end

  def test_create_failure_attachment_with_virus
    current_user_is :f_mentor

    PrivateMeetingNote.any_instance.expects(:save).at_least(1).raises(VirusError)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_NOTES).never
    assert_no_difference 'PrivateMeetingNote.count' do
      post :create, xhr: true, params: { meeting_id: meetings(:f_mentor_mkr_student).id,
      private_meeting_note: {
        text: "Nice text",
        attachment:  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      }
    }
    end

    assert_equal "Our security system has detected the presence of a virus in the attachment.", assigns(:error_message)
  end

  def test_update_success
    current_user_is :not_requestable_mentor

    put :update, xhr: true, params: { meeting_id: meetings(:student_2_not_req_mentor).id,
      id: connection_private_notes(:meeting_not_req_mentor_student_1).id,
      private_meeting_note: {
        text: "New text"
      }
    }

    assert assigns(:private_meeting_note).valid?
  end

  def test_update_failure_for_text_should_not_replace_attachment
    current_user_is :not_requestable_mentor

    connection_private_notes(:meeting_not_req_mentor_student_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:meeting_not_req_mentor_student_1).save!
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?

    put :update, xhr: true, params: { meeting_id: meetings(:student_2_not_req_mentor).id,
      id: connection_private_notes(:meeting_not_req_mentor_student_1).id,
      private_meeting_note: {
        text: "",
        attachment: nil
      }
    }

    assert_false assigns(:private_meeting_note).valid?

    # Old attachment should be intact.
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?
  end

  def test_update_failure_for_attachment
    current_user_is :not_requestable_mentor

    connection_private_notes(:meeting_not_req_mentor_student_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:meeting_not_req_mentor_student_1).save!
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?

    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)
    put :update, xhr: true, params: {
      meeting_id: meetings(:student_2_not_req_mentor).id,
      id: connection_private_notes(:meeting_not_req_mentor_student_1).id,
      private_meeting_note: {
        text: "Proper text",
        attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      }}

    assert assigns(:private_meeting_note).errors.any?

    # Old attachment should be intact.
    connection_private_notes(:meeting_not_req_mentor_student_1).reload
    assert connection_private_notes(:meeting_not_req_mentor_student_1).attachment?
    assert_equal 'some_file.txt', connection_private_notes(:meeting_not_req_mentor_student_1).attachment_file_name
  end

  def test_update_failure_for_attachment_unsupported
    current_user_is :not_requestable_mentor

    connection_private_notes(:meeting_not_req_mentor_student_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:meeting_not_req_mentor_student_1).save!
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?

    put :update, xhr: true, params: {
      meeting_id: meetings(:student_2_not_req_mentor).id,
      id: connection_private_notes(:meeting_not_req_mentor_student_1).id,
      private_meeting_note: {
        text: "Proper text",
        attachment: fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')
      }
    }

    assert assigns(:private_meeting_note).errors.any?

    # Old attachment should be intact.
    connection_private_notes(:meeting_not_req_mentor_student_1).reload
    assert connection_private_notes(:meeting_not_req_mentor_student_1).attachment?
    assert_equal 'some_file.txt', connection_private_notes(:meeting_not_req_mentor_student_1).attachment_file_name
  end

  def test_update_remove_attachment_success
    current_user_is :not_requestable_mentor

    private_meeting_note = connection_private_notes(:meeting_not_req_mentor_student_1)
    private_meeting_note.attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    private_meeting_note.save!
    assert private_meeting_note.reload.attachment?

    put :update, xhr: true, params: {
      meeting_id: meetings(:student_2_not_req_mentor).id,
      id: private_meeting_note.id,
      private_meeting_note: {
        text: "Proper text"
      },
      remove_attachment: true
    }

    # No errors.
    assert assigns(:private_meeting_note).errors.empty?
    private_meeting_note = PrivateMeetingNote.find(private_meeting_note.id)
    assert_false private_meeting_note.reload.attachment?
  end

  def test_update_remove_attachment_and_add_another_success
    current_user_is :not_requestable_mentor

    connection_private_notes(:meeting_not_req_mentor_student_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:meeting_not_req_mentor_student_1).save!
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?

    put :update, xhr: true, params: {
      meeting_id: meetings(:student_2_not_req_mentor).id,
      id: connection_private_notes(:meeting_not_req_mentor_student_1).id,
      private_meeting_note: {
        text: "Proper text",
        attachment: fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
      },
      remove_attachment: true
    }

    # No errors.
    assert assigns(:private_meeting_note).errors.empty?
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?
    assert_equal 'test_file.css', connection_private_notes(:meeting_not_req_mentor_student_1).attachment_file_name
  end

  def test_update_remove_attachment_failure
    current_user_is :not_requestable_mentor

    connection_private_notes(:meeting_not_req_mentor_student_1).attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    connection_private_notes(:meeting_not_req_mentor_student_1).save!
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?

    put :update, xhr: true, params: {
      meeting_id: meetings(:student_2_not_req_mentor).id,
      id: connection_private_notes(:meeting_not_req_mentor_student_1).id,
      private_meeting_note: {
        text: ""
      },
      remove_attachment: true
    }


    assert assigns(:private_meeting_note).errors.any?
    assert connection_private_notes(:meeting_not_req_mentor_student_1).reload.attachment?
    assert_equal 'some_file.txt', connection_private_notes(:meeting_not_req_mentor_student_1).attachment_file_name
  end

  def test_update_remove_attachment_failure_with_new_attachment
    current_user_is :not_requestable_mentor

    private_meeting_note = connection_private_notes(:meeting_not_req_mentor_student_1)

    private_meeting_note.attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    private_meeting_note.save!
    assert private_meeting_note.reload.attachment?

    stub_paperclip_size(AttachmentSize::END_USER_ATTACHMENT_SIZE + 1)

    put :update, xhr: true, params: {
      meeting_id: meetings(:student_2_not_req_mentor).id,
      id: private_meeting_note.id,
      private_meeting_note: {
        text: "Hello",
        attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      },
      remove_attachment: true
    }

    private_meeting_note = PrivateMeetingNote.find(private_meeting_note.id)
    assert assigns(:private_meeting_note).errors.any?
    assert_false private_meeting_note.attachment?
    assert_nil private_meeting_note.attachment_file_name
  end

  def test_update_failure_attachment_with_virus
    current_user_is :not_requestable_mentor

    private_meeting_note = connection_private_notes(:meeting_not_req_mentor_student_1)

    private_meeting_note.attachment =
      fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    private_meeting_note.save!
    assert private_meeting_note.reload.attachment?

    PrivateMeetingNote.any_instance.expects(:save).at_least(1).raises(VirusError)
    put :update, xhr: true, params: { meeting_id: meetings(:student_2_not_req_mentor).id,
      id: private_meeting_note.id,
      private_meeting_note: {
        text: "Hello",
        attachment:  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      },
      remove_attachment: true
    }

    assert_equal "Our security system has detected the presence of a virus in the attachment.", assigns(:error_message)
  end

  def test_destroy
    current_user_is :not_requestable_mentor

    assert_difference 'PrivateMeetingNote.count', -1 do
      delete :destroy, params: { meeting_id: meetings(:student_2_not_req_mentor).id,
        id: connection_private_notes(:meeting_not_req_mentor_student_1).id
      }
    end

    assert_redirected_to meeting_private_meeting_notes_path(meetings(:student_2_not_req_mentor))
  end

end