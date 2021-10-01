require_relative './../test_helper.rb'

class AnnouncementsControllerTest < ActionController::TestCase
  def setup
    super
    current_program_is :albers
  end

  def test_announcement_update_with_virus
    current_user_is :f_admin

    ann = create_announcement(:title => "Hello", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    Announcement.any_instance.expects(:save).at_least(1).raises(VirusError)
    assert_no_difference('Announcement.count') do
      put :update, params: { :id =>ann.id , :announcement => {
        :title => "abcde",
        :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'),
        :recipient_role_names => [RoleConstants::MENTOR_NAME]
      }}
    end
    assert_redirected_to edit_announcement_path(ann)
    assert_equal "Our security system has detected the presence of a virus in the attachment.", flash[:error]
  end

  def test_send_test_emails
    current_user_is :f_admin

    assert_emails(1) do
      post :send_test_emails, xhr: true, params: { :test_announcement => {:title => "Ann Title", :body => "Ann body",
        :notification_list_for_test_email => "abcdef@ghi.com"}}
    end
    assert_equal "abcdef@ghi.com", assigns(:email_list)
  end

  def test_send_test_emails_with_no_title
    current_user_is :f_admin
    assert_emails(1) do
      post :send_test_emails, xhr: true, params: { :test_announcement => {:title => "", :body => "Ann body",
        :notification_list_for_test_email => "abcdef@ghi.com"}}
    end
    assert_equal "abcdef@ghi.com", assigns(:email_list)
  end

  def test_send_test_emails_with_no_email_list
    current_user_is :f_admin

    assert_no_emails do
      post :send_test_emails, xhr: true, params: { :test_announcement => {:title => "Ann Title", :body => "Ann body",
        :notification_list_for_test_email => ""}, :id => announcements(:assemble)}
    end
    assert_equal "", assigns(:email_list)
  end

  def test_send_test_emails_for_existing_announcement
    current_user_is :f_admin

    ann = announcements(:assemble)
    assert_emails(1) do
      post :send_test_emails, xhr: true, params: { :test_announcement => {:title => "Ann Title", :body => "Ann body",
        :notification_list_for_test_email => "abcdef@ghi.com"}, :id => announcements(:assemble)}
    end
    assert_equal "abcdef@ghi.com", assigns(:email_list)
  end

  def test_add_announcement
    current_user_is :f_admin
    announcement = announcements(:assemble)
    assert !announcement.attachment?

    # Add an attachment
    assert_no_difference('RecentActivity.count') do
      put :update, params: { id: announcement.id,
        announcement: {
          attachment:  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'),
          email_notification: UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
        }
      }
    end

    assert announcement.reload.attachment?
    assert_equal UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, announcement.email_notification
  end

  def test_announcement_create_with_file_type_unsupported
    current_user_is :f_admin

    ann = create_announcement(:title => "Hello", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    assert_no_difference('Announcement.count') do
      put :update, params: { :id => ann.id , :announcement => {
        :title => "abcde",
        :attachment =>  fixture_file_upload(File.join("files", "test_php.php"), "application/x-php"),
        :recipient_role_names => [RoleConstants::MENTOR_NAME]
      }}
    end
    assert_equal flash[:error], "Attachment content type is restricted and Attachment file name is invalid"
  end

  def test_announcement_jar_file_type_unsupported
    current_user_is :f_admin

    ann = create_announcement(:title => "Hello", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    assert_no_difference('Announcement.count') do
      put :update, params: { :id => ann.id , :announcement => {
        :title => "abcde",
        :attachment =>  fixture_file_upload(File.join("files", "helloworld.jar")),
        :recipient_role_names => [RoleConstants::MENTOR_NAME]
      }}
    end
    assert_equal flash[:error], "Attachment content type is restricted and Attachment file name is invalid"
  end

  def test_remove_attachment
    current_user_is :f_admin
    ann = announcements(:assemble)
    ann.attachment = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    ann.save!
    ann.reload
    assert ann.attachment?

    # Remove attachment
    assert_no_difference('RecentActivity.count') do
      put :update, params: { :id => ann.id, :remove_attachment => true,
        :announcement => {:email_notification => UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE}
      }
    end

    ann = Announcement.find(ann.id)
    assert !ann.reload.attachment?
  end

  def test_update_announcement_with_notification
    current_user_is :f_admin
    ann = announcements(:assemble)
    dj_mock = mock()
    Announcement.expects(:delay).returns(dj_mock).once
    dj_mock.expects(:notify_users).with(ann.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, 2, true)
    Push::Base.expects(:queued_notify).with(PushNotification::Type::ANNOUNCEMENT_UPDATE, ann).once

    # Some update
    assert_no_difference('RecentActivity.count') do
      put :update, params: { :id => ann.id,
        :announcement => {:title => "New title", :email_notification => UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE}
      }
    end
  end

  def test_update_announcement_with_notification_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    ann = announcements(:assemble)
    dj_mock = mock()
    Announcement.expects(:delay).returns(dj_mock).once
    dj_mock.expects(:notify_users).with(ann.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, 2, true)
    Push::Base.expects(:queued_notify).with(PushNotification::Type::ANNOUNCEMENT_UPDATE, ann).once
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    # Some update
    assert_no_difference "VulnerableContentLog.count" do
      assert_no_difference('RecentActivity.count') do
        put :update, params: { :id => ann.id,
          :announcement => {:title => "New title", :body => "New Body <script>alert(10);</script>", :email_notification => UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE}
        }
      end
    end
  end

  def test_update_announcement_with_notification_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    ann = announcements(:assemble)
    dj_mock = mock()
    Announcement.expects(:delay).returns(dj_mock).once
    dj_mock.expects(:notify_users).with(ann.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, 2, false)
    Push::Base.expects(:queued_notify).with(PushNotification::Type::ANNOUNCEMENT_UPDATE, ann).once
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    # Some update
    assert_difference "VulnerableContentLog.count" do
      assert_no_difference('RecentActivity.count') do
        put :update, params: { :id => ann.id,
          :announcement => {:title => "New title", :body => "New Body <script>alert(10);</script>", :email_notification => UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY}
        }
      end
    end
  end

  def test_update_announcement_without_notification
    current_user_is :f_admin
    ann = announcements(:assemble)

    Announcement.any_instance.expects(:send_later).with(:notify_users, ann.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, 2).never

    # Some update
    assert_no_difference('RecentActivity.count') do
      put :update, params: { :id => ann.id,
        :announcement => {:title => "New title", :email_notification => UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND}
      }
    end
  end

  def test_announcement_shows_remove_attachment_if_present
    ann = create_announcement(:title => "Hello", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    assert !ann.attachment?
    current_user_is :f_admin

    get :edit, params: { :id => ann.id}

    assert_response :success

    assert_select "input#post_attachment[type=\"file\"]"

    assert_select "input#remove_attachment[type=\"checkbox\"]", count: 0

    # Update the announcement with an attachment
    assert_no_difference('RecentActivity.count') do
      put :update, params: { :id =>ann.id , :announcement => {:title => "abcde",
        :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
      }
    end
    assert ann.reload.attachment?

    # When there is an attachment, show option to remove it
    get :edit, params: { :id => ann.reload.id}

    assert_response :success
    assert_select "input#remove_attachment[type=\"checkbox\"]"
    assert_select "input#announcement_attachment[type=\"file\"]", count: 0
  end

  def test_should_log_in
    get :index
    assert_redirected_to new_session_path
  end

  def test_should_get_index
    current_user_is :f_admin
    Announcement.destroy_all

    ann_1 = create_announcement(:title => "Hello", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    ann_2 = create_announcement(:title => "How", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    ann_3 = create_announcement(:title => "Are you?", :recipient_role_names => [RoleConstants::MENTOR_NAME])
    ann_4 = create_announcement(:title => "Are you?", :recipient_role_names => [RoleConstants::STUDENT_NAME], :status => Announcement::Status::DRAFTED)
    # The user, who is a member of the program should get the page
    get :index
    assert_response :success
    assert_equal [ann_3, ann_2, ann_1], assigns(:published_announcements)
    assert_equal [ann_4], assigns(:drafted_announcements)
    assert_select 'div.pagination_box'
  end

  def test_index_restricts_the_announcement_according_to_the_user
    Announcement.destroy_all
    ann_1 = create_announcement(:title => "Hello", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    ann_2 = create_announcement(:title => "How", :recipient_role_names => [RoleConstants::STUDENT_NAME])
    create_announcement(:title => "Are you?", :recipient_role_names => [RoleConstants::MENTOR_NAME])
    current_user_is :f_student

    get :index
    assert_response :success
    assert_equal_unordered [ann_1, ann_2], assigns(:published_announcements)
    assert_select 'div.pagination_box'
  end

  def test_should_get_index_only_non_expired_published_announcements_for_non_admins
    current_user_is :f_mentor
    # The user, who is a member of the program should get the page
    get :index
    assert_response :success
    assert_equal [announcements(:big_announcement), announcements(:assemble)], assigns(:published_announcements)
    assert_select 'div.pagination_box'
  end

  def test_should_get_index_all_announcements_for_admins
    current_user_is :f_admin
    # The user, who is a member of the program should get the page
    get :index
    assert_response :success
    assert_equal [announcements(:expired_announcement), announcements(:big_announcement), announcements(:assemble)], assigns(:published_announcements)
    assert_equal [announcements(:drafted_announcement)], assigns(:drafted_announcements)
    assert_select 'div.pagination_box'
  end

  def test_should_get_index_all_with_announcement_in_bold_underline_italic
    current_user_is :f_mentor
    announcements(:assemble).update_attributes(body: "Test <em>italic</em><u>underline</u><strong>Bold</strong>")
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    get :index
    assert_response :success
    assert_match "Test <em>italic</em><u>underline</u><strong>Bold</strong>", response.body
  end

  #
  # New announcement
  #
  def test_should_get_new
    current_user_is :f_admin
    get :new
    assert_response :success
    assert_select 'html'
    assert_match AnnouncementNotification.mailer_attributes[:uid], response.body
  end

  def test_announcement_with_virus
    current_user_is :f_admin

    Announcement.any_instance.expects(:save).at_least(1).raises(VirusError)
    assert_no_difference('Announcement.count') do
      post :create, params: { :announcement => {:title => "Hello"}}
    end
    assert_redirected_to new_announcement_path
    assert_equal "Our security system has detected the presence of a virus in the attachment.", flash[:error]
  end

  # Creation/Publish of announcement
  def test_should_create_published_announcement
    role = create_role(:name => 'managers')
    manager = create_user(:role_names => ['managers'])
    current_program_is :albers
    current_user_is manager
    add_role_permission(role, 'manage_announcements')
    dj_mock = mock()
    Announcement.expects(:delay).returns(dj_mock).at_least(0)
    push_mock = mock()
    Push::Base.expects(:delay).returns(push_mock).once
    push_mock.expects(:notify).once
    dj_mock.expects(:notify_users)

    assert_difference('Announcement.count') do
      post :create, params: { :announcement => {:title => "Hello", :recipient_role_names => [RoleConstants::STUDENT_NAME], :email_notification => UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE }}
    end

    assert_equal "The announcement has been published.", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], assigns(:announcement).recipient_role_names
    assert_redirected_to announcement_path(assigns(:announcement))
  end

  def test_should_create_published_announcement_with_vulnerable_content_with_version_v1
    role = create_role(:name => 'managers')
    manager = create_user(:role_names => ['managers'])
    current_program_is :albers
    current_user_is manager
    add_role_permission(role, 'manage_announcements')
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_difference('Announcement.count') do
        post :create, params: { :announcement => {:title => "Hello", :recipient_role_names => [RoleConstants::STUDENT_NAME], :body => "This is an announcement<script>alert(10);</script>" }}
      end
    end

    assert_equal "The announcement has been published.", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], assigns(:announcement).recipient_role_names
    assert_redirected_to announcement_path(assigns(:announcement))
  end

  def test_should_create_published_announcement_with_vulnerable_content_with_version_v2
    role = create_role(:name => 'managers')
    manager = create_user(:role_names => ['managers', 'admin'])
    current_program_is :albers
    current_user_is manager
    add_role_permission(role, 'manage_announcements')
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_difference('Announcement.count') do
        post :create, params: { :announcement => {:title => "Hello", :recipient_role_names => [RoleConstants::STUDENT_NAME], :body => "This is an announcement<script>alert(10);</script>" }}
      end
    end

    assert_equal "The announcement has been published.", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], assigns(:announcement).recipient_role_names
    assert_redirected_to announcement_path(assigns(:announcement))
  end

  # Creation/Drafting of announcement
  def test_should_create_drafted_announcement
    role = create_role(:name => 'managers')
    manager = create_user(:role_names => ['managers'])
    current_program_is :albers
    current_user_is manager
    add_role_permission(role, 'manage_announcements')

    assert_difference('Announcement.count') do
      post :create, params: { :announcement => {:title => "Hello", :recipient_role_names => [RoleConstants::STUDENT_NAME], :status => Announcement::Status::DRAFTED }}
    end

    assert_equal "The announcement has been saved.", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], assigns(:announcement).recipient_role_names
    assert_redirected_to announcement_path(assigns(:announcement))
  end

  #
  # Show Announcement
  #
  def test_should_show_announcement
    current_user_is :f_admin
    get :show, params: { :id => announcements(:assemble).id}
    assert_response :success
    assert_equal announcements(:assemble), assigns(:announcement)
  end

  #
  # Non-admin show
  #
  def test_should_show_only_published_announcement_to_non_admin
    current_user_is :f_mentor
    get :show, params: { :id => announcements(:assemble).id}
    assert_response :success
    assert_equal announcements(:assemble), assigns(:announcement)

    assert_permission_denied do
      get :show, params: { :id => announcements(:drafted_announcement).id}
    end
  end

  # Adding italics & underline in announcements
  def test_should_show_announcement_with_italics_or_underline
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    announcement = announcements(:assemble)
    announcement.update_attributes(body: "TEST <em>italic</em> <u>Underline</u>")
    get :show, params: { :id => announcement.id}
    assert_response :success
    assert_match "TEST <em>italic</em> <u>Underline</u>", response.body
  end

  #
  # Edit Announcement
  #
  def test_should_get_edit
    current_user_is :f_admin
    get :edit, params: { :id => announcements(:assemble).id}
    assert_response :success
    assert_match AnnouncementUpdateNotification.mailer_attributes[:uid], response.body
    assert_equal announcements(:assemble), assigns(:announcement)
  end

  #
  # Update Announcement
  #
  def test_should_update_announcement
    current_user_is :f_admin
    announcement = announcements(:assemble)
    drafted_announcement = announcements(:drafted_announcement)

    # Successful update
    assert announcement.title != "abcde"
    assert_no_difference('RecentActivity.count') do
      put :update, params: { :id =>announcement.id , :announcement => {:title => "abcde"}}
    end
    assert_equal "The announcement has been updated.", flash[:notice]
    assert_redirected_to announcement_path(assigns(:announcement))
    announcement.reload
    assert_equal "abcde", announcement.title

    # Failure update
    assert_no_difference('RecentActivity.count') do
      put :update, params: { :id =>announcement.id , :announcement => {:title => ""}}
    end
    assert_template 'edit'
    announcement.reload
    assert_equal "abcde", announcement.title

    #Publishing a drafted Announcement
    assert drafted_announcement.drafted?
    assert_difference('RecentActivity.count') do
      put :update, params: { :id =>drafted_announcement.id , :announcement => {:status => Announcement::Status::PUBLISHED}}
    end
    assert_redirected_to announcement_path(drafted_announcement)
    drafted_announcement.reload
    assert_equal "The announcement has been published.", flash[:notice]
    assert drafted_announcement.published?
  end

  def test_should_destroy_announcement
    announcement_id = announcements(:assemble).id
    current_user_is :f_admin
    assert_difference 'Announcement.count', -1 do
      post :destroy, params: { :id => announcement_id}
    end
    assert_nil Announcement.find_by(id: announcement_id)
  end

  def test_mark_viewed_for_mentor
    announcement_id = announcements(:assemble).id
    current_user_is :not_requestable_mentor
    assert_no_difference 'ViewedObject.count' do
      get :mark_viewed, xhr: true, params: { :id => announcement_id}
    end
    assert_equal 1, assigns(:unviewed_announcements_count)
    announcement_id = announcements(:big_announcement).id
    assert_difference 'ViewedObject.count', 1 do
      get :mark_viewed, xhr: true, params: { :id => announcement_id}
    end
    assert_equal 0, assigns(:unviewed_announcements_count)
  end

  def test_mark_viewed_for_student
    announcement_id = announcements(:big_announcement).id
    current_user_is :drafted_group_user
    assert_no_difference 'ViewedObject.count' do
      get :mark_viewed, xhr: true, params: { :id => announcement_id}
    end
    assert_equal 1, assigns(:unviewed_announcements_count)
    announcement_id = announcements(:assemble).id
    assert_difference 'ViewedObject.count', 1 do
      get :mark_viewed, xhr: true, params: { :id => announcement_id}
    end
    assert_equal 0, assigns(:unviewed_announcements_count)
  end

end
