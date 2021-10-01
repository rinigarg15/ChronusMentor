require_relative './../test_helper.rb'

class ProgramEventTest < ActiveSupport::TestCase

  def setup
    super
    chronus_s3_utils_stub
  end

  def test_validations
    event = ProgramEvent.new
    assert_false event.valid?
    assert_equal(["can't be blank"], event.errors[:user])
    assert_equal(["can't be blank"], event.errors[:admin_view])
    assert_equal(["can't be blank"], event.errors[:admin_view_title])
    assert_equal(["can't be blank"], event.errors[:program])
    assert_equal(["can't be blank"], event.errors[:title])
    assert_equal(["can't be blank"], event.errors[:start_time])
  end

  def test_belongs_to
    event = program_events(:birthday_party)
    assert_equal users(:ram), event.user
    assert_equal programs(:albers), event.program
  end

  def test_has_many
    event = program_events(:birthday_party)
    assert_equal 0, event.event_invites.size
    event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    assert_equal 1, event.event_invites.size

    assert_equal 44, event.program_event_users.size
    assert_equal 44, event.users.size
  end

  def test_scopes_past_upcoming
    event_1 = program_events(:birthday_party)
    event_2 = program_events(:ror_meetup)
    event_3 = program_events(:entrepreneur_meetup)
    event_4 = program_events(:portal_birthday_party)
    assert_equal_unordered [event_1, event_2, event_3, event_4], ProgramEvent.all
    assert_equal_unordered [event_1, event_2, event_3, event_4], ProgramEvent.upcoming

    event_3.update_attributes!(:start_time => 2.days.ago)
    assert_equal_unordered [event_1, event_2, event_3, event_4], ProgramEvent.all
    assert_equal_unordered [event_1, event_2, event_4], ProgramEvent.upcoming
    assert_equal_unordered [event_3], ProgramEvent.past

    event_3.update_attributes!(:start_time => 20.days.from_now)
  end

  def test_scope_for_user
    user = users(:f_mentor)
    admin = users(:f_admin)
    event_1 = program_events(:birthday_party)
    event_2 = program_events(:ror_meetup)
    event_3 = program_events(:entrepreneur_meetup)
    event_4 = program_events(:portal_birthday_party)
    assert_equal_unordered [event_1, event_2, event_3, event_4], ProgramEvent.all
    assert_equal_unordered [event_1, event_2], ProgramEvent.for_user(user)
    assert_equal_unordered [event_1, event_2], ProgramEvent.for_user(admin)

    event_2.program_event_users.where(user_id: [user.id, admin.id]).delete_all
    assert_equal_unordered [event_1], ProgramEvent.for_user(user)
    assert_equal_unordered [event_1, event_2], ProgramEvent.for_user(admin)
  end

  def test_scopes_draft_published
    program = programs(:albers)
    event_1 = program_events(:birthday_party)
    event_2 = program_events(:ror_meetup)
    assert_equal_unordered [event_2, event_1], program.program_events
    assert_equal_unordered [event_2, event_1], program.program_events.upcoming
    assert_equal [event_1], program.program_events.published
    assert_equal [event_1], program.program_events.published.upcoming
    assert_equal [event_2], program.program_events.drafted
    assert_equal [event_2], program.program_events.drafted.upcoming
    assert event_1.published?
    assert event_1.published_upcoming?
    assert_false event_1.draft?
    assert event_2.draft?
    assert_false event_2.published?
    assert_false event_2.published_upcoming?
  end

  def test_scopes_archived
    program = programs(:albers)
    event_1 = program_events(:birthday_party)
    assert !event_1.archived?
    assert_nil event_1.end_time

    event_1.start_time = "2010-12-06 07:30:00"
    event_1.save!
    assert event_1.archived?
    event_1.end_time = "2025-12-06 07:30:00"
    event_1.save!
    assert_false event_1.archived?
  end

  def test_start_time_end_time_of_the_day
    event = program_events(:birthday_party)
    event.update_column(:start_time,  "2015-12-06 07:30:00".to_datetime)
    assert_equal "01:00 pm", event.start_time_of_the_day
    assert_nil event.end_time_of_the_day
    event.stubs(:end_time).returns("2014-09-18 09:30".to_datetime)
    assert_equal "03:00 pm", event.end_time_of_the_day
    event.stubs(:time_zone).returns("Asia/Tokyo")
    assert_equal "06:30 pm", event.end_time_of_the_day
    assert_equal "04:30 pm", event.start_time_of_the_day
  end

  def test_notification_list
    event = program_events(:birthday_party)
    assert_equal event.admin_view.generate_view("", "",false).sort, ProgramEvent.notification_list(event.user_ids).map(&:id).sort
  end

  def test_send_test_emails_existing_event
    event = program_events(:birthday_party)
    program = programs(:albers)
    admin = program.admin_users.first
    display_time = "#{DateTime.localize(event.start_time.in_time_zone(event.time_zone), format: 'short_date_short_time'.to_sym)} IST"
    assert_no_emails do
      event.send_test_emails
    end

    assert_no_emails do
      event.send_test_emails
    end

    event.notification_list_for_test_email = "test2@test.com"
    assert_emails(1) do
      event.send_test_emails
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal ["test2@test.com"], email.to
    assert_equal "Update: Birthday Party", email.subject

    event.status = ProgramEvent::Status::DRAFT
    event.save!
    assert_emails(1) do
      event.send_test_emails
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal ["test2@test.com"], email.to
    assert_match "Invitation: Birthday Party on #{display_time}", email.subject
  end

  def test_send_test_emails_new_event
    new_event = programs(:albers).program_events.new(:user => users(:ram), :title => "(No title)")
    new_event.notification_list_for_test_email = "test2@test.com"

    program = programs(:albers)
    admin = program.admin_users.first

    assert_emails(1) do
      new_event.send_test_emails
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal ["test2@test.com"], email.to
    assert_equal "Invitation: (No title) on (Event Timings)", email.subject
  end

  def test_get_program_events_for_reminder
    program = programs(:albers)
    event = program_events(:birthday_party)
    time_now = Time.now
    assert_equal [], program.program_events.get_program_events_for_reminder(CronConstants::PROGRAM_EVENT_REMINDERS, CronConstants::PROGRAM_EVENT_REMINDERS_INTERVAL, time_now)
    event.start_time = 1.day.from_now
    event.save!
    assert_equal [event], program.program_events.get_program_events_for_reminder(CronConstants::PROGRAM_EVENT_REMINDERS, CronConstants::PROGRAM_EVENT_REMINDERS_INTERVAL, time_now)
    event.start_time = 1.day.from_now+5.minutes
    event.save!
    assert_equal [], program.program_events.get_program_events_for_reminder(CronConstants::PROGRAM_EVENT_REMINDERS, CronConstants::PROGRAM_EVENT_REMINDERS_INTERVAL, time_now)
    event.status = ProgramEvent::Status::DRAFT
    event.save!
    assert_equal [], program.program_events.get_program_events_for_reminder(CronConstants::PROGRAM_EVENT_REMINDERS, CronConstants::PROGRAM_EVENT_REMINDERS_INTERVAL, time_now)
  end

  def test_send_program_event_reminders
    program = programs(:albers)
    event = program_events(:birthday_party)
    time_now = Time.now
    event.start_time = 1.day.from_now
    event.save!
    event.event_invites.create!(:user => users(:ram), :status => EventInvite::Status::YES)
    event.save!
    assert_equal [event], program.program_events.get_program_events_for_reminder(CronConstants::PROGRAM_EVENT_REMINDERS, CronConstants::PROGRAM_EVENT_REMINDERS_INTERVAL, time_now)
    assert_equal 1, event.event_invites.size
    assert_equal 0, event.event_invites.needs_reminder.size
    invite = event.event_invites.first
    invite.reminder = true
    invite.save!
    assert_equal 1, event.event_invites.needs_reminder.size
    Push::Base.expects(:queued_notify).times(1)
    assert_emails(1) do
      ProgramEvent.send_program_event_reminders
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:ram).email], email.to
    assert_match "Reminder: Birthday Party on ", email.subject
  end

  def test_clear_user_rsvp
    programs(:albers).enable_feature(FeatureName::PROGRAM_EVENTS)
    RecentActivity.destroy_all
    # current_user_is :f_mentor
    user = users(:f_mentor)
    program_event = program_events(:birthday_party)
    assert_equal 0, program_event.event_invites.for_user(user).size
    assert_difference "EventInvite.count", 1 do
      assert_difference "RecentActivity.count", 1 do
        program_event.event_invites.create!(user: users(:f_mentor_student), status: EventInvite::Status::YES)
      end
    end
    assert_difference "EventInvite.count", 1 do
      assert_difference "RecentActivity.count", 1 do
        program_event.event_invites.create!(user: user, status: EventInvite::Status::YES)
      end
    end
    invite = EventInvite.last
    assert_no_difference "EventInvite.count" do
      assert_difference "RecentActivity.count", 1 do
        invite.update_attributes!(status: EventInvite::Status::NO)
      end
    end
    assert_no_difference "EventInvite.count" do
      assert_difference "RecentActivity.count", 1 do
        invite.update_attributes!(status: EventInvite::Status::MAYBE)
      end
    end
    assert_difference("RecentActivity.count") do
      RecentActivity.create!(ref_obj: groups(:mygroup),
                             action_type: RecentActivityConstants::Type::GROUP_REACTIVATION,
                             programs: [groups(:mygroup).program],
                             member: user.member,
                             target: RecentActivityConstants::Target::ALL)
    end
    assert_equal 4, RecentActivity.by_member(user.member).size
    types = RecentActivity.by_member(user.member).collect(&:action_type)
    assert types.include?(RecentActivityConstants::Type::GROUP_REACTIVATION)
    assert types.include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT)
    assert types.include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT)
    assert types.include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE)
    assert_equal 1, program_events(:birthday_party).event_invites.for_user(user).size
    assert_difference "EventInvite.count", -1 do
      assert_difference "RecentActivity.count", -3 do
        program_event.clear_user_rsvp(user)
      end
    end
    assert_false program_events(:birthday_party).event_invites.for_user(user).present?
    assert_equal 1, RecentActivity.by_member(user.reload.member).size
    types = RecentActivity.by_member(user.member).collect(&:action_type)
    assert types.include?(RecentActivityConstants::Type::GROUP_REACTIVATION)
    assert_false types.include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT)
    assert_false types.include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT)
    assert_false types.include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE)
  end

  def test_notify_users_for_deleted_event
    program_event = program_events(:birthday_party)
    title = program_event.get_titles_for_all_locales
    invite_list_size = ProgramEvent.notification_list(program_event.user_ids).size
    users_ids = program_event.program_event_users.pluck(:user_id)

    #subract one because one of the member in the list is a drafted user.
    assert_difference "JobLog.count", invite_list_size do
      assert_emails invite_list_size do
        ProgramEvent.notify_users_for_deleted_event(RecentActivityConstants::Type::PROGRAM_EVENT_DELETE,
          {klass_name: program_event.class.name, klass_id: program_event.id},
          {send_now: true, title: title, owner_id: program_event.user.id,
           program_id: program_event.program.id, users_ids: users_ids,
           location: program_event.location, start_time: program_event.start_time, created_at: program_event.created_at, program_event_id: program_event.id })
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "Cancelled Invitation: #{title[:en]}", email.subject

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        ProgramEvent.notify_users_for_deleted_event(RecentActivityConstants::Type::PROGRAM_EVENT_DELETE,
          {klass_name: program_event.class.name, klass_id: program_event.id},
          {send_now: true, title: title, owner_id: program_event.user.id,
           admin_view_id: program_event.admin_view_id, program_id: program_event.program.id,
           location: program_event.location, start_time: program_event.start_time })
      end
    end
  end

  def test_notify_users_for_deleted_event_for_different_locale
    program_event = program_events(:birthday_party)
    Globalize.with_locale(:de) do
      program_event.title = "Burday Parddy"
    end
    program_event.save!
    title = program_event.get_titles_for_all_locales
    invited_users = ProgramEvent.notification_list(program_event.user_ids)
    invite_list_size = invited_users.size
    users_ids = program_event.program_event_users.pluck(:user_id)
    invited_users.each do |user|
      user.member.member_language.destroy if user.member.member_language.present?
      user.member.build_member_language(language: languages(:hindi)).save!
    end

    assert_difference "JobLog.count", invite_list_size do
      assert_emails invite_list_size do
        ProgramEvent.notify_users_for_deleted_event(RecentActivityConstants::Type::PROGRAM_EVENT_DELETE,
          {klass_name: program_event.class.name, klass_id: program_event.id},
          {send_now: true, title: title, owner_id: program_event.user.id,
           program_id: program_event.program.id, users_ids: users_ids,
           location: program_event.location, start_time: program_event.start_time,  program_event_id: program_event.id, created_at: program_event.created_at })
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_match /Burday Parddy/, email.subject

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        ProgramEvent.notify_users_for_deleted_event(RecentActivityConstants::Type::PROGRAM_EVENT_DELETE,
          {klass_name: program_event.class.name, klass_id: program_event.id},
          {send_now: true, title: title, owner_id: program_event.user.id,
           admin_view_id: program_event.admin_view_id, program_id: program_event.program.id,
           location: program_event.location, start_time: program_event.start_time, program_event_id: program_event.id, created_at: program_event.created_at})
      end
    end
  end

  def test_has_many_job_logs
    program_event = program_events(:entrepreneur_meetup)
    user = users(:f_mentor_nwen_student)
    job_log = nil
    assert_equal 0, program_event.job_logs.size
    event_list_invites_size = ProgramEvent.notification_list(program_event.user_ids).size

    assert_difference "JobLog.count" do
      job_log = user.job_logs.create!(loggable_object: program_event, action_type: RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, version_id: program_event.version_number)
    end
    assert_equal Array(job_log), program_event.job_logs.reload

    assert_difference "JobLog.count", event_list_invites_size do
      program_event.destroy
    end
  end

  def test_notify_users
    program_event = program_events(:entrepreneur_meetup)
    title = program_event.title
    event_list_invites = ProgramEvent.notification_list(program_event.user_ids).size
    options = { send_now: true, users_ids: program_event.user_ids }

    assert_difference "JobLog.count", event_list_invites do
      Push::Base.expects(:queued_notify).times(event_list_invites)
      assert_emails(event_list_invites) do
        ProgramEvent.notify_users(program_event, RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, program_event.version_number, options)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_match "Invitation: Enterpreneur Meetup", email.subject

    assert_no_difference "JobLog.count" do
      Push::Base.expects(:queued_notify).never
      assert_no_emails do
        ProgramEvent.notify_users(program_event, RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, program_event.version_number, options)
      end
    end

    assert_difference "JobLog.count", event_list_invites do
      Push::Base.expects(:queued_notify).times(event_list_invites)
      assert_emails(event_list_invites) do
        ProgramEvent.notify_users(program_event, RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, program_event.version_number + 1, options)
      end
    end
  end

  def test_notify_users_update
    program_event = program_events(:entrepreneur_meetup)
    program_event.start_time = program_event.start_time + 6.hours
    program_event.email_notification = true
    event_list_invites = ProgramEvent.notification_list(program_event.user_ids).size
    options = { send_now: true, users_ids: program_event.user_ids }

    assert_no_difference "PendingNotification.count" do
      assert_difference "JobLog.count", event_list_invites do
        Push::Base.expects(:queued_notify).never
        assert_emails(event_list_invites) do
          ProgramEvent.notify_users(program_event, RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE, program_event.version_number, options)
        end
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_match "Update: Enterpreneur Meetup", email.subject

    assert_no_difference "PendingNotification.count" do
      assert_no_difference "JobLog.count" do
        Push::Base.expects(:queued_notify).never
        assert_no_emails do
          ProgramEvent.notify_users(program_event, RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE, program_event.version_number, options)
        end
      end
    end

    assert_no_difference "PendingNotification.count" do
      assert_difference "JobLog.count", event_list_invites do
        Push::Base.expects(:queued_notify).never
        assert_emails(event_list_invites) do
          ProgramEvent.notify_users(program_event, RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE, program_event.version_number + 1, options)
        end
      end
    end
  end

  def test_generate_attendees_csv
    program_event = program_events(:birthday_party)
    file_name = program_event.generate_attendees_csv("test_file.csv")
    csv = CSV.open(file_name).to_a
    assert_equal ["First name", "Last name", "Email", "Role", "Attending?"], csv[0]
    assert_equal ["Freakin", "Admin", "ram@example.com", "Administrator", "Not Responded"], csv[1]
  end

  def test_short_time_zone
    event = ProgramEvent.first
    assert_equal "IST", event.short_time_zone
    event.stubs(:time_zone).returns("")
    assert_equal "UTC", event.short_time_zone
    event.stubs(:time_zone).returns("Asia/Karachi")
    assert_equal "PKT", event.short_time_zone
  end

  def test_users_by_status
    event = program_events(:birthday_party)

    attending_users = event.event_invites.where(:status => EventInvite::Status::YES).joins(:user)
    assert_equal_unordered attending_users, event.users_by_status(0)

    not_attending_users = event.event_invites.where(:status => EventInvite::Status::NO).joins(:user)
    assert_equal_unordered not_attending_users, event.users_by_status(1)

    maybe_attending_users = event.event_invites.where(:status => EventInvite::Status::MAYBE).joins(:user)
    assert_equal_unordered maybe_attending_users, event.users_by_status(2)

    responded_users = attending_users + not_attending_users + maybe_attending_users
    not_responded_users = event.users - responded_users
    assert_equal_unordered not_responded_users, event.users_by_status(3)
  end

  def test_set_users_from_admin_view_for_existing_event
    event = program_events(:birthday_party)
    program = event.program
    event.admin_view = program.admin_views.last
    event.save!
    new_admin_view = program.admin_views.first
    assert_false new_admin_view.id == event.admin_view.id
    current_user_ids = event.program_event_users.pluck(:user_id)
    new_admin_view_user_ids = new_admin_view.generate_view("", "",false).to_a
    users_to_add = new_admin_view_user_ids - current_user_ids

    ActionMailer::Base.deliveries.clear
    freezed_datetime = '2014/06/25'.to_datetime.utc
    Timecop.freeze(freezed_datetime) do
      assert_difference 'ProgramEventUser.count', users_to_add.size do
        event.email_notification = true
        event.admin_view = new_admin_view
        event.save!
        assert_equal freezed_datetime, event.admin_view_fetched_at.utc
      end
    end
  end

  def test_set_users_from_admin_view_for_new_event
    program = programs(:albers)
    admin_view = program.admin_views.first
    new_event = program.program_events.new(:user => users(:ram), :title => "(No title)", :admin_view => admin_view, :start_time => 2.days.ago, :end_time => 1.day.from_now)
    new_event.email_notification = true
    users_to_add = admin_view.generate_view("", "",false)

    freezed_datetime = '2014/06/25'.to_datetime.utc
    Timecop.freeze(freezed_datetime) do
      assert_difference 'ProgramEventUser.count', users_to_add.size do
        new_event.save!
      end
    end
    assert_equal freezed_datetime, new_event.admin_view_fetched_at
  end

  def test_time_zone
    program_event = program_events(:birthday_party)
    program_event.stubs(:time_zone).returns("ProbePhising")
    assert_false program_event.valid?
    program_event.stubs(:time_zone).returns("Asia/Kolkata")
    assert program_event.valid?
    program_event.stubs(:time_zone).returns(nil)
    assert program_event.valid?
    program_event.stubs(:time_zone).returns(nil)
    assert program_event.valid?
  end

  def test_users_for_listing
    event = program_events(:birthday_party)
    invite = event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    invite.update_attribute(:updated_at, invite.updated_at + 10.minutes)
    event.event_invites.create!(:user => users(:f_student), :status => EventInvite::Status::NO)
    connected_users = event.program_event_users.where(:user_id => (users(:f_mentor).students + users(:f_mentor).mentors)).map(&:user)

    assert_equal (connected_users + [users(:f_mentor), users(:f_student)]).map(&:id), event.users_for_listing(users(:f_mentor)).limit(3).map(&:id)
  end

  def test_before_save
    event = program_events(:birthday_party)
    event.description = '<object width="425" height="344"><param name="movie" value="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;"><param name="allowFullScreen" value="true"><param name="allowscriptaccess" value="always"><embed src="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="425" height="344"></object>'
    event.current_member = members(:f_admin)
    event.sanitization_version = "v1"
    event.save!
    assert_match "<param name=\"allowscriptaccess\" value=\"never\">", event.description
  end

  def test_translated_fields_get_titles_for_all_locales
    event = program_events(:birthday_party)
    Globalize.with_locale(:en) do
      event.title = "english title"
      event.description = "english desc"
      event.save!
    end
    assert_equal "english title", event.get_titles_for_all_locales[:en]
    assert_nil event.get_titles_for_all_locales[:"fr-CA"]
    Globalize.with_locale(:"fr-CA") do
      event.title = "french title"
      event.description = "french desc"
      event.save!
    end
    assert_equal "english title", event.get_titles_for_all_locales[:en]
    assert_equal "french title", event.get_titles_for_all_locales[:"fr-CA"]
    Globalize.with_locale(:en) do
      assert_equal "english title", event.title
      assert_equal "english desc", event.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", event.title
      assert_equal "french desc", event.description
    end
  end

  def test_get_users_and_non_member_mails
    event = program_events(:birthday_party)
    event.notification_list_for_test_email = "ram@example.com, random@random.com"
    user, non_member = event.get_users_and_non_member_mails
    assert_equal_unordered [1], user.collect(&:id)
    assert_equal "random@random.com", non_member.first

    event.notification_list_for_test_email = "ram@example.com, rahim@example.com"
    user, non_member = event.get_users_and_non_member_mails
    assert_equal_unordered [1, 2], user.collect(&:id)
    assert_empty non_member

    event.notification_list_for_test_email = "ram@random.com, random@random.com"
    user, non_member = event.get_users_and_non_member_mails
    assert_empty user
    assert_equal "ram@random.com", non_member.first

    member_not_part_of_program = members(:teacher_0)
    assert event.program.organization == member_not_part_of_program.organization
    assert_nil member_not_part_of_program.user_in_program(event.program)
    event.notification_list_for_test_email = member_not_part_of_program.email
    user, non_member = event.get_users_and_non_member_mails
    assert_empty user
    assert_equal member_not_part_of_program.email, non_member.first

    event.notification_list_for_test_email = ""
    user, non_member = event.get_users_and_non_member_mails
    assert_empty user
    assert_empty non_member
  end

  def test_current_admin_view_changes
    program_event = program_events(:birthday_party)
    assert_equal [0, 0], program_event.get_current_admin_view_changes
    assert_false program_event.current_admin_view_changed?
  end

  def test_current_admin_view_changes_removed
    program_event = program_events(:birthday_party)
    user = users(:f_student)
    program_event_users = program_event.program_event_users
    program_event_users_user_ids = program_event_users.pluck(:user_id)
    assert program_event_users_user_ids.include? user.id

    program_event.stubs(:get_user_ids_to_set).returns(program_event_users_user_ids - [user.id])
    assert_equal [0, 1], program_event.get_current_admin_view_changes
    assert program_event.current_admin_view_changed?
  end

  def test_current_admin_view_changes_added
    program_event = program_events(:birthday_party)
    user = users(:f_student)
    program_event_users = program_event.program_event_users
    program_event_users_user_ids = program_event_users.pluck(:user_id)
    assert program_event_users_user_ids.include? user.id

    program_event.stubs(:program_event_users).returns(program_event_users.where("user_id != ?", user.id))
    assert_equal [1, 0], program_event.get_current_admin_view_changes
    assert program_event.current_admin_view_changed?
  end

  def test_get_attending_size
    program_event = program_events(:birthday_party)
    assert_equal 0, program_event.get_attending_size

    program_event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    assert_equal 1, program_event.get_attending_size
  end

  def test_versioning
    program_event = program_events(:birthday_party)

    assert program_event.versions.empty?
    assert_difference "ChronusVersion.count", 1 do
      program_event.update_attributes(title: "new title")
    end
    assert_equal 1, program_event.versions.size
    assert_no_difference "ChronusVersion.count" do
      program_event.update_attributes(title: "new title")
    end
    assert_equal 1, program_event.versions.size
    assert_no_difference "ChronusVersion.count" do
      program_event.destroy
    end
    assert_equal 1, program_event.versions.size
  end

  def test_version_number
    program_event = program_events(:birthday_party)
    assert_equal 1, program_event.version_number
    create_chronus_version(item: program_event, object_changes: "", event: ChronusVersion::Events::UPDATE)
    assert_equal 2, program_event.reload.version_number
  end

  def test_get_calendar_event_uid
    program_event = program_events(:birthday_party)
    CalendarUtils.expects(:get_calendar_event_uid).with(program_event)
    program_event.get_calendar_event_uid
  end

  def test_get_description_for_calendar_event
    program_event = program_events(:birthday_party)

    description = program_event.get_description_for_calendar_event
    assert_match /p\/#{program_event.program.root}\/program_events\/#{program_event.id}/, description
  end
end