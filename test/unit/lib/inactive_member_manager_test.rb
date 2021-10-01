require_relative './../../test_helper.rb'

class InactiveMemberManagerTest < ActiveSupport::TestCase

  def test_suspend
    count_pre = Member.where(state: Member::Status::SUSPENDED).count
    filepath = 'test/fixtures/files/test_file_inactive_member_manager_test.txt'
    InactiveMemberManager.suspend!(filepath)
    dummy_member = Member.where("email = ?", "ram@example.com").first
    assert_equal Member::Status::SUSPENDED, dummy_member.state
    dummy_member = Member.where("email = ?", "rahim@example.com").first
    assert_equal Member::Status::SUSPENDED, dummy_member.state
    dummy_member = Member.where("email = ?", "robert@example.com").first
    assert_equal Member::Status::SUSPENDED, dummy_member.state
    dummy_member = Member.where("email = ?", "mentrostud@example.com").first
    assert_equal Member::Status::ACTIVE, dummy_member.state
    assert_equal count_pre+4, Member.where(state: Member::Status::SUSPENDED).count
    filepath = "filenotpresent.txt"
    assert_equal "File not present", (assert_raises(RuntimeError) { InactiveMemberManager.suspend!(filepath) }).message
  end
end