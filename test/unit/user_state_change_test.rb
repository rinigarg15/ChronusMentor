require_relative './../test_helper.rb'

class UserStateChangeTest < ActiveSupport::TestCase
  def test_set_info
    user_state_change = UserStateChange.new
    hsh = {a: 1, b: 2}
    user_state_change.set_info(hsh)
    assert_equal hsh.to_yaml.gsub(/--- \n/, ""), user_state_change.info
  end

  def test_set_connection_membership_info
    user_state_change = UserStateChange.new
    hsh = {a: 1, b: 2}
    user_state_change.set_connection_membership_info(hsh)
    assert_equal hsh.to_yaml.gsub(/--- \n/, ""), user_state_change.connection_membership_info
  end

  def test_info_hash
    user_state_change = UserStateChange.new
    hsh = {a: 1, b: 2}
    user_state_change.set_info(hsh)
    assert_equal_hash(hsh, user_state_change.info_hash)
    hsh1 = {c: 3, d: 4}
    user_state_change.set_info(hsh1)
    assert_equal_hash(hsh, user_state_change.info_hash)
    assert_equal_hash(hsh1, user_state_change.info_hash(true))
  end

  def test_connection_membership_info_hash
    user_state_change = UserStateChange.new
    hsh = {a: 1, b: 2}
    user_state_change.set_connection_membership_info(hsh)
    assert_equal_hash(hsh, user_state_change.connection_membership_info_hash)
    hsh1 = {c: 3, d: 4}
    user_state_change.set_connection_membership_info(hsh1)
    assert_equal_hash(hsh, user_state_change.connection_membership_info_hash)
    assert_equal_hash(hsh1, user_state_change.connection_membership_info_hash(true))
  end

  def test_validations
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :user_id do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :date_id, nil, cascade: true do
        assert_raise_error_on_field ActiveRecord::RecordInvalid, :info, nil, cascade: true do
          UserStateChange.create!
        end
      end
    end
  end

  def test_info_extracters
    h = {:state => {:from => 'f_s', :to => 't_s'}, :role => {:from => 'f_r'}}
    cm_h = {:role => {:to_role => 'cm_t_r'}}
    usc = users(:f_admin).state_transitions.new(:date_id => 10000)
    usc.set_info(h)
    usc.set_connection_membership_info(cm_h)
    usc.save!
    assert_equal "f_s", usc.from_state
    assert_equal "t_s", usc.to_state
    assert_equal "f_r", usc.from_roles
    assert_equal [], usc.to_roles
    assert_equal "cm_t_r", usc.connection_membership_to_roles
    assert_nil usc.connection_membership_from_roles
  end

  def test_group_is_reindexed_after_save
    ElasticsearchIndexerJob.stubs(:new).at_least(2)
    Delayed::Job.stubs(:enqueue).at_least(2)
    usc = users(:f_admin).state_transitions.new(:date_id => 10000)
    h = {:state => {:from => 'f_s', :to => 't_s'}, :role => {:from => 'f_r'}}
    cm_h = {:role => {:from_role => 'cm_f_r'}}
    usc.set_info(h)
    usc.set_connection_membership_info(cm_h)
    usc.save!
  end
end