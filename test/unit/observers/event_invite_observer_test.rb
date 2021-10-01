require_relative './../../test_helper.rb'

class EventInviteObserverTest < ActiveSupport::TestCase

  def test_after_create
    assert_no_emails do
      assert_difference 'RecentActivity.count', 1 do
        assert_difference 'EventInvite.count', 1 do
          event = program_events(:birthday_party).event_invites.create!(:user => users(:ram), :status => EventInvite::Status::YES)
        end
      end
    end
    assert_equal RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT, RecentActivity.last.action_type
    assert_equal RecentActivityConstants::Target::ALL, RecentActivity.last.target
  end

  def test_after_update
    event = program_events(:birthday_party).event_invites.create!(:user => users(:ram), :status => EventInvite::Status::YES)
    assert_no_emails do
      assert_no_difference 'RecentActivity.count' do
        assert_no_difference 'EventInvite.count' do          
          event.status = EventInvite::Status::YES
          event.save!
        end
      end
    end

    assert_no_emails do
      assert_difference 'RecentActivity.count', 1 do
        assert_no_difference 'EventInvite.count' do          
          event.status = EventInvite::Status::NO
          event.save!
        end
      end
    end
    assert_equal RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT, RecentActivity.last.action_type
    assert_equal RecentActivityConstants::Target::ALL, RecentActivity.last.target
  end

end