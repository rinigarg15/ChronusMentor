require_relative './../../test_helper.rb'

class Connection::MenteeMembershipTest < ActiveSupport::TestCase
  def test_user_is_student
    assert_raise ActiveRecord::RecordInvalid do
      m = fetch_connection_membership(:student, groups(:mygroup))
      m.user = users(:mentor_2)
      m.save!
    end
  end
end
