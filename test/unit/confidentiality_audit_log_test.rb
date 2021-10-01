require_relative './../test_helper.rb'

class ConfidentialityAuditLogTest < ActiveSupport::TestCase
  def test_audit_log_belongs_to_program_user_and_group
    audit_log = nil
    assert_nothing_raised do
      ConfidentialityAuditLog.create!(:program_id => programs(:albers).id, :user_id => users(:f_admin).id, :reason =>"This is a reason", :group_id => groups(:mygroup).id)
    end
    audit_log = ConfidentialityAuditLog.last
    assert_equal programs(:albers), audit_log.program
    assert_equal users(:f_admin), audit_log.user
    assert_equal "This is a reason", audit_log.reason
    assert_equal groups(:mygroup), audit_log.group
  end

  def test_audit_log_creation_without_args_must_fail
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ConfidentialityAuditLog.create!
    end

    assert_match(/Program can't be blank/, e.message)
    assert_match(/User can't be blank/, e.message)
    assert_match(/Reason can't be blank/, e.message)
    assert_match(/Group can't be blank/, e.message)
  end

  def test_user_privilege
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :user,
      'does not have the privileges to perform this action') do
      ConfidentialityAuditLog.create! :user => users(:f_student)
    end
  end
end
