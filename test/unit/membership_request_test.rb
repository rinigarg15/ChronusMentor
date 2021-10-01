require_relative './../test_helper.rb'

class MembershipRequestTest < ActiveSupport::TestCase
  def test_validates_presence
    membership_request = MembershipRequest.new(program: programs(:albers))
    assert_false membership_request.valid?
    assert_equal ["can't be blank", "is not a valid email address."], membership_request.errors[:email]
    assert_equal ["can't be blank"], membership_request.errors[:member]
    assert_equal ["can't be blank"], membership_request.errors[:last_name]
    assert_equal ["can't be blank"], membership_request.errors[:roles]
  end

  def test_validates_email_and_roles
    e = assert_raise(ActiveRecord::RecordInvalid) do
      MembershipRequest.create!(
        first_name: "Appy",
        last_name: "Chugh",
        email: "invalid",
        program: programs(:albers),
        member: members(:f_mentor)
      )
    end
    assert_match(/Email is not a valid email address/, e.message)
    assert_match(/Roles can't be blank/, e.message)
  end

  def test_accepted
    membership_request = create_membership_request
    assert membership_request.pending?
    assert_false membership_request.answered?

    ChronusMailer.expects(:membership_request_accepted).once.returns(stub(:deliver_now))
    membership_request.update_attributes({
      status: MembershipRequest::Status::ACCEPTED,
      response_text: "Reason",
      accepted_as: RoleConstants::STUDENT_NAME,
      admin: users(:f_admin)
    })
    assert_equal MembershipRequest::Status::ACCEPTED, membership_request.reload.status
    assert membership_request.accepted?
    assert membership_request.answered?
    assert_equal [RoleConstants::STUDENT_NAME], membership_request.accepted_role_names
  end

  def test_send_membership_request_accepted_notification
    membership_request = create_membership_request

    assert_false membership_request.answered?
    assert_no_emails do
      MembershipRequest.send_membership_request_accepted_notification(membership_request.id)
    end

    membership_request.update_attributes!({ accepted_as: RoleConstants::STUDENT_NAME, status: MembershipRequest::Status::ACCEPTED, admin: users(:f_admin) } )
    assert_emails do
      MembershipRequest.send_membership_request_accepted_notification(membership_request.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [members(:f_mentor).email], email.to
    assert_equal "Your membership request has been accepted!", email.subject

    membership_request.update_column(:status, MembershipRequest::Status::ACCEPTED)
    membership_request.user.update_column(:state, User::Status::SUSPENDED)
    assert_no_emails do
      MembershipRequest.send_membership_request_accepted_notification(membership_request.id)
    end

    membership_request.user.update_column(:state, User::Status::ACTIVE)
    membership_request.update_column(:joined_directly, true)
    assert_no_emails do
      MembershipRequest.send_membership_request_accepted_notification(membership_request.id)
    end

    membership_request.update_column(:joined_directly, false)
    assert_no_emails do
      MembershipRequest.send_membership_request_accepted_notification(0)
    end
  end

  def test_send_membership_request_not_accepted_notification
    membership_request = create_membership_request

    assert_false membership_request.rejected?
    assert_no_emails do
      MembershipRequest.send_membership_request_not_accepted_notification(0)
    end

    membership_request.update_attributes({status: MembershipRequest::Status::REJECTED, response_text: "Reason", admin: users(:f_admin) })
    assert membership_request.rejected?
    assert_emails 1 do
      MembershipRequest.send_membership_request_not_accepted_notification(membership_request.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [members(:f_mentor).email], email.to
    assert_equal "Your membership request has been declined", email.subject

    assert_no_emails do
      MembershipRequest.send_membership_request_not_accepted_notification(0)
    end
  end

  def test_accepted_role_names
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert membership_request.pending?
    assert_false membership_request.answered?

    membership_request.admin = users(:f_admin)
    membership_request.status = MembershipRequest::Status::ACCEPTED
    membership_request.accepted_role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    assert_equal "#{RoleConstants::MENTOR_NAME},#{RoleConstants::STUDENT_NAME}", membership_request.accepted_as
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], membership_request.accepted_role_names
  end

  def test_accepted_as_str
    program = programs(:albers)
    program.find_role(RoleConstants::MENTOR_NAME).customized_term.update_attribute(:term, "book")
    program.find_role(RoleConstants::STUDENT_NAME).customized_term.update_attribute(:term, "car")
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert membership_request.pending?
    assert_false membership_request.answered?

    membership_request.admin = users(:f_admin)
    membership_request.status = MembershipRequest::Status::ACCEPTED
    membership_request.accepted_role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    assert_equal "book and car", membership_request.accepted_as_str
    membership_request.accepted_role_names = [RoleConstants::MENTOR_NAME]
    assert_equal "book", membership_request.accepted_as_str
  end

  def test_rejected
    membership_request = create_membership_request
    assert membership_request.pending?
    assert_false membership_request.answered?

    membership_request.update_attributes({
      status: MembershipRequest::Status::REJECTED,
      response_text: "Reason",
      admin: users(:f_admin)
    })
    assert_equal MembershipRequest::Status::REJECTED, membership_request.reload.status
    assert membership_request.rejected?
    assert membership_request.answered?
    assert_nil membership_request.accepted_role_names
  end

  def test_should_create_membership_request_with_answer
    member = members(:f_mentor)
    member_profile_answers_count = member.profile_answers.count
    membership_request = nil
    assert_difference "MembershipRequest.count" do
      membership_request = MembershipRequest.create!(
        first_name: member.first_name,
        last_name: member.last_name,
        email: "#{member.email} ",
        program: programs(:albers),
        role_names: [RoleConstants::MENTOR_NAME],
        member: member
      )
      membership_question = create_membership_profile_question
      member.profile_answers.create!(
        profile_question: membership_question,
        answer_text: "To teach")
    end

    assert_equal "Good unique name", membership_request.name
    assert_equal "robert@example.com", membership_request.email
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert membership_request.for_single_role?
    assert_equal programs(:albers), membership_request.program
    assert_equal (member_profile_answers_count + 1), membership_request.profile_answers.count
  end

  def test_should_create_student_request
    member = members(:f_student)
    membership_request = nil
    assert_equal 0, member.profile_answers.count
    assert_difference "MembershipRequest.count" do
      membership_request = MembershipRequest.create!(
        first_name: member.first_name,
        last_name: member.last_name,
        email: "#{member.email} ",
        program: programs(:albers),
        role_names: [RoleConstants::STUDENT_NAME],
        member: member
      )
      membership_question = create_membership_profile_question(role_names: [RoleConstants::STUDENT_NAME])
      member.profile_answers.create!(
        profile_question: membership_question,
        answer_text: "To learn")
    end

    assert_equal "student example", membership_request.name
    assert_equal "rahim@example.com", membership_request.email
    assert_equal [RoleConstants::STUDENT_NAME], membership_request.role_names
    assert membership_request.for_single_role?
    assert_equal programs(:albers), membership_request.program
    assert_equal 1, membership_request.profile_answers.count
  end

  def test_membership_request_recent_scope
    MembershipRequest.last(5).each { |membership_request| membership_request.update_attribute(:created_at, 10.days.from_now) }
    time_traveller(9.days.from_now) do
      assert_equal 5, MembershipRequest.recent(1.week.ago).count
    end
  end

  def test_membership_request_scopes
    membership_requests = MembershipRequest.where(member_id: [members(:student_1).id, members(:student_5).id])
    a = membership_requests.find_by(member_id: members(:student_1).id)
    a.update_attribute(:last_name, "a_example")
    b = membership_requests.find_by(member_id: members(:student_5).id)
    b.update_attribute(:last_name, "b_example")

    assert_equal [a, b], membership_requests.by_name_asc
    assert_equal [b, a], membership_requests.by_name_desc
    assert_equal [b, a], membership_requests.by_time_desc
    assert_equal [a, b], membership_requests.by_time_asc
    assert_equal [a, b], membership_requests.order_by('id', 'asc')
    assert_equal [b, a], membership_requests.order_by('id', 'desc')
    assert_equal [a, b], membership_requests.order_by('email', 'asc')
    assert_equal [b, a], membership_requests.order_by('email', 'desc')
  end

  def test_status_scopes
    assert_equal 12, MembershipRequest.pending.size
    assert_equal 0, MembershipRequest.accepted.size
    assert_equal 0 , MembershipRequest.rejected.size

    accepted_request, rejected_request = MembershipRequest.last(2)
    accepted_request.status = MembershipRequest::Status::ACCEPTED
    accepted_request.skip_observer = true
    accepted_request.save(validate: false)
    rejected_request.status = MembershipRequest::Status::REJECTED
    rejected_request.skip_observer = true
    rejected_request.save(validate: false)
    assert_equal 10, MembershipRequest.pending.size
    assert_equal 1, MembershipRequest.accepted.size
    assert_equal 1 , MembershipRequest.rejected.size
  end

  def test_membership_request_should_have_response_when_rejected
    membership_request = MembershipRequest.first
    assert_false membership_request.rejected?
    assert membership_request.valid?

    membership_request.status = MembershipRequest::Status::REJECTED
    membership_request.admin = users(:f_admin)
    assert_false membership_request.valid?
    membership_request.response_text = "Sorry I cant accept your request"
    assert membership_request.valid?
  end

  def test_check_accepted_as
    membership_request = MembershipRequest.find_by(member_id: members(:student_1).id)
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :accepted_as, "is not among the requested roles") do
      membership_request.update_attributes!({ accepted_as: RoleConstants::STUDENT_NAME, status: MembershipRequest::Status::ACCEPTED, admin: users(:f_admin) } )
    end

    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :accepted_as, "cannot be present when rejected") do
      membership_request.update_attributes!({ accepted_as: RoleConstants::STUDENT_NAME, status: MembershipRequest::Status::REJECTED, admin: users(:f_admin), response_text: "R" } )
    end
  end

  def test_should_accept_membership_request_for_any_of_requested_roles
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], program: programs(:ceg), member: members(:f_student))
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], membership_request.role_names
    assert_difference("User.count", 1) do
      membership_request.update_attributes!({ accepted_as: RoleConstants::MENTOR_NAME, status: MembershipRequest::Status::ACCEPTED, admin: users(:f_admin) } )
    end
  end

  def test_has_many_profile_answers
    membership_request = MembershipRequest.first
    member = membership_request.member
    assert membership_request.profile_answers.empty?

    question_1 = create_question(question_type: ProfileQuestion::Type::STRING)
    answer_1 = member.profile_answers.create!(profile_question: question_1, answer_text: "1")
    question_2 = create_question(question_type: ProfileQuestion::Type::STRING)
    answer_2 = member.profile_answers.create!(profile_question: question_2, answer_text: "2")
    assert_equal [answer_1, answer_2], membership_request.reload.profile_answers
  end

  def test_create_from_params_failure
    question_1 = create_membership_profile_question
    question_2 = create_membership_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_choices: ["get", "set", "go"])
    assert question_1.profile_answers.empty?
    assert question_2.profile_answers.empty?

    member = members(:student_10)
    assert_no_difference 'ProfileAnswer.count' do
      MembershipRequest.create_from_params(programs(:albers),
        { roles: [RoleConstants::MENTOR_NAME], first_name: member.first_name, last_name: member.last_name, email: member.email }, member)
    end
    assert question_1.profile_answers.reload.empty?
    assert question_2.profile_answers.reload.empty?
  end

  def test_create_from_params_success
    member = members(:student_10)
    membership_request = nil
    program = programs(:albers)
    assert_difference "ProfileAnswer.count", 0 do
      assert_difference "MembershipRequest.count" do
        membership_request = MembershipRequest.create_from_params(program,
          { roles: [RoleConstants::MENTOR_NAME], first_name: member.first_name, last_name: member.last_name, email: member.email }, member)
      end
    end
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert_equal member, membership_request.member
    assert_equal program, membership_request.program
  end

  def test_header_for_exporting
    create_membership_profile_question(question_text: 'Age', role_names: [RoleConstants::STUDENT_NAME])
    create_membership_profile_question(question_text: 'Country', role_names: [RoleConstants::MENTOR_NAME])
    create_membership_profile_question(question_text: 'Height', role_names: [RoleConstants::STUDENT_NAME])
    create_membership_profile_question(question_text: 'Weight', role_names: [RoleConstants::STUDENT_NAME])
    create_membership_profile_question(question_text: 'Age', role_names: [RoleConstants::MENTOR_NAME])

    # mentor question gets precedence over the student question when both are similar.
    # Hence, the latter 'Age' is picked up as the header.
    assert_equal ["First name", "Last name", "Email", "Join As", "Sent", "Status", 'Age', 'Country', 'Height', 'Weight'],
      MembershipRequest.header_for_exporting(programs(:albers))
  end

  def test_header_for_exporting_status_wise
    create_membership_profile_question(question_text: 'Age', role_names: [RoleConstants::STUDENT_NAME])
    create_membership_profile_question(question_text: 'Country', role_names: [RoleConstants::MENTOR_NAME])
    create_membership_profile_question(question_text: 'Height', role_names: [RoleConstants::STUDENT_NAME])
    create_membership_profile_question(question_text: 'Weight', role_names: [RoleConstants::STUDENT_NAME])
    create_membership_profile_question(question_text: 'Age', role_names: [RoleConstants::MENTOR_NAME])

    # mentor question gets precedence over the student question when both are similar.
    # Hence, the latter 'Age' is picked up as the header.
    assert_equal ["First name", "Last name", "Email", "Join As", "Sent", "Status", 'Age', 'Country', 'Height', 'Weight'],
      MembershipRequest.header_for_exporting(programs(:albers))
    assert_equal ["First name", "Last name", "Email", "Join As", "Sent", "Status", 'Age', 'Country', 'Height', 'Weight'],
      MembershipRequest.header_for_exporting(programs(:albers), MembershipRequest::FilterStatus::PENDING)
    assert_equal ["First name", "Last name", "Email", "Join As", "Sent", "Status", "Accepted By", "Accepted on", "Age", "Country", "Height", "Weight"], 
      MembershipRequest.header_for_exporting(programs(:albers), MembershipRequest::FilterStatus::ACCEPTED)
    assert_equal ["First name", "Last name", "Email", "Join As", "Sent", "Status", "Rejected By", "Rejected on", "Reason for rejection", "Age", "Country", "Height", "Weight"], 
      MembershipRequest.header_for_exporting(programs(:albers), MembershipRequest::FilterStatus::REJECTED)
  end

  def test_data_for_exporting
    program = programs(:albers)
    question_1 = create_membership_profile_question(question_text: "Age", role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    question_2 = create_membership_profile_question(question_text: "Country", role_names: [RoleConstants::MENTOR_NAME])
    question_3 = create_membership_profile_question(question_text: "Height", role_names: [RoleConstants::STUDENT_NAME])
    question_4 = create_membership_profile_question(question_text: "Weight", role_names: [RoleConstants::STUDENT_NAME])
    question_5 = create_membership_profile_question(question_text: "Resume", role_names: [RoleConstants::STUDENT_NAME], question_type: ProfileQuestion::Type::FILE)
    question_6 = create_membership_profile_question(question_text: "What are your hobbies?", role_names: [RoleConstants::STUDENT_NAME], question_type: ProfileQuestion::Type::MULTI_CHOICE, question_choices: ["Stand", "Walk"])

    GlobalizationUtils.run_in_locale(:de) do
      question_6.question_choices.first.update_attributes!(:text => "Supporter")
      question_6.question_choices.last.update_attributes!(:text => "Marcher")
    end

    membership_request_1 = MembershipRequest.find_by(member_id: members(:student_1).id)
    membership_request_2 = MembershipRequest.find_by(member_id: members(:student_2).id)
    membership_request_3 = MembershipRequest.find_by(member_id: members(:mentor_7).id)
    membership_request_4 = MembershipRequest.find_by(member_id: members(:student_4).id)
    ProfileAnswer.create(ref_obj: membership_request_1.member, answer_text: "35", profile_question_id: question_1.id)
    ProfileAnswer.create(ref_obj: membership_request_1.member, answer_text: "170 cms", profile_question_id: question_3.id)
    ProfileAnswer.create(ref_obj: membership_request_2.member, answer_text: "165 cms", profile_question_id: question_3.id)
    ProfileAnswer.create(ref_obj: membership_request_2.member, answer_text: "70 Kgs", profile_question_id: question_4.id)
    ProfileAnswer.create(ref_obj: membership_request_2.member, answer_value: {answer_text: [" Walk"], question: question_6}, profile_question_id: question_6.id)
    profile_answer = ProfileAnswer.new(ref_obj: membership_request_2.member, profile_question_id: question_5.id)
    profile_answer.answer_value = fixture_file_upload(File.join("files", "some_file.txt"))
    profile_answer.save!
    ProfileAnswer.create(ref_obj: membership_request_3.member, answer_text: "35", profile_question_id: question_1.id)
    ProfileAnswer.create(ref_obj: membership_request_3.member, answer_text: "India", profile_question_id: question_2.id)
    ProfileAnswer.create(ref_obj: membership_request_4.member, answer_text: "25", profile_question_id: question_1.id)

    membership_request_2.status = MembershipRequest::Status::REJECTED
    membership_request_2.admin = users(:ram)
    membership_request_2.response_text = "can't accept"
    membership_request_2.save!
    membership_request_4.accepted_as = RoleConstants::MENTOR_NAME
    membership_request_4.status = MembershipRequest::Status::ACCEPTED
    membership_request_4.admin = users(:f_admin)
    membership_request_4.save!

    roles("#{program.id}_#{RoleConstants::MENTOR_NAME}").customized_term.update_attribute(:term, "Expert")
    roles("#{program.id}_#{RoleConstants::STUDENT_NAME}").customized_term.update_attribute(:term, "Protege")

    assert_equal [
      [membership_request_1.first_name, membership_request_1.last_name, membership_request_1.email, "Expert", membership_request_1.created_at.strftime("%B %d, %Y at %I:%M %p"), "Pending", "35", nil, "170 cms", nil, nil, nil],
      [membership_request_2.first_name, membership_request_2.last_name, membership_request_2.email, "Expert", membership_request_2.created_at.strftime("%B %d, %Y at %I:%M %p"), "Rejected", users(:ram).name, membership_request_2.closed_at.strftime("%B %d, %Y at %I:%M %p"), "can't accept", nil, nil, "165 cms", "70 Kgs", "some_file.txt", "Walk"],
      [membership_request_3.first_name, membership_request_3.last_name, membership_request_3.email, "Protege", membership_request_3.created_at.strftime("%B %d, %Y at %I:%M %p"), "Pending", "35", "India", nil, nil, nil, nil]
      ],
      MembershipRequest.data_for_exporting(programs(:albers), [membership_request_1, membership_request_2, membership_request_3])

    GlobalizationUtils.run_in_locale(:de) do
      value = MembershipRequest.data_for_exporting(programs(:albers), [membership_request_2])
      assert_equal "Supporter, Marcher", value.first.last
    end

    assert_equal [[membership_request_4.first_name, membership_request_4.last_name, membership_request_4.email, "Expert", membership_request_4.created_at.strftime("%B %d, %Y at %I:%M %p"), "Accepted as Expert", users(:f_admin).name, membership_request_4.closed_at.strftime("%B %d, %Y at %I:%M %p"), "25", nil, nil, nil, nil, nil]],
      MembershipRequest.data_for_exporting(programs(:albers), [membership_request_4])
  end

  def test_for_mentor_role
    membership_request = MembershipRequest.find_by(member_id: members(:mentor_7).id)
    assert_equal [RoleConstants::STUDENT_NAME], membership_request.role_names
    assert_false membership_request.for_mentor_role?

    membership_request = MembershipRequest.find_by(member_id: members(:student_1).id)
    assert membership_request.for_mentor_role?

    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert membership_request.for_mentor_role?
  end

  def test_validate_uniqueness_of_request_pending_case
    membership_request = nil
    student_member = members(:f_student)
    assert_difference('MembershipRequest.count', 1) do
      membership_request = MembershipRequest.create!(
        program: programs(:albers),
        first_name: student_member.first_name,
        last_name: student_member.last_name,
        email: student_member.email,
        role_names: [RoleConstants::MENTOR_NAME],
        member: student_member
      )
    end
    assert membership_request.pending?

    e = assert_raise(ActiveRecord::RecordInvalid) do
      MembershipRequest.create!(
        program: programs(:albers),
        first_name: student_member.first_name,
        last_name: student_member.last_name,
        email: student_member.email,
        role_names: [RoleConstants::MENTOR_NAME],
        member: student_member
      )
    end
    assert_match "You already have a pending request.", e.message
    e = assert_raise(ActiveRecord::RecordInvalid) do
      MembershipRequest.create!(
        program: programs(:albers),
        first_name: student_member.first_name,
        last_name: student_member.last_name,
        email: student_member.email,
        role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
        member: student_member
      )
    end
    assert_match "You already have a pending request.", e.message
  end

  def test_validate_uniqueness_of_request_rejected_case
    membership_request = MembershipRequest.first
    membership_request.update_attributes({
      status: MembershipRequest::Status::REJECTED,
      response_text: "Reason",
      admin: users(:f_admin) } )
    assert membership_request.reload.rejected?

    assert_nothing_raised do
      membership_request = MembershipRequest.create!(
        program: programs(:albers),
        first_name: membership_request.first_name,
        last_name: membership_request.last_name,
        email: membership_request.email,
        role_names: membership_request.role_names,
        member_id: membership_request.member_id
      )
    end

    membership_request.update_attributes({
      status: MembershipRequest::Status::REJECTED,
      response_text: "Reason",
      admin: users(:f_admin) } )
    assert membership_request.reload.rejected?

    assert_nothing_raised do
      membership_request = MembershipRequest.create!(
        program: programs(:albers),
        first_name: membership_request.first_name,
        last_name: membership_request.last_name,
        email: membership_request.email,
        role_names: membership_request.role_names,
        member_id: membership_request.member_id
      )
    end
  end

  def test_generate_and_email_report_should_call_run_in_locale
    reqs = programs(:albers).membership_requests.not_joined_directly.pending.by_time_desc
    admin = programs(:albers).admin_users.first

    GlobalizationUtils.expects(:run_in_locale).with(:en).once
    MembershipRequest.generate_and_email_report(admin, [reqs.first.id], "pending", "by_time_desc", :pdf)

    # Test the default parameter
    run_in_another_locale(:'fr-CA') do
      GlobalizationUtils.expects(:run_in_locale).with(:'fr-CA').once
      MembershipRequest.generate_and_email_report(admin, [reqs.first.id], "pending", "by_time_desc", :pdf)
    end

    # Test the case when locale is passed as param
    GlobalizationUtils.expects(:run_in_locale).with(:'fr-CA').once
    MembershipRequest.generate_and_email_report(admin, [reqs.first.id], "pending", "by_time_desc", :pdf, nil, :'fr-CA')
  end

  def test_should_generate_pdf_report
    reqs = programs(:albers).membership_requests.not_joined_directly.pending.by_time_desc
    admin = programs(:albers).admin_users.first
    MembershipRequestReport::PDF.expects(:generate).with(programs(:albers), [reqs.first], "pending").times(2).returns("Test pdf content")

    assert_emails(1) do
      assert_no_difference "JobLog.count" do
        MembershipRequest.generate_and_email_report(admin, [reqs.first.id], "pending", "by_time_desc", :pdf)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Membership requests report", email.subject)
    time = DateTime.localize(Time.now, format: :pdf_timestamp)
    assert_equal  "Membership requests-#{time}.pdf", email.attachments.first.filename
    assert_emails(1) do
      assert_no_difference "JobLog.count" do
        MembershipRequest.generate_and_email_report(admin, [reqs.first.id], "pending", "by_time_desc", :pdf)
      end
    end
  end

  def test_should_generate_pdf_report_with_job_uuid
    reqs = programs(:albers).membership_requests.not_joined_directly.pending.by_time_desc
    admin = programs(:albers).admin_users.first
    MembershipRequestReport::PDF.expects(:generate).with(programs(:albers), [reqs.first], "pending").times(2).returns("Test pdf content")

    assert_emails(1) do
      assert_difference "JobLog.count" do
        MembershipRequest.generate_and_email_report(admin, [reqs.first.id], "pending", "by_time_desc", :pdf, "15")
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Membership requests report", email.subject)
    time = DateTime.localize(Time.now, format: :pdf_timestamp)
    assert_equal  "Membership requests-#{time}.pdf", email.attachments.first.filename
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        MembershipRequest.generate_and_email_report(admin, [reqs.first.id], "pending", "by_time_desc", :pdf, "15")
      end
    end

    sort_scope = [:order_by, "question-#{profile_questions(:string_q).id}", "asc"]
    assert_emails do
      assert_difference "JobLog.count" do
        MembershipRequest.generate_and_email_report(users(:ram), [reqs.first.id], "pending", sort_scope, :pdf, "15")
      end
    end
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        MembershipRequest.generate_and_email_report(users(:ram), [reqs.first.id], "pending", sort_scope, :pdf, "15")
      end
    end
  end

  def test_should_generate_csv_report
    reqs = programs(:albers).membership_requests.not_joined_directly.pending.by_time_desc
    admin = programs(:albers).admin_users.first
    Zip::DOSTime.instance_eval do
      def now ; Zip::DOSTime.new(Time.now.to_s) ; end
    end
    MembershipRequestReport::CSV.expects(:generate).with([reqs.first], "pending").returns("Test csv content")
    assert_emails(1) do
      MembershipRequest.generate_and_email_report(admin, [reqs.first], "pending", "by_time_desc", :csv)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Membership requests report", email.subject)
    time = DateTime.localize(Time.now, format: :pdf_timestamp)
    assert_equal  "Membership requests-#{time}.csv.zip", email.attachments.first.filename
  end

  def test_create_user_from_accepted_request
    mentor_q = create_question(question_text: "Hello", required: true, role_names: [RoleConstants::MENTOR_NAME])
    student_q = create_question(question_text: "Drive", role_names: [RoleConstants::STUDENT_NAME])
    mem_q = create_membership_profile_question(:question_text => "Hello")

    membership_request = create_membership_request( {
      program: programs(:ceg),
      member: members(:f_student),
      status: MembershipRequest::Status::ACCEPTED,
      roles: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME],
      response_text: "Reason",
      accepted_as: RoleConstants::STUDENT_NAME,
      admin: users(:f_admin)
    } )
    membership_request.member.profile_answers.create!(profile_question: mem_q, answer_text: "Great")
    assert_no_difference "Member.count" do
      assert_difference "User.count" do
        membership_request.create_user_from_accepted_request
      end
    end

    student = User.last
    assert_equal User::Status::ACTIVE, student.state
    assert student.profile_incomplete_roles.empty?
    assert_equal "student", student.first_name
    assert_equal "example", student.last_name
    assert_equal membership_request.first_name, student.first_name
    assert_equal "rahim@example.com", student.email
    assert_equal programs(:ceg), student.program
    assert_equal [RoleConstants::STUDENT_NAME], student.role_names
    assert_equal UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, student.program_notification_setting
    assert_equal User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED, student.creation_source
    assert_equal 1, membership_request.profile_answers.count
  end

  def test_name
    membership_request = create_membership_request
    assert_equal membership_request.member.name, membership_request.name
  end

  def test_check_email_format
    security_setting = programs(:org_primary).security_setting
    assert_nil security_setting.email_domain
    security_setting.update_attributes!(email_domain: "CHRONUS.COM")
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :email, "should be of chronus.com" do
      create_membership_request(first_name: "Manju", last_name: "Sampole", email: "manju@sample.com")
    end
    member = programs(:org_primary).members.last
    email = member.email
    assert_equal email, "teacher_4@example.com"
    assert_nothing_raised do
      create_membership_request(first_name: "Manju", last_name: "Sampole", email: email)
    end
    assert_nothing_raised do
      create_membership_request(first_name: "Manju", last_name: "Sampole", email: "manju@chronus.com")
    end
  end

  def test_not_joined_directly_scope
    membership_request = create_membership_request
    membership_request.joined_directly = true
    membership_request.save
    assert_equal MembershipRequest.count, MembershipRequest.not_joined_directly.count + 1
  end

  def test_answered_and_not_joined_directly
    membership_request = create_membership_request
    assert_false membership_request.answered_and_not_joined_directly?
    membership_request.status = MembershipRequest::Status::ACCEPTED
    membership_request.joined_directly = true
    membership_request.accepted_as = RoleConstants::MENTOR_NAME
    membership_request.save
    assert membership_request.joined_directly?
    assert_false membership_request.pending?
    assert_false membership_request.answered_and_not_joined_directly?
  end

  def test_user
    membership_request = membership_requests(:membership_request_0)
    assert_equal users(:student_0), membership_request.user
  end

  def test_get_invalid_profile_answer_details
    question_1 = create_membership_profile_question(question_text: 'Height', role_names: [RoleConstants::STUDENT_NAME])
    question_2 = create_membership_profile_question(question_text: 'Weight', role_names: [RoleConstants::STUDENT_NAME])
    question_3 = create_membership_profile_question(question_text: 'Resume', role_names: [RoleConstants::STUDENT_NAME], question_type: ProfileQuestion::Type::FILE)
    membership_request = create_membership_request(
      { roles: [RoleConstants::STUDENT_NAME] },
      { question_1.id => '165 cms', question_2.id => '70 Kgs', question_3.id => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text') } )

    uploader = FileUploader.new(question_3.id, 'new', fixture_file_upload(File.join('files', 'big.pdf'), 'application/pdf'), base_path: ProfileAnswer::TEMP_BASE_PATH)
    assert_false uploader.save
  end

  def test_sorted_by_answer_for_file_question
    member_1 = members(:mentor_0)
    member_2 = members(:student_7)
    member_3 = members(:student_8)
    file1 = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    file2 = fixture_file_upload(File.join('files', 'test_email_source.eml'))
    file3 = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')

    question = create_membership_profile_question(question_text: 'Resume', role_names: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::FILE)
    uploader1 = FileUploader.new(question.id, member_1.id, file1, base_path: ProfileAnswer::TEMP_BASE_PATH)
    uploader1.save
    uploader2 = FileUploader.new(question.id, member_2.id, file2, base_path: ProfileAnswer::TEMP_BASE_PATH)
    uploader2.save
    uploader3 = FileUploader.new(question.id, member_3.id, file3, base_path: ProfileAnswer::TEMP_BASE_PATH)
    uploader3.save
    FileUploader.expects(:get_file_path).with(question.id, member_1.id, ProfileAnswer::TEMP_BASE_PATH, { code: uploader1.uniq_code, file_name: "some_file.txt" }).returns(file1)
    FileUploader.expects(:get_file_path).with(question.id, member_2.id, ProfileAnswer::TEMP_BASE_PATH, { code: uploader2.uniq_code, file_name: "test_email_source.eml" }).returns(file2)
    FileUploader.expects(:get_file_path).with(question.id, member_3.id, ProfileAnswer::TEMP_BASE_PATH, { code: uploader3.uniq_code, file_name: "test_file.css" }).returns(file3)

    membership_request_1 = create_membership_request(
      { roles: [RoleConstants::STUDENT_NAME], member: member_1 },
      { question.id => 'some_file.txt' }, "question_#{question.id}_code" => uploader1.uniq_code)
    membership_request_2 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME], member: member_2 },
      { question.id => 'test_email_source.eml' }, "question_#{question.id}_code" => uploader2.uniq_code)
    membership_request_3 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], member: member_3 },
      { question.id => 'test_file.css' }, "question_#{question.id}_code" => uploader3.uniq_code)

    scope = MembershipRequest.where(id: [membership_request_1.id, membership_request_2.id, membership_request_3.id])
    assert_equal [membership_request_1.id, membership_request_2.id, membership_request_3.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "asc").map(&:id)
    assert_equal [membership_request_3.id, membership_request_2.id, membership_request_1.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_work_question
    question = create_membership_profile_question(question_text: 'Work', role_names: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::EXPERIENCE)
    default_experience_options = {
      job_title: 'A',
      start_year: 1990,
      end_year: 2001,
      company: 'B'
    }

    membership_request_1 = create_membership_request(
      { roles: [RoleConstants::STUDENT_NAME], member: members(:mentor_0) },
      { question.id => { "new_experience_attributes" => [ { "0" => default_experience_options.merge(job_title: 'A') } ] } } )
    membership_request_2 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME], member: members(:student_7) },
      { question.id => { "new_experience_attributes" => [ { "0" => default_experience_options.merge(job_title: 'B') } ] } } )
    membership_request_3 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], member: members(:student_8) },
      { question.id => { "new_experience_attributes" => [ { "0" => default_experience_options.merge(job_title: 'C') } ] } } )

    scope = MembershipRequest.where(id: [membership_request_1.id, membership_request_2.id, membership_request_3.id])
    assert_equal [membership_request_1.id, membership_request_2.id, membership_request_3.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "asc").map(&:id)
    assert_equal [membership_request_3.id, membership_request_2.id, membership_request_1.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_education_question
    question = create_membership_profile_question(question_text: 'Education', role_names: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::EDUCATION)
    default_education_options = {
      school_name: 'A',
      degree: 'A',
      major: 'Mech',
      graduation_year: 2010
    }

    membership_request_1 = create_membership_request(
      { roles: [RoleConstants::STUDENT_NAME], member: members(:mentor_0) },
      { question.id => { "new_education_attributes" => [ { "0" => default_education_options } ] } } )
    membership_request_2 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME], member: members(:student_7) },
      { question.id => { "new_education_attributes" => [ { "0" => default_education_options.merge(school_name: 'B') } ] } } )
    membership_request_3 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], member: members(:student_8) },
      { question.id => { "new_education_attributes" => [ { "0" => default_education_options.merge(school_name: 'C') } ] } } )

    scope = MembershipRequest.where(id: [membership_request_1.id, membership_request_2.id, membership_request_3.id])
    assert_equal [membership_request_1.id, membership_request_2.id, membership_request_3.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "asc").map(&:id)
    assert_equal [membership_request_3.id, membership_request_2.id, membership_request_1.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_publication_question
    question = create_membership_profile_question(question_text: 'Publication', role_names: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::PUBLICATION)
    default_publication_options = {
      title: 'A',
      authors: 'A',
      publisher: 'Mech',
      year: 2010,
      month: 1,
      day: 1
    }

    membership_request_1 = create_membership_request(
      { roles: [RoleConstants::STUDENT_NAME], member: members(:mentor_0) },
      { question.id => { "new_publication_attributes" => [ { "0" => default_publication_options } ] } } )
    membership_request_2 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME], member: members(:student_7) },
      { question.id => { "new_publication_attributes" => [default_publication_options.merge(title: 'B')] } } )
    membership_request_3 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], member: members(:student_8) },
      { question.id => { "new_publication_attributes" => [default_publication_options.merge(title: 'C')] } } )

    scope = MembershipRequest.where(id: [membership_request_1.id, membership_request_2.id, membership_request_3.id])
    assert_equal [membership_request_1.id, membership_request_2.id, membership_request_3.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "asc").map(&:id)
    assert_equal [membership_request_3.id, membership_request_2.id, membership_request_1.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_text_question
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)

    membership_request_1 = create_membership_request(
      { roles: [RoleConstants::STUDENT_NAME], member: members(:mentor_0) },
      { question.id => 'A' } )
    membership_request_2 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME], member: members(:student_7) },
      { question.id => 'B' } )
    membership_request_3 = create_membership_request(
      { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], member: members(:student_8) },
      { question.id => 'C' } )

    scope = MembershipRequest.where(id: [membership_request_1.id, membership_request_2.id, membership_request_3.id])
    assert_equal [membership_request_1.id, membership_request_2.id, membership_request_3.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "asc").map(&:id)
    assert_equal [membership_request_3.id, membership_request_2.id, membership_request_1.id], MembershipRequest.sorted_by_answer(scope, question.organization, question.id, "desc").map(&:id)
  end

  def test_send_membership_notification
    mt = programs(:albers).mailer_templates.where(uid: MembershipRequestSentNotification.mailer_attributes[:uid]).first
    mt.enabled = true
    mt.save!

    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      membership_request.send_membership_notification
    end
    assert_equal "Your membership request has been received.", ActionMailer::Base.deliveries.last.subject
  end

  def test_trigger_manager_notification
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    manager_question = programs(:org_primary).profile_questions.manager_questions.first

    Organization.any_instance.stubs(:manager_enabled?).returns(false)
    MembershipRequest.any_instance.expects(:send_manager_notification).never
    MembershipRequest.trigger_manager_notification(membership_request.id)

    Organization.any_instance.stubs(:manager_enabled?).returns(true)
    MembershipRequest.any_instance.expects(:send_manager_notification).never
    MembershipRequest.trigger_manager_notification(membership_request.id)

    create_manager(membership_request.user, manager_question)
    MembershipRequest.any_instance.expects(:send_manager_notification).once
    MembershipRequest.trigger_manager_notification(membership_request.id)
  end

  def test_send_manager_notification
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    question = programs(:org_primary).profile_questions.manager_questions.first
    manager = create_manager(users(:f_student), question)
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      membership_request.send_manager_notification(manager)
    end
    assert_equal [manager.email], ActionMailer::Base.deliveries.last.to
  end

  def test_manager
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    question = programs(:org_primary).profile_questions.manager_questions.first
    manager = create_manager(users(:f_student), question)
    assert membership_request.manager.present?
    membership_request.program = programs(:org_primary).programs.last
    assert_false membership_request.manager.present?
  end

  def test_check_member_be_non_suspended
    member = members(:f_mentor)
    assert member.active?
    membership_request = create_membership_request(member: members(:f_mentor), roles: [RoleConstants::STUDENT_NAME])
    assert membership_request.valid?

    member.update_column(:state, Member::Status::SUSPENDED)
    assert_false membership_request.reload.valid?
    assert_equal ["suspended member's request cannot be pending"], membership_request.errors[:member]

    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :member, "suspended members cannot apply") do
      create_membership_request(member: member, program: programs(:psg), roles: [RoleConstants::STUDENT_NAME])
    end
  end

  def test_check_suspended_user_cannot_join_directly
    user = users(:inactive_user)
    member = user.member
    assert user.suspended?
    assert member.suspended?
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :joined_directly, "Suspended users are not allowed to join without approval") do
      create_membership_request(member: member, program: programs(:psg), roles: [RoleConstants::MENTOR_NAME], joined_directly: true)
    end

    member.update_column(:state, Member::Status::ACTIVE)
    assert user.suspended?
    assert_false member.suspended?
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :joined_directly, "Suspended users are not allowed to join without approval") do
      create_membership_request(member: member, program: programs(:psg), roles: [RoleConstants::MENTOR_NAME], joined_directly: true)
    end

    user.update_column(:state, User::Status::ACTIVE)
    assert_false user.suspended?
    assert_nothing_raised do
      create_membership_request(member: member, program: programs(:psg), roles: [RoleConstants::MENTOR_NAME], joined_directly: true)
    end
  end
end