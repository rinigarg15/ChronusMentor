require_relative './../test_helper.rb'

class EventInviteTest < ActiveSupport::TestCase	
  def test_validations
    event = EventInvite.new
    assert_false event.valid?
    assert_equal(["can't be blank"], event.errors[:user])
    assert_equal(["can't be blank"], event.errors[:program_event])
  end

  def test_belongs_to
    event = program_events(:birthday_party)
    event_invite = event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    assert_equal users(:f_mentor), event_invite.user
    assert_equal program_events(:birthday_party), event_invite.program_event
  end

  def test_scopes
    event = program_events(:birthday_party)
    event_invite = event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    assert_equal EventInvite::Status::YES, event_invite.status
    assert_equal_unordered [event_invite], event.event_invites.attending

    event_invite.status = EventInvite::Status::NO
    event_invite.save!
    assert_equal EventInvite::Status::NO, event_invite.status
    assert_equal [event_invite], event.event_invites.not_attending

    event_invite.status = EventInvite::Status::MAYBE
    event_invite.save!
    assert_equal EventInvite::Status::MAYBE, event_invite.status
    assert_equal [event_invite], event.event_invites.maybe_attending
  end

  def test_for_user
    event = program_events(:birthday_party)
    assert_equal [], event.event_invites.for_user(users(:f_mentor))
    event_invite = event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    assert_equal [event_invite], event.event_invites.for_user(users(:f_mentor))
  end

  def test_scope_needs_reminder
    event = program_events(:birthday_party)
    assert_equal [], event.event_invites.needs_reminder
    new_invite = event.event_invites.create!(:user => users(:f_mentor), :reminder => true, :status => EventInvite::Status::YES)
    assert_equal [new_invite], event.event_invites.needs_reminder
    new_invite.reminder_sent_time = 2.hours.ago
    new_invite.save!
    assert_equal [], event.event_invites.needs_reminder
  end

  def test_status_title
    assert_equal "Yes", EventInvite::Status.title(EventInvite::Status::YES)
    assert_equal "No", EventInvite::Status.title(EventInvite::Status::NO)
    assert_equal "Maybe", EventInvite::Status.title(EventInvite::Status::MAYBE)
    assert_equal "Not Responded", EventInvite::Status.title(nil)
  end

  def test_attending_not_attending_maybe_attending
    event_invite = EventInvite.new
    assert_false event_invite.attending?
    assert_false event_invite.not_attending?
    assert_false event_invite.maybe_attending?

    event_invite.status = EventInvite::Status::YES
    assert event_invite.attending?
    assert_false event_invite.not_attending?
    assert_false event_invite.maybe_attending?

    event_invite.status = EventInvite::Status::NO
    assert_false event_invite.attending?
    assert event_invite.not_attending?
    assert_false event_invite.maybe_attending?

    event_invite.status = EventInvite::Status::MAYBE
    assert_false event_invite.attending?
    assert_false event_invite.not_attending?
    assert event_invite.maybe_attending?
  end
end