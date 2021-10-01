require_relative './../../test_helper.rb'

class ScrapExtensionsTest < ActiveSupport::TestCase
  include ScrapExtensions

  def test_get_unread_scraps_for_homepage
    users(:f_mentor).connection_memberships.destroy_all
    users(:f_mentor_student).connection_memberships.destroy_all
    groups(:group_2).mentors << [users(:f_mentor)]
    groups(:group_2).students << [users(:mkr_student), users(:f_mentor_student)]
    member = members(:f_mentor)
    member.received_messages.destroy_all

    m1 = create_scrap(:group => groups(:group_2), :sender => members(:f_mentor_student))
    m2 = nil
    time_traveller(3.days.ago) do
      m2 = create_scrap(:group => groups(:group_2), :sender => members(:f_mentor_student))
    end
    s1 = nil
    time_traveller(1.days.ago) do
      s1 = create_scrap(:group => groups(:group_2), :sender => members(:mkr_student))
    end
    s2=nil
    time_traveller(2.days.ago) do
      s2 = create_scrap(:group => groups(:group_2), :sender => members(:mkr_student))
    end

    assert_false AbstractMessageReceiver.find_by(message_id: m2.id, member_id: members(:f_mentor).id).read?
    messages_hash = get_scrap_messages_index([m1, m2, s1,s2].collect(&:id), members(:f_mentor), {:page => 1, :per_page => ScrapsController::SCRAPS_PER_PAGE, :is_admin_viewing_scraps => false, home_page: true})
    assert_equal_unordered messages_hash[:latest_messages].collect(&:root_id), [m1.id,s1.id]

    AbstractMessageReceiver.find_by(message_id: m1.id, member_id: members(:f_mentor).id).update_attributes(status: 1)
    messages_hash = get_scrap_messages_index([m1, m2, s1,s2].collect(&:id), members(:f_mentor), {:page => 1, :per_page => ScrapsController::SCRAPS_PER_PAGE, :is_admin_viewing_scraps => false, home_page: true})
    assert_equal_unordered messages_hash[:latest_messages].collect(&:root_id), [s1.id,s2.id]

    AbstractMessageReceiver.find_by(message_id: s1.id, member_id: members(:f_mentor).id).update_attributes(status: 1)
    messages_hash = get_scrap_messages_index([m1, m2, s1,s2].collect(&:id), members(:f_mentor), {:page => 1, :per_page => ScrapsController::SCRAPS_PER_PAGE, :is_admin_viewing_scraps => false, home_page: true})
    assert_equal_unordered messages_hash[:latest_messages].collect(&:root_id), [m2.id,s2.id]
    AbstractMessageReceiver.find_by(message_id: m2.id, member_id: members(:f_mentor).id).update_attributes(status: 1)
    AbstractMessageReceiver.find_by(message_id: s2.id, member_id: members(:f_mentor).id).update_attributes(status: 1)
    messages_hash = get_scrap_messages_index([m1, m2, s1,s2].collect(&:id), members(:f_mentor), {:page => 1, :per_page => ScrapsController::SCRAPS_PER_PAGE, :is_admin_viewing_scraps => false, home_page: true})
    assert_equal_unordered messages_hash[:latest_messages].collect(&:root_id), [m1.id,s1.id,s2.id]
  end

  def test_get_scrap_messages_index
    users(:f_mentor).connection_memberships.destroy_all
    users(:f_mentor_student).connection_memberships.destroy_all
    groups(:group_2).mentors << [users(:f_mentor)]
    groups(:group_2).students << [users(:mkr_student), users(:f_mentor_student)]
    member = members(:f_mentor)
    member.received_messages.destroy_all

    m1 = create_scrap(:group => groups(:group_2), :sender => members(:f_mentor_student))
    m2 = nil
    time_traveller(1.days.ago) do
      m2 = create_scrap(:group => groups(:group_2), :sender => members(:f_mentor_student))
    end
    s1 = nil
    time_traveller(1.days.from_now) do
      s1 = create_scrap(:group => groups(:group_2), :sender => members(:mkr_student))
    end
    m2_reply = nil
    time_traveller(2.days.from_now) do
      m2_reply = create_scrap(:group => groups(:group_2), :sender => member)
    end
    m2_reply.parent_id = m2_reply.root_id = m2.id
    m2_reply.save!

    member.reload
    assert_equal_unordered [m1, m2, s1].collect(&:id), member.received_messages.pluck(:root_id)
    messages_hash = get_scrap_messages_index([m1, m2, s1].collect(&:id), member, {:page => 1, :per_page => ScrapsController::SCRAPS_PER_PAGE, :is_admin_viewing_scraps => false})
    assert_equal messages_hash[:latest_messages].collect(&:root_id), [m2, s1, m1].collect(&:id)
    assert_equal_hash messages_hash[:messages_attachments], {m1.id => false, m2.id => false, s1.id => false}
    assert_equal messages_hash[:messages_last_created_at][m2.id].to_i, m2_reply.created_at.to_i

    # Ignoring the deleted messages
    m2.mark_deleted!(member)
    assert_equal_unordered [m1, s1].collect(&:id), member.received_messages.pluck(:root_id)
    messages_hash = get_scrap_messages_index([m1, s1].collect(&:id), member, {:page => 1, :per_page => ScrapsController::SCRAPS_PER_PAGE, :is_admin_viewing_scraps => false})
    assert_equal messages_hash[:latest_messages].collect(&:root_id), [s1, m1].collect(&:id)
    assert_equal_hash messages_hash[:messages_attachments], {m1.id => false, s1.id => false}
    assert_equal messages_hash[:messages_last_created_at][m1.id].to_i, m1.created_at.to_i
  end
end