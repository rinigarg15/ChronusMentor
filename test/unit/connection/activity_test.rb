require_relative './../../test_helper.rb'

class Connection::ActivityTest < ActiveSupport::TestCase
  def test_belongs_to_group_and_recent_activity
    assert_difference 'Connection::Activity.count' do
      assert_difference 'RecentActivity.count' do
        create_scrap(group: groups(:mygroup))
      end
    end

    act = RecentActivity.last
    Connection::Activity.destroy_all
    assert_difference 'Connection::Activity.count' do
      @conn_act = Connection::Activity.create!(
        group: groups(:mygroup), recent_activity: act)
    end

    assert_equal groups(:mygroup), @conn_act.group
    assert_equal act, @conn_act.recent_activity
  end

  def test_group_and_recent_activity_are_required
    assert_no_difference 'Connection::Activity.count' do
      assert_multiple_errors([{field: :group}, {field: :recent_activity}]) do
        Connection::Activity.create!
      end
    end
  end

  def test_recent_acitivity_supported_types
    ra =  RecentActivity.create!(
      programs: [programs(:albers)],
      action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      ref_obj: programs(:albers).announcements.first,
      target: RecentActivityConstants::Target::MENTORS
    )

    assert_no_difference 'Connection::Activity.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :recent_activity) do
        Connection::Activity.create!(
          group: groups(:mygroup), recent_activity: ra
        )
      end
    end
  end

  def test_new_admin_activity_should_update_group_last_activity_at_but_not_last_member_activity_at
    group = groups(:mygroup)

    Timecop.freeze(DateTime.now) do
      group.update_attribute(:last_activity_at, 2.days.ago)
      group.update_attribute(:last_member_activity_at, 2.days.ago)

      assert_difference 'Connection::Activity.count' do
        assert_difference 'RecentActivity.count' do
          group.update_members(group.mentors.clone + [users(:mentor_2)], group.students.clone, users(:f_admin))
        end
      end
      assert_equal DateTime.now, group.reload.last_activity_at
      assert_equal 2.days.ago, group.last_member_activity_at
    end
  end
end