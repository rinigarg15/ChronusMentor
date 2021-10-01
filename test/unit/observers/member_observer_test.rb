require_relative './../../test_helper.rb'

class MemberObserverTest < ActiveSupport::TestCase

  def test_deliver_email_on_email_change
    member = members(:f_mentor)
    email_changer = members(:f_admin)
    old_email = 'robert@example.com'
    new_email = 'robert@chronus.com'
    assert_equal old_email, member.email

    Member.expects(:send_email_change_notification).once.with(member.id, new_email, old_email, email_changer.id)
    member.email = new_email
    member.email_changer = email_changer
    member.save!
    assert_equal new_email, member.reload.email
  end

  def test_before_create_member_generate_api_key
    member = create_member
    assert member.calendar_api_key.present?
  end

  #deletion of member should not result in deletion of corresponding
  #received and sent messages
  def test_after_destroy
    mem = members(:f_mentor)
    admin_message = create_admin_message(:sender => mem, :receiver => members(:f_admin))
    assert_equal 1, AdminMessage.where(sender_id: mem.id).size
    assert_equal 1, Message.where(sender_id: mem.id).size
    assert_equal 4, Scrap.where(sender_id: mem.id).size
    sent_messages = AbstractMessage.where(sender_id: mem.id)
    assert_equal 6, sent_messages.size
    assert_equal mem.id, sent_messages[0].sender_id

    message_receivers = AbstractMessageReceiver.where(member_id: mem.id)
    assert_equal 4, message_receivers.size
    assert_no_difference "Message.count" do
      assert_difference "AbstractMessageReceiver.count", -4 do
        assert_difference "Member.count", -1 do
          mem.users.destroy_all
          mem.destroy
        end
      end
    end
    sent_messages_by_id = AbstractMessage.where(sender_id: mem.id)
    assert_blank sent_messages_by_id
    removed_user_msg_count = AbstractMessage.where(sender_name: "Removed User").size
    assert_equal sent_messages.size, removed_user_msg_count
  end

  def test_before_save
    member = members(:f_mentor)
    current_updated_time = member.password_updated_at
    chronus_auth = member.organization.chronus_auth
    chronus_auth.disable!
    member.crypted_password = nil
    member.save!
    member.login_identifiers.destroy_all

    assert_difference "member.login_identifiers.where(auth_config_id: chronus_auth.id).count" do
      member.password = "sample123"
      member.password_confirmation = "sample123"
      member.save!
    end
    assert_no_difference "member.login_identifiers.where(auth_config_id: chronus_auth.id).count" do
      member.password = "123sample"
      member.password_confirmation = "123sample"
      member.save!
    end
    latest_time = member.password_updated_at
    assert_not_equal current_updated_time.strftime("%d, %b %Y at %I:%M %p"), latest_time.strftime("%d, %b %Y at %I:%M %p")

    member.reload
    member.email = "sample@chronus.com"
    member.save!
    assert_equal latest_time.strftime("%d, %b %Y at %I:%M %p"), member.password_updated_at.strftime("%d, %b %Y at %I:%M %p")
  end

  def test_after_save
    member = members(:rahim)
    manager3 = managers(:manager_3)
    manager2 = managers(:manager_2)
    assert_equal manager3.email, "userrahim@example.com"
    assert_equal manager3.member_id, member.id

    manager2.update_attributes!(email: "newrahim@example.com")
    assert_nil manager2.member_id

    member.update_attributes!(email: "newrahim@example.com")
    assert_equal manager2.reload.member_id, member.id
    assert_nil manager3.reload.member_id
  end

  def test_after_save_es_reindexing
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(MentorRequest, 15.times.map { |i| mentor_requests("mentor_request_#{i}").id } )
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Meeting, meetings(:f_mentor_mkr_student, :f_mentor_mkr_student_daily_meeting, :upcoming_calendar_meeting, :past_calendar_meeting, :completed_calendar_meeting, :cancelled_calendar_meeting).map(&:id))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Topic, [])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(ProjectRequest, [])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(QaQuestion, qa_questions(:what, :why).map(&:id) + 15.times.map { |i| qa_questions("qa_question_#{i + 100}").id } + [qa_questions(:question_for_stopwords_test).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Article, [articles(:kangaroo).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(ThreeSixty::SurveyAssessee, [3, 15])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(5).with(User, users(:f_mentor, :f_mentor_nwen_student, :f_mentor_pbe, :f_onetime_mode_mentor).map(&:id))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, groups(:proposed_group_3, :proposed_group_4, :rejected_group_2, :withdrawn_group_1, :mygroup, :group_nwen, :group_pbe, :proposed_group_3, :proposed_group_4, :rejected_group_2, :withdrawn_group_1).map(&:id))

    member = members(:f_mentor)
    member.update_attribute(:first_name, "First Name") # should invoke dj for first_name changed
    member.update_attribute(:email, "test@email.com") # should only invoke user bulk update
    member.update_attribute(:organization_id, 54) # 1 User Index DJ
    member.update_attribute(:state, Member::Status::SUSPENDED) # 1 User Index DJ
    member.update_attribute(:terms_and_conditions_accepted, false) # 1 User Index DJ
    member.update_attribute(:api_key, "random") # No DJ
  end

  def test_after_destroy_es_reindexing
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Meeting, [])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(User, [users(:nch_mentor).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Member, [members(:nch_mentor).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(QaQuestion, [qa_questions(:nch_why).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(User, [])
    members(:nch_mentor).destroy
  end

  def test_destroy_pending_membership_requests_on_suspension
    member = members(:f_mentor)
    program = programs(:no_mentor_request_program)
    membership_request_1 = create_membership_request(program: program, member: member, roles: [RoleConstants::MENTOR_NAME])
    membership_request_2 = create_membership_request(program: program, member: member, roles: [RoleConstants::STUDENT_NAME])
    membership_request_2.update_attributes!(status: MembershipRequest::Status::REJECTED, response_text: "R", admin: users(:no_mreq_admin))
    assert_difference "member.membership_requests.count", -1 do
      member.suspend!(members(:f_admin), "Suspension Reason")
    end
  end
end