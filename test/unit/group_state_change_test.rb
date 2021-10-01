require_relative './../test_helper.rb'

class GroupStateChangeTest < ActiveSupport::TestCase

  def test_presence_validations
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :group_id do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :date_id, nil, cascade: true do
        assert_raise_error_on_field ActiveRecord::RecordInvalid, :to_state, nil, cascade: true do
          GroupStateChange.create!
        end
      end
    end
  end

  def test_to_and_from_state_are_valid
    gs = GroupStateChange.first
    gs.update_attributes(:from_state => 999, :to_state => 1000)
    assert_equal ["is not included in the list"], gs.errors[:from_state]
    assert_equal ["is not included in the list"], gs.errors[:to_state]
  end

  def test_group_is_reindexed_after_save
    group = groups(:mygroup)
    ElasticsearchIndexerJob.stubs(:new).at_least(2)
    Delayed::Job.stubs(:enqueue).at_least(2)
    group.state_changes.create(:date_id => 10000, :from_state => nil, :to_state => Group::Status::ACTIVE)
  end
end