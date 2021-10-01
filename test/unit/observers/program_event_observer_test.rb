require_relative './../../test_helper.rb'

class ProgramEventObserverTest < ActiveSupport::TestCase

  def setup
    super
    chronus_s3_utils_stub
  end

  def test_after_create_draft
    program = programs(:albers)
    admin_view = program.admin_views.first
    users_size = admin_view.generate_view("", "", false).size
    assert_no_emails do
      assert_no_difference 'RecentActivity.count' do #One for creation and one for owner attending
        assert_difference 'ProgramEvent.count', 1 do
          assert_difference 'ProgramEventUser.count', users_size do
            event = program.program_events.new(:title => "Hack Day", :location => "chennai, tamilnadu, india", :start_time => 30.days.from_now, :status => ProgramEvent::Status::PUBLISHED, :admin_view => admin_view, :user => users(:ram), :time_zone => "Asia/Kolkata")
            event.email_notification = true
            event.status = ProgramEvent::Status::DRAFT
            event.save!
          end
        end
      end
    end
  end

  def test_after_create_delete
    program = programs(:albers)
    admin_view = program.admin_views.first
    notification_list = admin_view.generate_view("", "", false).to_a
    assert_nothing_raised do
      assert_emails(notification_list.size) do
        assert_no_difference 'RecentActivity.count' do #Creation of event
          assert_no_difference 'ProgramEvent.count' do
              event = program.program_events.new(:title => "Hack Day", :location => "chennai, tamilnadu, india", :start_time => 30.days.from_now, :status => ProgramEvent::Status::PUBLISHED, :admin_view => admin_view, :user => users(:ram), :time_zone => "Asia/Kolkata")
              event.email_notification = false
              event.save!
              event.destroy
          end
        end
      end
    end
  end

  def test_after_update_delete
    program = programs(:albers)
    admin_view = program.admin_views.first
    notification_list = admin_view.generate_view("", "", false).to_a
    assert_nothing_raised do
      assert_emails(notification_list.size) do
        assert_no_difference 'RecentActivity.count' do #Creation of event
          assert_no_difference 'ProgramEvent.count' do
              event = program.program_events.new(:title => "Hack Day", :location => "chennai, tamilnadu, india", :start_time => 30.days.from_now, :status => ProgramEvent::Status::PUBLISHED, :admin_view => admin_view, :user => users(:ram), :time_zone => "Asia/Kolkata")
              event.email_notification = false
              event.save!
              event.title = "New Hack Day"  #Updation of Event
              event.save!
              event.destroy
          end
        end
      end
    end
  end

  def test_after_create_published
    program = programs(:albers)
    admin_view = program.admin_views.first
    notification_list = admin_view.generate_view("", "", false).to_a
    assert_emails(notification_list.size) do
      assert_difference 'RecentActivity.count', 1 do #Creation of event
        assert_difference 'ProgramEvent.count', 1 do
          event = program.program_events.new(:title => "Hack Day", :location => "chennai, tamilnadu, india", :start_time => 30.days.from_now, :status => ProgramEvent::Status::PUBLISHED, :admin_view => admin_view, :user => users(:ram), :time_zone => "Asia/Kolkata")
          event.email_notification = true
          event.save!
        end
      end
    end
    assert_equal RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, RecentActivity.last.action_type
    assert_equal RecentActivityConstants::Target::ALL, RecentActivity.last.target
  end

  def test_after_update_draft
    event = program_events(:entrepreneur_meetup)
    event.status = ProgramEvent::Status::DRAFT
    event.save!
    assert_no_emails do
      assert_no_difference 'RecentActivity.count' do
        assert_no_difference 'ProgramEvent.count' do
          assert_no_difference 'ProgramEventUser.count' do
            event.email_notification = true
            event.save!
          end
        end
      end
    end
  end

  def test_after_update_published
    event = program_events(:entrepreneur_meetup)
    old_version = event.version_number
    admin_view = programs(:nwen).admin_views.where(default_view: AbstractView::DefaultType::ALL_USERS).first
    all_users_size = event.users.size
    event.program_event_users.where(user_id: users(:f_mentor_nwen_student).id).destroy_all

    ProgramEvent.any_instance.stubs(:saved_change_to_admin_view_id?).returns(true)
    assert_emails(all_users_size) do
      assert_difference 'ProgramEventUser.count' do
        assert_difference 'RecentActivity.count' do
          assert_no_difference 'ProgramEvent.count' do
            event.email_notification = true
            event.admin_view = admin_view
            event.save!
          end
        end
      end
    end
    emails = ActionMailer::Base.deliveries.last(all_users_size)
    assert_match /Invitation: #{event.title} on/, emails[0].subject
    assert_equal [users(:f_mentor_nwen_student).email], emails[0].to
    assert_equal ["Update: #{event.title}"], emails[1..-1].collect(&:subject).uniq
    assert_equal old_version + 1, event.reload.version_number
    assert_equal RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE, RecentActivity.last.action_type
    assert_equal RecentActivityConstants::Target::ALL, RecentActivity.last.target
  end

  def test_after_destroy_draft
    event = program_events(:birthday_party)
    event.status = ProgramEvent::Status::DRAFT
    event.save!
    assert_no_emails do
      assert_no_difference 'RecentActivity.count' do
        assert_difference 'ProgramEvent.count', -1 do
          event.destroy
        end
      end
    end
  end

  def test_after_destroy_published
    event = program_events(:birthday_party)
    assert_emails(event.users.active_or_pending.size) do
      assert_no_difference 'RecentActivity.count' do
        assert_difference 'ProgramEvent.count', -1 do
          event.destroy
        end
      end
    end
  end

  def test_after_destroy_archived
    event = program_events(:birthday_party)
    event.start_time = "2012-06-06 07:30:00"
    event.save!
    assert event.archived?
    assert_no_emails do
      assert_no_difference 'RecentActivity.count' do
        assert_difference 'ProgramEvent.count', -1 do
          event.destroy
        end
      end
    end
  end

  def test_after_update_reset_rsvps
    event = program_events(:birthday_party)
    new_event_invite = event.event_invites.new(user_id: users(:ram).id)
    new_event_invite.status = 0
    new_event_invite.save!
    assert_equal 1, event.event_invites.count
    assert_equal 1, event.recent_activities.of_type([RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE]).count
    event.start_time = 1.day.from_now
    event.save!
    assert_equal 0, event.event_invites.count
    assert_equal 0, event.recent_activities.of_type([RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE]).count
  end

end