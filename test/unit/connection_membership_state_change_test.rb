require_relative './../test_helper.rb'

class ConnectionMembershipStateChangeTest < ActiveSupport::TestCase
  def test_set_info
    membership_state_change = ConnectionMembershipStateChange.new
    hsh = {a: 1, b: 2}
    membership_state_change.set_info(hsh)
    assert_equal hsh.to_yaml.gsub(/--- \n/, ""), membership_state_change.info
  end

  def test_info_hash
    membership_state_change = ConnectionMembershipStateChange.new
    hsh = {a: 1, b: 2}
    membership_state_change.set_info(hsh)
    assert_equal_hash hsh, membership_state_change.info_hash
    hsh1 = {c: 3, d: 4}
    membership_state_change.set_info(hsh1)
    assert_equal_hash hsh, membership_state_change.info_hash
    assert_equal_hash hsh1, membership_state_change.info_hash(true)
  end

  def test_validations
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :connection_membership_id do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :user_id, nil, cascade: true do
        assert_raise_error_on_field ActiveRecord::RecordInvalid, :group_id, nil, cascade: true do
          assert_raise_error_on_field ActiveRecord::RecordInvalid, :date_id, nil, cascade: true do
            assert_raise_error_on_field ActiveRecord::RecordInvalid, :info, nil, cascade: true do
              ConnectionMembershipStateChange.create!
            end
          end
        end
      end
    end
  end

end