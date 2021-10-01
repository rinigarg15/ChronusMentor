require_relative './../test_helper.rb'

class SessionTest < ActiveSupport::TestCase
  def test_member_is_set
    member = members(:f_student)
    mentor = members(:f_mentor)
    session_1 = ActiveRecord::SessionStore::Session.create!(:session_id => "session_id_1", :data => {"member_id" => member.id, "home_organization_id" => member.organization.id})
    session_2 = ActiveRecord::SessionStore::Session.create!(:session_id => "session_id_2", :data => {"member_id" => member.id, "home_organization_id" => member.organization.id})
    assert_equal session_1.member_id, member.id
    assert_equal session_2.member_id, member.id
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 2
    
    session_2.data["member_id"] = mentor.id
    session_2.save
    assert_equal session_2.member_id, mentor.id

    session_2.data["member_id"] = nil
    session_2.save
    assert_not_nil session_2.member_id

    session_3 = ActiveRecord::SessionStore::Session.create!(:session_id => "session_id_1", :data => {"home_organization_id" => member.organization.id})
    assert_nil session_3.member_id
  end
end