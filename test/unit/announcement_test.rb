require_relative './../test_helper.rb'

class AnnouncementTest < ActiveSupport::TestCase

  # Announcement belongs to both program and user
  def test_announcement_belongs_to_program_and_user
    assert_nothing_raised do
      @announcement = create_announcement(:recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    end
    assert_equal programs(:albers), @announcement.program
    assert_equal users(:f_admin), @announcement.admin
    assert_nil @announcement.expiration_date

    assert !users(:f_student).can_manage_announcements?

    # User should be have privileges and recipient roles cannot be empty
    announcement_2 = Announcement.new(:title => "Hello", :program => programs(:albers),:admin => users(:f_student))
    assert !announcement_2.valid?
    assert_equal 2, announcement_2.errors.size
    assert_equal ["does not have necessary privileges to create an announcement"], announcement_2.errors[:admin]
  end

  def test_announcement_validations
    assert_multiple_errors([{:field => :program}, {:field => :admin}, {:field => :title}]) do
      Announcement.create!
    end
    assert_multiple_errors([{:field => :program}, {:field => :admin}]) do
      Announcement.create!(:status => Announcement::Status::DRAFTED)
    end
  end

  def test_email_notification_validation
    announcement = announcements(:assemble)

    UserConstants::DigestV2Setting::ProgramUpdates.for_announcement.each do |notification_setting|
      announcement.email_notification = notification_setting
      assert announcement.valid?
    end

    (UserConstants::DigestV2Setting::ProgramUpdates.all - UserConstants::DigestV2Setting::ProgramUpdates.for_announcement).each do |notification_setting|
      announcement.email_notification = notification_setting
      assert_false announcement.valid?
    end
  end

  def test_recipient_roles_cannot_be_empty_for_a_published_announcement
    assert_no_difference "Announcement.count" do
      assert_raise ActiveRecord::RecordInvalid, "Validation failed: Recipient roles can't be blank" do
        Announcement.create!(:title => "Hello", :program => programs(:albers), :admin => users(:f_admin))
      end
    end
  end

  def test_recipient_roles_can_be_empty_for_a_drafted_announcement
    assert_difference "Announcement.count" do
      assert_nothing_raised do
        Announcement.create!({:title => "Hello", :program => programs(:albers), :admin => users(:f_admin), :status => Announcement::Status::DRAFTED})
      end
    end
  end

  # Recipient scopes for announcements
  def test_announcement_recipient_scopes
    Announcement.destroy_all
    to_all = create_announcement(:recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    m_1 = create_announcement(:recipient_role_names => [RoleConstants::MENTOR_NAME])
    m_2 = create_announcement(:recipient_role_names => [RoleConstants::MENTOR_NAME])
    s_1 = create_announcement(:recipient_role_names => [RoleConstants::STUDENT_NAME])
    s_2 = create_announcement(:recipient_role_names => [RoleConstants::STUDENT_NAME])
    s_3 = create_announcement(:recipient_role_names => [RoleConstants::STUDENT_NAME], :expiration_date => 1.day.ago)
    assert_equal [to_all, m_1, m_2], Announcement.for_mentors
    assert_equal [to_all, s_1, s_2, s_3], Announcement.for_students
    assert_equal [to_all, s_1, s_2], Announcement.for_students.not_expired
    assert_equal [m_2, m_1, to_all], Announcement.for_mentors.ordered

    assert_equal [to_all, m_1, m_2, s_1, s_2, s_3], Announcement.for_user(users(:f_admin))
    assert_equal [to_all, m_1, m_2], Announcement.for_user(users(:f_mentor))
    assert_equal [to_all, s_1, s_2, s_3], Announcement.for_user(users(:f_student))
    assert_equal [to_all, m_1, m_2, s_1, s_2, s_3], Announcement.for_user(users(:f_mentor_student))

    # Mentors get privilege to manage announcements.
    add_role_permission(fetch_role(:albers, :mentor), 'manage_announcements')
    assert_equal [to_all, m_1, m_2, s_1, s_2, s_3], Announcement.for_user(users(:f_mentor).reload)
  end

  def test_announcement_status_scopes
    Announcement.destroy_all
    drafted_announcement_1 = create_announcement(:status => Announcement::Status::DRAFTED)
    drafted_announcement_2 = create_announcement(:status => Announcement::Status::DRAFTED)
    published_announcement = create_announcement

    assert_equal [published_announcement], Announcement.published
    assert_equal [drafted_announcement_1, drafted_announcement_2], Announcement.drafted
  end

  def test_announcement_status
    announcement = announcements(:drafted_announcement)
    assert announcement.drafted?

    announcement.update_attributes!(:status => Announcement::Status::PUBLISHED)
    assert announcement.published?
  end

  def test_announcement_with_Attachment_file_name_invalid
    announcement = announcements(:drafted_announcement)
    assert announcement.drafted?

    announcement.update_attributes!(:status => Announcement::Status::PUBLISHED)
    assert announcement.published?
    assert announcement.valid?
    announcement.attachment_file_name = 'some_file.asp'
    assert_false announcement.valid?

    announcement = announcements(:assemble)
    assert announcement.valid?
    announcement.attachment_file_name = 'some_file.htm'
    assert_false announcement.valid?
    announcement.attachment_file_name = 'some_file.html'
    assert_false announcement.valid?
    announcement.attachment_file_name = 'some_file.xht'
    assert_false announcement.valid?
    announcement.attachment_file_name = 'some_file.xhtml'
    assert_false announcement.valid?
  end

  def test_announcement_with_Attachment_file_size_huge
    announcement = announcements(:drafted_announcement)
    assert announcement.drafted?

    announcement.update_attributes!(:status => Announcement::Status::PUBLISHED)
    assert announcement.published?
    assert announcement.valid?
    announcement.attachment_file_name = 'some_file.txt'
    announcement.attachment_file_size = 51.megabytes
    assert_false announcement.valid?
    assert announcement.errors[:attachment_file_size].present?
  end

  def test_recent_activity_is_deleted
    # Create an announcement and hence a recent activity
    assert_difference('RecentActivity.count') do
      @announcement = create_announcement(:recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    end

    assert_difference('RecentActivity.count', -1) do
      @announcement.destroy
    end
  end

  def test_announcement_list
    some_mentor = programs(:albers).mentor_users.first
    some_mentor.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    assert programs(:albers).mentor_users.include?(some_mentor)
    assert programs(:albers).admin_users.include?(some_mentor)

    announcement = create_announcement(:recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    assert_equal_unordered programs(:albers).users, announcement.notification_list
    announcement.recipient_role_names = [RoleConstants::MENTOR_NAME]

    # Users with multiple roles should not repeat.
    uniq_admins_and_mentors = (programs(:albers).admin_users + programs(:albers).mentor_users).uniq
    assert_equal uniq_admins_and_mentors.size, announcement.notification_list.size
    assert_equal_unordered uniq_admins_and_mentors, announcement.notification_list
    announcement.recipient_role_names = [RoleConstants::STUDENT_NAME]
    assert_equal_unordered programs(:albers).admin_users + programs(:albers).student_users,
        announcement.notification_list
  end

  def test_notify_users_send_now
    announcement = create_announcement(:admin => users(:ram), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    # Creation notification
    user_list = User.where(:id => [users(:f_admin), users(:f_mentor)])
    users(:f_mentor).update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    Announcement.any_instance.expects(:notification_list).returns(user_list)
    announcement.program.mailer_template_enable_or_disable(AnnouncementNotification, true)

    # 1 delivery and 1 pending notification, but send_now is true
    assert_difference 'PendingNotification.count', 0 do
      assert_emails 2 do
        Announcement.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version_number, true)
      end
    end
  end

  def test_notify_users
    announcement = create_announcement(:admin => users(:ram), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    # Creation notification
    user_list = User.where(:id => [users(:f_admin), users(:f_mentor)])
    users(:f_mentor).update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    Announcement.any_instance.expects(:notification_list).returns(user_list)
    announcement.program.mailer_template_enable_or_disable(AnnouncementNotification, true)

    # 1 delivery and 1 pending notification
    assert_difference 'PendingNotification.count', 1 do
      assert_emails 1 do
        Announcement.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version_number, false)
      end
    end

    pending_notif = PendingNotification.last
    assert_equal announcement, pending_notif.ref_obj
    assert_equal programs(:albers), pending_notif.program
    assert_equal RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, pending_notif.action_type
    assert_equal users(:f_mentor), pending_notif.ref_obj_creator
    assert_equal users(:ram), pending_notif.initiator

    # Should not do the operation again, if done once
    Announcement.any_instance.expects(:notification_list).returns(user_list)
    assert_no_difference 'PendingNotification.count' do
      assert_no_emails do
        Announcement.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version_number, false)
      end
    end

    # Update notification
    user_list = User.where(:id => [users(:f_student), users(:f_mentor), users(:rahim)])
    Announcement.any_instance.expects(:notification_list).returns(user_list)
    assert_difference 'PendingNotification.count', 1 do
      assert_emails 2 do
        Announcement.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, announcement.version_number, false)
      end
    end

    pending_notif = PendingNotification.last
    assert_equal announcement, pending_notif.ref_obj
    assert_equal programs(:albers), pending_notif.program
    assert_equal RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, pending_notif.action_type
    assert_equal users(:f_mentor), pending_notif.ref_obj_creator
    assert_equal users(:ram), pending_notif.initiator

    Announcement.any_instance.expects(:notification_list).returns(user_list)
    assert_no_difference 'PendingNotification.count' do
      assert_no_emails do
        Announcement.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, announcement.version_number, false)
      end
    end

    user_list = User.where(:id => [users(:f_student), users(:f_mentor), users(:rahim)])
    Announcement.any_instance.expects(:notification_list).returns(user_list)
    announcement.update_attributes!(title: "Awesome")
    announcement.program.mailer_template_enable_or_disable(AnnouncementUpdateNotification, true)
    assert_difference 'PendingNotification.count', 1 do
      assert_emails 2 do
        Announcement.notify_users(announcement.id, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, announcement.version_number, false)
      end
    end
  end

  def test_send_test_emails_for_new_announcement
    albers = programs(:albers)
    notify_list = "abc@example.com,def@example.com"
    new_announcement = Announcement.new
    new_announcement.admin = users(:ram)
    new_announcement.title = 'Hello'
    new_announcement.program = albers
    new_announcement.body = 'Great'
    new_announcement.title = 'Hello'

    new_announcement.wants_test_email = false
    new_announcement.notification_list_for_test_email = ""
    assert_no_emails do
      new_announcement.send_test_emails
    end

    new_announcement.wants_test_email = true
    assert_no_emails do
      new_announcement.send_test_emails
    end

    new_announcement.notification_list_for_test_email = notify_list

    # Send actual email.
    assert_emails(2) do
      new_announcement.send_test_emails
    end

    # Now, test which mailer method is called.
    emails = notify_list.split(',').map(&:strip)
    emails.each do |email|
      ChronusMailer.expects(:announcement_notification).with(nil, new_announcement, {:is_test_mail => true, :non_system_email => email}).returns(stub(:deliver_now))
    end
    new_announcement.send_test_emails

    f_user = users(:f_user)
    notify_email = f_user.email
    new_announcement.notification_list_for_test_email = notify_email

    ChronusMailer.expects(:announcement_notification).with(f_user, new_announcement, {:is_test_mail => true}).returns(stub(:deliver_now))
    new_announcement.send_test_emails

    teacher_0 = members(:teacher_0)
    notify_email = teacher_0.email
    new_announcement.notification_list_for_test_email = notify_email

    assert_equal albers.organization, teacher_0.organization
    assert_nil teacher_0.user_in_program(albers)

    ChronusMailer.expects(:announcement_notification).with(nil, new_announcement, {:is_test_mail => true, :non_system_email => notify_email}).returns(stub(:deliver_now))
    new_announcement.send_test_emails
  end

  def test_send_test_emails_for_announcement_update
    notify_list = "abc@example.com,def@example.com"
    ann = announcements(:assemble)
    program = programs(:albers)
    admin = program.admin_users.first


    ann.wants_test_email = false
    ann.notification_list_for_test_email = ""
    assert_no_emails do
      ann.send_test_emails
    end

    ann.wants_test_email = true
    assert_no_emails do
      ann.send_test_emails
    end

    ann.notification_list_for_test_email = notify_list

    # Send actual email.
    assert_emails(2) do
      ann.send_test_emails
    end

    # Now, test which mailer method is called.
    emails = notify_list.split(',').map(&:strip)
    emails.each do |email|
      ChronusMailer.expects(:announcement_notification).with(nil, ann, {:is_test_mail => true, :non_system_email => email}).returns(stub(:deliver_now))
    end
    ann.send_test_emails

    emails.each do |email|
      ChronusMailer.expects(:announcement_notification).with(nil, ann, {:is_test_mail => true, :non_system_email => email}).returns(stub(:deliver_now))
    end
    ann.body = "&lt! - -         adfsf - - &gtabc"
    ann.send_test_emails # This should sanitize the content before sendint the test email.
    assert_equal "abc", ann.body
  end

  def test_pending_notifications_should_dependent_destroy_on_announcement_deletion
    users(:f_mentor).update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    assert_difference('Announcement.count',1) do
      assert_difference('PendingNotification.count',1) do
        @announcement = create_announcement(email_notification: UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, recipient_role_names: RoleConstants::MENTOR_NAME)
      end
    end
    assert_difference('PendingNotification.count', -1) do
      assert_difference('Announcement.count',-1) do
        @announcement.destroy
      end
    end
  end

  def test_job_logs
    announcement = create_announcement
    assert_difference "JobLog.count", 2 do
      create_job_log(user: users(:mkr_student), object: announcement)
      create_job_log(user: users(:f_mentor), object: announcement)
    end

    assert_no_difference "JobLog.count" do
      assert_difference "Announcement.count", -1 do
        announcement.destroy
      end
    end
  end

  def test_recipient_roles_str
    assert_equal "Mentors", announcements(:drafted_announcement).recipient_roles_str
    assert_equal "Mentors and Students", announcements(:big_announcement).recipient_roles_str
  end

  def test_notify_immediately
    announcement = announcements(:assemble)
    announcement.email_notification = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    assert announcement.notify_immediately?

    (UserConstants::DigestV2Setting::ProgramUpdates.all - [UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE]).each do |email_notification_setting|
      announcement.email_notification = email_notification_setting
      assert_false announcement.notify_immediately?
    end
  end

  def test_notify_in_digest
    announcement = announcements(:assemble)
    announcement.email_notification = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    assert announcement.notify_in_digest?

    (UserConstants::DigestV2Setting::ProgramUpdates.all - [UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY]).each do |email_notification_setting|
      announcement.email_notification = email_notification_setting
      assert_false announcement.notify_in_digest?
    end
  end

  def test_notify
    announcement = announcements(:assemble)
    announcement.stubs(:notify_immediately?).returns(true)
    assert announcement.notify?
    announcement.block_mail = true
    assert_false announcement.notify?

    announcement.block_mail = nil
    announcement.stubs(:notify_immediately?).returns(false)
    announcement.stubs(:notify_in_digest?).returns(true)
    assert announcement.notify?

    announcement.block_mail = true
    assert_false announcement.notify?

    announcement.block_mail = nil
    announcement.stubs(:notify_in_digest?).returns(false)
    assert_false announcement.notify?
  end

  def test_version_number
    announcement = announcements(:assemble)
    assert_equal 1, announcement.version_number
    announcement = create_announcement(:title => "globalized announcement", :body => "test body")
    assert_equal 1, announcement.version_number
    create_chronus_version(item: announcement, object_changes: "", event: ChronusVersion::Events::UPDATE)
    assert_equal 2, announcement.reload.version_number
  end

  def test_translated_fields
    announcement = create_announcement(:title => "globalized announcement", :body => "test body")
    Globalize.with_locale(:en) do
      announcement.title = "english title"
      announcement.body = "english body"
      announcement.save!
    end
    Globalize.with_locale(:"fr-CA") do
      announcement.title = "french title"
      announcement.body = "french body"
      announcement.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", announcement.title
      assert_equal "english body", announcement.body
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", announcement.title
      assert_equal "french body", announcement.body
    end
  end

  def test_dependent_destroy_push_notifications
    announcement = create_announcement(email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, recipient_role_names: RoleConstants::MENTOR_NAME)

    object = {object_id: announcement.id, category: Announcement.name}
    users(:f_mentor).member.push_notifications.create!(notification_params: object, ref_obj_id: announcement.id, ref_obj_type: announcement.class.name, notification_type: PushNotification::Type::ANNOUNCEMENT_NEW)
    assert_difference "PushNotification.count", -1 do
      announcement.reload.destroy
    end
  end

  def test_viewed_objects_association
    announcement = announcements(:assemble)
    assert_equal viewed_objects(:viewed_object_1), announcement.viewed_objects.first
    assert_difference "ViewedObject.count", -42 do
      announcement.destroy
    end
    announcement = announcements(:big_announcement)
    new_viewed_object = create_viewed_object(ref_obj: announcement, user: users(:not_requestable_mentor))
    assert_equal_unordered [new_viewed_object, viewed_objects(:viewed_object_3)], [announcement.viewed_objects.first, announcement.viewed_objects.last]
  end

  def test_mark_announcement_visibility_for_user
    user = users(:f_mentor)
    announcement = announcements(:assemble)
    assert_no_difference "ViewedObject.count" do
      announcement.mark_announcement_visibility_for_user(user.id, false)
    end
    user = users(:drafted_group_user)
    announcement.update_column(:updated_at, Announcement::VIEWABLE_CUTOFF_DATE.to_datetime - 1.day)
     assert_no_difference "ViewedObject.count" do
      announcement.mark_announcement_visibility_for_user(user.id, false)
    end

    announcement.update_column(:updated_at, Time.now)
    assert_no_difference "ViewedObject.count" do
      announcement.mark_announcement_visibility_for_user(user.id, true)
    end

    assert_difference "ViewedObject.count", 1 do
      announcement.mark_announcement_visibility_for_user(user.id, false)
    end
  end

  def test_versioning
    assert_no_difference "ChronusVersion.count" do
      create_announcement(title: "globalized announcement", body: "test body")
    end
    announcement = announcements(:drafted_announcement)
    assert announcement.versions.empty?
    new_params_array = [{title: "new title"}, {body: "new body"}, {expiration_date: Time.now}, {email_notification: UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY}, {status: Announcement::Status::PUBLISHED}]
    new_params_array.each do |params|
      assert_difference "announcement.versions.size", 1 do
        assert_difference "ChronusVersion.count", 1 do
          announcement.update_attributes(params)
        end
      end
    end
    assert_no_difference "announcement.versions.size" do
      assert_no_difference "ChronusVersion.count" do
        announcement.destroy
      end
    end
  end
end
