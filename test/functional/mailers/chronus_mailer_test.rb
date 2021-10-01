require_relative './../../test_helper.rb'

class ChronusMailerTest < ActiveSupport::TestCase
  def setup
    super
    chronus_s3_utils_stub
  end

  def test_run_with_locale
    current_locale = I18n.locale
    test_locale = :fr
    assert test_locale != current_locale

    ChronusMailer.run_with_locale(current_locale) do
      assert_equal "en test", "test".translate
    end

    ChronusMailer.run_with_locale(test_locale) do
      assert_equal "fr test", "test".translate
    end
    assert_equal current_locale, I18n.locale

    assert_raise RuntimeError do
      ChronusMailer.run_with_locale(test_locale) do
        assert_equal test_locale, I18n.locale
        raise "some error"
      end
    end
    assert_equal current_locale, I18n.locale
  end

  def test_expected_locale_for_password
    member = members(:f_mentor)
    Language.set_for_member(member, :en)
    password = Password.create!(:member => member)
    assert_equal :en, ChronusMailer.expected_locale_for(password)
    Language.set_for_member(member, :de)
    password = Password.create!(:member => member)
    assert_equal :de, ChronusMailer.expected_locale_for(password)
  end

  def test_expected_locale_for_membership_request
    membership_request = create_membership_request
    assert_equal :en, ChronusMailer.expected_locale_for(membership_request)
    member = membership_request.member
    Language.set_for_member(member, :en)
    assert_equal :en, ChronusMailer.expected_locale_for(membership_request)
    Language.set_for_member(member, :de)
    membership_request.reload
    assert_equal :de, ChronusMailer.expected_locale_for(membership_request)
  end

  def test_first_argument_is_not_user
    password = Password.create!(:member => members(:f_admin))
    assert_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.forgot_password(password, programs(:org_primary) ).deliver_now
    end
  end

  def test_should_raise_exception_when_the_receiver_object_is_an_array_of_distinct_objects
    # Make sure that all the exposed templates are enabled
    Organization.any_instance.stubs(:email_template_disabled_for_activity?).returns(true)

    # Handle array of mix of object types
    group = groups(:mygroup)
    array = [users(:f_student), members(:f_student)]
    e = assert_raise RuntimeError do
      ChronusMailer.group_creation_notification_to_students(array, group).deliver_now
    end
    assert_equal("Object is an array containing more than one type of objects", e.message)
  end

  def test_should_raise_exception_when_an_handled_object_is_passed_as_receiver
    # Make sure that all the exposed templates are enabled
    Organization.any_instance.stubs(:email_template_disabled_for_activity?).returns(true)

    # Handle array of mix of object types
    unhandled_object = Education.first
    assert_false unhandled_object.respond_to?(:program)
    e = assert_raise RuntimeError do
      ChronusMailer.welcome_message_to_admin(unhandled_object).deliver_now
    end
    assert_equal("Program does not exist for the object", e.message)
  end

  def test_should_deliver_all_unexposed_email_templates
    # Make sure that all the exposed templates are disabled
    Organization.any_instance.stubs(:email_template_disabled_for_activity?).returns(true)
    user = users(:f_admin)

    announcement = announcements(:assemble)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.announcement_notification(user, announcement).deliver_now
    end

    password = Password.create!(:member => user.member)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.forgot_password(password, programs(:org_primary)).deliver_now
    end

    login_token = members(:f_mentor).login_tokens.new
    login_token.save!
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.mobile_app_login(members(:f_mentor), login_token, "uniq_token").deliver_now
    end
  end

  def test_should_check_deliver_when_organization_suspended
    # Make sure that all the exposed templates are disabled
    programs(:org_primary).active = false
    programs(:org_primary).save!

    # Handle array of users
    group = groups(:mygroup)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.group_creation_notification_to_students(group.students.first, group).deliver_now
    end

    admin = users(:f_admin)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.welcome_message_to_admin(admin).deliver_now
    end
  end

  def test_should_check_deliver_when_the_email_template_is_enabled
    # Make sure that all the exposed templates are enabled
    Organization.any_instance.stubs(:email_template_disabled_for_activity?).returns(false)

    # Handle array of users
    group = groups(:mygroup)
    assert_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.group_creation_notification_to_students(group.students.first, group).deliver_now
    end

    admin = users(:f_admin)
    assert_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.welcome_message_to_admin(admin).deliver_now
    end
  end

  def test_should_check_deliver_when_the_email_template_is_disabled
    # Make sure that all the exposed templates are disabled
    Organization.any_instance.stubs(:email_template_disabled_for_activity?).returns(true)

    # Handle array of users
    group = groups(:mygroup)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.group_creation_notification_to_students(group.students.first, group).deliver_now
    end

    admin = users(:f_admin)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.welcome_message_to_admin(admin).deliver_now
    end
  end

  def test_email_change_notification_should_not_be_sent_when_enabled
    # This case is specially covered to test the case when the receipient is ChronusUser object
    Organization.any_instance.stubs(:email_template_disabled_for_activity?).returns(true)

    member = members(:f_mentor)
    member.email_changer = members(:f_admin)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.email_change_notification(member, "old_test@gmail.com").deliver_now
    end
  end

  def test_email_change_notification_should_be_sent_when_enabled
    # This case is specially covered to test the case when the receipient is ChronusUser object
    Organization.any_instance.stubs(:email_template_disabled_for_activity?).returns(false)

    member = members(:f_mentor)
    member.email_changer = members(:f_admin)
    assert_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.email_change_notification(member, "old_test@gmail.com").deliver_now
    end
  end

  def test_user_is_not_deleted
    user = users(:f_admin)
    assert_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.welcome_message_to_admin(user).deliver_now
    end
  end

  def test_user_is_deleted
    user = users(:f_admin)
    user.delete!
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.welcome_message_to_admin(user).deliver_now
    end
  end

  def test_user_is_deleted_but_mail_is_forced_to_be_delivered
    user = users(:f_admin)
    user.delete!
    assert_difference('ActionMailer::Base.deliveries.size') do
      ChronusMailer.welcome_message_to_admin(user, :force_send => true).deliver_now
    end
  end

  def test_essential_emails_are_delivered
    user = users(:f_mentor)
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    user.save!

    UserActivationNotification.expects(:user_activation_notification).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.user_activation_notification(user).deliver_now

    UserSuspensionNotification.expects(:user_suspension_notification).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.user_suspension_notification(user).deliver_now

    MentorAddedNotification.expects(:mentor_added_notification).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.mentor_added_notification(user).deliver_now

    UserWithSetOfRolesAddedNotification.expects(:user_with_set_of_roles_added_notification).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.user_with_set_of_roles_added_notification(user).deliver_now

    AdminAddedDirectlyNotification.expects(:admin_added_directly_notification).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.admin_added_directly_notification(user).deliver_now

    EmailChangeNotification.expects(:email_change_notification).with(user.member).once.returns(stub(:deliver_now))
    user.member.email_changer = members(:f_admin)
    ChronusMailer.email_change_notification(user.member).deliver_now

    ForgotPassword.expects(:forgot_password).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.forgot_password(user).deliver_now

    GroupInactivityNotification.expects(:group_inactivity_notification).with(user, groups(:mygroup)).once.returns(stub(:deliver_now))
    ChronusMailer.group_inactivity_notification(user, groups(:mygroup)).deliver_now

    student = groups(:mygroup).students.first
    student.update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    GroupInactivityNotificationWithAutoTerminate.expects(:group_inactivity_notification_with_auto_terminate).with(student, groups(:mygroup)).once.returns(stub(:deliver_now))
    ChronusMailer.group_inactivity_notification_with_auto_terminate(student, groups(:mygroup)).deliver_now

    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    time = time_now - 2.days
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    MeetingRequestReminderNotification.expects(:meeting_request_reminder_notification).with(user, meeting_request).once.returns(stub(:deliver_now))
    ChronusMailer.meeting_request_reminder_notification(user, meeting_request).deliver_now

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    MeetingRequestCreatedNotification.expects(:meeting_request_created_notification).with(user, meeting_request, meeting.generate_ics_calendar, sender: meeting_request.student).once.returns(stub(:deliver_now))
    ChronusMailer.meeting_request_created_notification(user, meeting_request, meeting.generate_ics_calendar, sender: meeting_request.student).deliver_now
  end

  def test_career_developement_essential_emails_are_delivered
    user = users(:portal_employee)
    PortalMemberWithSetOfRolesAddedNotification.expects(:portal_member_with_set_of_roles_added_notification).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.portal_member_with_set_of_roles_added_notification(user).deliver_now

    PortalMemberWithSetOfRolesAddedNotificationToReviewProfile.expects(:portal_member_with_set_of_roles_added_notification_to_review_profile).with(user).once.returns(stub(:deliver_now))
    ChronusMailer.portal_member_with_set_of_roles_added_notification_to_review_profile(user).deliver_now
  end

  def test_should_forward_the_method_to_appropriate_mailer_if_mailer_option_is_present
    admin = users(:f_admin)
    program = programs(:albers)
    precomputed_hash = program.get_admin_weekly_status_hash
    AdminWeeklyStatus.expects(:admin_weekly_status).with(admin, program, precomputed_hash).once.returns(stub(:deliver_now))
    ChronusMailer.admin_weekly_status(admin, program, precomputed_hash).deliver_now
  end

  def test_should_propogate_hash_options_to_mailer
    admin = users(:f_admin)
    program = programs(:albers)
    precomputed_hash = program.get_admin_weekly_status_hash

    ForgotPassword.expects(:forgot_password).with(admin).once.returns(stub(:deliver_now))
    ChronusMailer.forgot_password(admin).deliver_now

    AdminWeeklyStatus.expects(:admin_weekly_status).with(admin, program, precomputed_hash).once.returns(stub(:deliver_now))
    ChronusMailer.admin_weekly_status(admin, program, precomputed_hash, :force_send => true).deliver_now

    AdminWeeklyStatus.expects(:admin_weekly_status).with(admin, program, precomputed_hash, :mail_option => '123', :other_option => '234').once.returns(stub(:deliver_now))
    ChronusMailer.admin_weekly_status(admin, program, precomputed_hash, :force_send => true, :mail_option => '123', :other_option => '234').deliver_now
  end

  def test_essential_mailers_exact_match
    pre = 'prefix_'
    suf = '_suffix'
    mailers = ChronusMailer::EssentialMailers
    mailers.each do |mailer_name|
      assert ChronusMailer.essential_notification?(mailer_name)
      assert_false ChronusMailer.essential_notification?(mailer_name + suf)
      assert_false ChronusMailer.essential_notification?(pre + mailer_name)
    end
  end

  def test_meeting_request_notification_mailers_permissions
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    mentor = users(:f_mentor)
    mentor.update_attribute(:state, User::Status::ACTIVE)
    assert_emails 1 do
      ChronusMailer.meeting_request_reminder_notification(mentor, meeting_request).deliver_now
    end

    mentor.update_attribute(:state, User::Status::PENDING)
    assert_emails 1 do
      ChronusMailer.meeting_request_reminder_notification(mentor, meeting_request).deliver_now
    end

    mentor.update_attribute(:state, User::Status::SUSPENDED)
    assert_no_emails do
      ChronusMailer.meeting_request_reminder_notification(mentor, meeting_request).deliver_now
    end
  end

  def test_email_template_disabled_for_mail_level
    program = programs(:albers)
    organization = programs(:org_primary)

    program_mailer = program.mailer_templates.create!(:uid => UserActivationNotification.mailer_attributes[:uid], :enabled => false)
    org_mailer = organization.mailer_templates.create!(:uid => EmailChangeNotification.mailer_attributes[:uid], :enabled => false)

    assert_equal UserActivationNotification.mailer_attributes[:level], EmailCustomization::Level::PROGRAM
    assert_equal EmailChangeNotification.mailer_attributes[:level], EmailCustomization::Level::ORGANIZATION

    assert ChronusMailer.email_template_disabled?(users(:f_mentor), UserActivationNotification)
    assert ChronusMailer.email_template_disabled?(users(:f_mentor), EmailChangeNotification)

    program_mailer.update_attributes!(:enabled => true)
    org_mailer.update_attributes!(:enabled => true)

    assert_false ChronusMailer.email_template_disabled?(users(:f_mentor), UserActivationNotification)
    assert_false ChronusMailer.email_template_disabled?(users(:f_mentor), EmailChangeNotification)

    program_mailer = program.mailer_templates.create!(:uid => EmailChangeNotification.mailer_attributes[:uid], :enabled => false)
    assert_false ChronusMailer.email_template_disabled?(users(:f_mentor), EmailChangeNotification)
  end

  private

  def _a_article
    "an article"
  end

  def _article
    "article"
  end

  def _Article
    "Article"
  end

  def _articles
    "articles"
  end

  def _Articles
    "Articles"
  end

end
