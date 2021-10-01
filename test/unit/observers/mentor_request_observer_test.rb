require_relative './../../test_helper.rb'

class MentorRequestObserverTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_recent_activity
    student = users(:f_student)
    mentor = users(:f_mentor)
    program = programs(:albers)

    # Mentor Request creates a new recent activity
    request = nil
    assert_difference('RecentActivity.count') do
      request = create_mentor_request(:student => student, :mentor => mentor, :program => program)
    end
    activity = RecentActivity.last

    assert_equal student, activity.get_user(program)
    assert_equal request.id, activity.ref_obj_id
    assert_equal AbstractRequest.to_s, activity.ref_obj_type
    assert_equal [programs(:albers)], activity.programs
    assert_equal mentor.member, activity.for
    assert_equal RecentActivityConstants::Target::USER, activity.target


    # Change the request status, and check whether the recent activity is created
    assert_difference('RecentActivity.count') do
      request.mark_accepted!
    end
    assert_equal RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE, RecentActivity.last.action_type

    assert_difference('RecentActivity.count') do
      request.update_attributes(:response_text => "Sorry", :status => AbstractRequest::Status::REJECTED)
    end
    assert_equal RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION, RecentActivity.last.action_type
    
    assert_difference('RecentActivity.count') do
      request.update_attributes(:response_text => "Sorry", :status => AbstractRequest::Status::WITHDRAWN)
    end
    assert_equal RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL, RecentActivity.last.action_type
  end

  def test_no_recent_activity_moderated_groups
    make_member_of(:moderated_program, :f_student)
    assert_no_difference('RecentActivity.count') do
      create_mentor_request(:student => users(:f_student), :program => programs(:moderated_program))
    end
  end

  def test_no_recent_activity_unless_state_change_in_update
    assert_difference('RecentActivity.count') do
      @req = create_mentor_request(:student => users(:f_student), :mentor => users(:f_mentor), :program => programs(:albers))
    end
    

    assert_difference('RecentActivity.count') do
      @req.mark_accepted!
    end

    assert_no_difference('RecentActivity.count') do
      @req.update_attribute(:created_at , 1.day.ago)
    end

    assert_difference('RecentActivity.count', -2) do
      @req.destroy
    end
  end

  def test_mentor_requests_for_moderated_program
    make_member_of(:moderated_program, :f_student)

    assert_difference 'MentorRequest.count' do
      create_mentor_request(:student => users(:f_student), :program => programs(:moderated_program), :message => "First request")
    end
    assert_equal 1, users(:f_student).reload.sent_mentor_requests.count
    assert_equal "First request", users(:f_student).reload.sent_mentor_requests[0].message

    assert_difference 'MentorRequest.count' do
      create_mentor_request(:student => users(:f_student), :program => programs(:moderated_program), :message => "Second request")
    end
    assert_equal 2, users(:f_student).reload.sent_mentor_requests.count
    assert_equal "First request", users(:f_student).reload.sent_mentor_requests[0].message
    assert_equal "Second request", users(:f_student).reload.sent_mentor_requests[1].message
  end

  def test_no_recent_activity_on_accepting_moderated_groups
    make_member_of(:moderated_program, :f_student)
    m1 = create_mentor_request(:student => users(:f_student), :program => programs(:moderated_program))

    # No recent activity create on request update
    assert_no_difference('RecentActivity.count') do
      m1.status = AbstractRequest::Status::ACCEPTED
      m1.save!
    end
  end

  def test_no_recent_activity_but_send_email_to_student_on_rejecting_moderated_groups
    make_member_of(:moderated_program, :f_student)
    m1 = create_mentor_request(:student => users(:f_student), :program => programs(:moderated_program))
    ActionMailer::Base.deliveries.clear

    MentorRequest.expects(:delay).returns(MentorRequest).once
    # No recent activity create on request update
    assert_emails 1 do
      assert_no_difference('RecentActivity.count') do
        m1.update_attributes!(:rejector => users(:moderated_admin), :response_text => "Sorry", :status => AbstractRequest::Status::REJECTED)
      end
    end
    assert_equal [users(:f_student).email], ActionMailer::Base.deliveries.collect(&:to).flatten
  end

  def test_should_send_email_to_admin_in_moderated_program
    make_member_of(:moderated_program, :f_student)

    assert_emails 2 do
      assert_difference 'MentorRequest.count' do
        @mentor_request = create_mentor_request(
          :student => users(:f_student), :program => programs(:moderated_program))
      end
    end

    recipients = ActionMailer::Base.deliveries.collect(&:to).flatten
    assert_equal [users(:moderated_admin).email, users(:f_admin_moderated_program).email].sort, recipients.sort
  end

  def test_mark_accepted_should_not_withdraw_mentee_if_max_connections_for_mentee_not_reached_yet
    program = programs(:albers)
    student = users(:f_student)
    # set necessary attributes
    program_attributes = {
      max_pending_requests_for_mentee: 2,
      max_connections_for_mentee:      2,
    }
    program.update_attributes!(program_attributes)
    # 2 requests from student
    request1 = MentorRequest.create!(program: program, student: student, mentor: users(:f_mentor), message: "Hi")
    request2 = MentorRequest.create!(program: program, student: student, mentor: users(:f_mentor_student), message: "Hi")
    
    # check emails and push notifications
    MentorRequest.expects(:delay).returns(MentorRequest).once
    push_mock = mock()
    Push::Base.expects(:delay).returns(push_mock).once
    push_mock.expects(:notify).once

    assert_difference "RecentActivity.count", 1 do
      assert_emails 1 do
        assert request1.mark_accepted!, "mark_accepted! expected to success"
        [request1, request2].each(&:reload) # make sure we test actual data
        assert_equal AbstractRequest::Status::ACCEPTED, request1.status
        assert_equal AbstractRequest::Status::NOT_ANSWERED, request2.status
      end
    end
  end

  def test_mark_accepted_should_withdraw_mentee_if_max_connections_for_mentee_reached
    program = programs(:albers)
    student = users(:f_student)
    # set necessary attributes
    program_attributes = {
      max_pending_requests_for_mentee: 2,
      max_connections_for_mentee:      1,
    }
    program.update_attributes!(program_attributes)
    # 2 requests from student
    request1 = MentorRequest.create!(program: program, student: student, mentor: users(:f_mentor), message: "Hi")
    request2 = MentorRequest.create!(program: program, student: student, mentor: users(:f_mentor_student), message: "Hi")
    # check emails and push notifications
    MentorRequest.expects(:delay).returns(MentorRequest).once
    push_mock = mock()
    Push::Base.expects(:delay).returns(push_mock).once
    push_mock.expects(:notify).once

    assert_difference "RecentActivity.count", 1 do
      assert_emails 1 do
        assert request1.mark_accepted!, "mark_accepted! expected to success"
        [request1, request2].each(&:reload) # make sure we test actual data
        assert_equal AbstractRequest::Status::ACCEPTED, request1.status
        assert_equal AbstractRequest::Status::WITHDRAWN, request2.status
      end
    end
  end

  def test_assert_push_notifications_for_mentee_to_mentor_type_program
    program = programs(:albers)
    assert program.matching_by_mentee_alone?
    PushNotifier.expects(:push).once
    create_mentor_request(:student => users(:f_student), :mentor => users(:f_mentor), :program => programs(:albers))

    mentor_request = MentorRequest.last
    PushNotifier.expects(:push).once
    mentor_request.mark_accepted!

    PushNotifier.expects(:push).once
    mentor_request.update_attributes!(status: AbstractRequest::Status::REJECTED)

    PushNotifier.expects(:push).never
    mentor_request.update_attributes!(status: AbstractRequest::Status::WITHDRAWN)
  end

  def test_assert_push_notifications_for_mentee_to_admin_type_program
    make_member_of(:moderated_program, :f_student)
    program = programs(:moderated_program)
    assert program.matching_by_mentee_and_admin?

    PushNotifier.expects(:push).never
    assert_difference 'MentorRequest.count' do
      create_mentor_request(:student => users(:f_student), :program => program, :message => "First request")
    end

    mentor_request = MentorRequest.last
    PushNotifier.expects(:push).never
    mentor_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)

    PushNotifier.expects(:push).never
    mentor_request.update_attributes!(:rejector => users(:moderated_admin), :response_text => "Sorry", :status => AbstractRequest::Status::REJECTED)

    PushNotifier.expects(:push).never
    mentor_request.update_attributes!(status: AbstractRequest::Status::WITHDRAWN)
  end

  def test_observers_reindex_es
    DelayedEsDocument.expects(:delayed_update_es_document).once.with(MentorRequest, any_parameters)
    MentorRequest.expects(:send_mails).times(2)
    Push::Base.expects(:queued_notify).times(2)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(3).with(User, [3])
    mentor_request = create_mentor_request(student: users(:f_student), mentor: users(:f_mentor), program: programs(:albers))
    mentor_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
    mentor_request.destroy
  end
end
