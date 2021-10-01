require_relative './../../test_helper.rb'

class Connection::MentorMembershipTest < ActiveSupport::TestCase
  def test_user_is_mentor
    assert_raise ActiveRecord::RecordInvalid do
      m = fetch_connection_membership(:mentor, groups(:mygroup))
      m.user = users(:student_3)
      m.save!
    end
  end
end
