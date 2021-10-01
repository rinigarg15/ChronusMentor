require_relative './../test_helper.rb'

class MentorRequestTest < ActiveSupport::TestCase
  TEMP_CSV_FILE = "tmp/test_file.csv"

  def test_association
    cache_key = users(:f_mentor).cache_key
    mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
    assert_not_equal cache_key, users(:f_mentor).cache_key
    mentor_request.closed_by_id = users(:f_admin).id
    assert_equal users(:f_admin), mentor_request.closed_by
    users(:f_admin).destroy
    assert_nil mentor_request.reload.closed_by
  end

  def test_invalid_creation_for_inactive_mentor
    mentor = users(:f_mentor)
    mentor.delete!
    request = MentorRequest.new(:program => programs(:albers), :student => users(:f_student), :mentor => mentor)
    assert_false request.valid?

    assert request.errors[:mentor]
  end

  def test_invalid_creation_for_closed_request
    mentor = users(:f_mentor)
    mentor.delete!
    request = MentorRequest.new(:program => programs(:albers), :student => users(:f_student), :mentor => mentor, :status => AbstractRequest::Status::CLOSED)
    assert_false request.valid?
    assert_equal ["can't be blank"], request.errors[:closed_at]
  end

  def test_scope_involving
    student = users(:f_student)
    mentor = users(:f_mentor)

    mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => student, :mentor => mentor)
    member_ids = [student.id, mentor.id]
    assert_equal [mentor_request], MentorRequest.involving(member_ids)
  end

  def test_valid_creation
    programs(:albers).update_attribute(:min_preferred_mentors, 2)
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'MentorRequest.count' do
        @mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
      end
    end

    assert_equal programs(:albers), @mentor_request.program
    assert_equal users(:f_student), @mentor_request.student
    assert_equal users(:f_mentor), @mentor_request.mentor

    # Default to NOT_ANSWERED
    assert_equal AbstractRequest::Status::NOT_ANSWERED, @mentor_request.status

    delivered_email = ActionMailer::Base.deliveries.first
    assert_equal @mentor_request.mentor.email, delivered_email.to[0]
    assert_match(/You received a new mentoring request from #{@mentor_request.student.name}/,
      delivered_email.subject)

    assert_match("/mentor_requests", get_html_part_from(delivered_email))
    assert @mentor_request.active?
  end

  def test_dependent_destroy_push_notifications
    programs(:albers).update_attribute(:min_preferred_mentors, 2)
    mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))

    object = {object_id: mentor_request.id, category: MentorRequest.name}
    users(:f_mentor).member.push_notifications.create!(notification_params: object, ref_obj_id: mentor_request.id, ref_obj_type: mentor_request.class.name, notification_type: PushNotification::Type::MENTOR_REQUEST_CREATE)
    assert_difference "PushNotification.count", -1 do
      mentor_request.reload.destroy
    end
  end

  def test_requires_program
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :program do
        MentorRequest.create!(
          :message => "Hi",
          :student => users(:f_student),
          :mentor => users(:f_mentor))
      end
    end
  end

  def test_requires_student
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :student do
        MentorRequest.create!(
          :message => "Hi",
          :program => programs(:albers),
          :mentor => users(:f_mentor))
      end
    end
  end

  def test_requires_status_and_inclusion
    mreq = MentorRequest.new(:message => "Hi",:program => programs(:albers),:mentor => users(:f_mentor),:student => users(:f_student), :status => nil)
    assert_false mreq.valid?
    assert mreq.errors[:status]

    mreq_1 = MentorRequest.new(:message => "Hi",:program => programs(:albers),:mentor => users(:f_mentor),:student => users(:f_student), :status => 5)
    assert_false mreq_1.valid?
    assert mreq_1.errors[:status]
  end

  def test_requires_student_can_send_mentor_request
    remove_mentor_request_permission_for_students
    assert_false users(:f_student).can_send_mentor_request?

    mentor_request = MentorRequest.new(
      :message => "Hi",
      :program => programs(:albers),
      :mentor => users(:f_mentor),
      :student => users(:f_student)
    )

    assert_false mentor_request.valid?
    assert mentor_request.errors[:student]
  end

  def test_requires_mentor
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :mentor do
        MentorRequest.create!(
          :message => "Hi",
          :program => programs(:albers),
          :student => users(:f_student))
      end
    end
  end

  def test_should_not_have_mentor_for_moderated_groups
    make_member_of(:moderated_program, users(:f_student))
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :mentor do
        MentorRequest.create!(
          :program => programs(:moderated_program),
          :student => users(:f_student),
          :mentor => users(:moderated_mentor),
          :message => "Hi")
      end
    end
  end

  def test_should_check_min_preferred_mentors_for_moderated_groups_on_creation
    program = programs(:moderated_program)
    make_member_of(:moderated_program, users(:f_student))
    program.update_attribute(:min_preferred_mentors, 2)

    assert program.matching_by_mentee_and_admin_with_preference?
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :student do
        MentorRequest.create!(program: program, student: users(:f_student), message: "Hi")
      end
    end

    program.update_attribute(:min_preferred_mentors, 1)
    assert_difference 'MentorRequest.count' do
      @mentor_request = MentorRequest.new(program: program, student: users(:f_student), message: "Hi")
      @mentor_request.build_favorites([users(:moderated_mentor).id])
      @mentor_request.save!
    end

    program.update_attribute(:min_preferred_mentors, 2)
    assert @mentor_request.save
  end

  def test_check_mentor_blank_if_admin_match_program
    program = programs(:moderated_program)
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :mentor do
        MentorRequest.create!(program: program, student: users(:moderated_student), mentor: users(:moderated_mentor), message: "Hi")
      end
    end
    assert_difference 'MentorRequest.count' do
      MentorRequest.create!(program: program, student: users(:moderated_student), message: "Hi")
    end

  end

  def test_for_moderated_groups_has_one_fav
    p = programs(:moderated_program)
    p.update_attribute(:min_preferred_mentors, 1)
    make_member_of(:moderated_program, users(:f_student))

    assert_difference 'MentorRequest.count' do
      assert_difference 'RequestFavorite.count' do
        req = MentorRequest.new(:program => p, :student => users(:f_student), :message => "Hi")
        req.build_favorites([users(:moderated_mentor).id])
        req.save!
      end
    end
  end

  def test_requires_message
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :message do
        MentorRequest.create!(
          :program => programs(:albers),
          :student => users(:f_student),
          :mentor => users(:f_mentor)
        )
      end
    end
  end

  def test_cannot_send_request_when_connection_limit_reached
    programs(:albers).update_attribute(:max_connections_for_mentee, 1)
    assert users(:mkr_student).connection_limit_as_mentee_reached?

    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :student do
        MentorRequest.create!(:program => programs(:albers), :student => users(:mkr_student), :mentor => users(:f_mentor), :message => "Hi")
      end
    end
  end

  def test_cannot_send_request_when_pending_request_limit_reached
    programs(:albers).update_attribute(:max_pending_requests_for_mentee, 1)
    MentorRequest.create!(:program => programs(:albers), :student => users(:mkr_student), :mentor => users(:f_mentor), :message => "Hi")
    assert users(:mkr_student).pending_request_limit_reached_for_mentee?

    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :student do
        MentorRequest.create!(:program => programs(:albers), :student => users(:mkr_student), :mentor => users(:f_mentor_student), :message => "Hi")
      end
    end
  end

  def test_cannot_send_request_when_program_doesnot_allow
    programs(:albers).update_attribute(:allow_mentoring_requests, false)
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :program do
        MentorRequest.create!(:program => programs(:albers), :student => users(:mkr_student), :mentor => users(:f_mentor), :message => "Hi")
      end
    end
  end

  def test_cannot_send_request_when_program_doesnot_allow_created_but_allows_update
    m_req = MentorRequest.create!(:program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor), :message => "Hi")
    programs(:albers).update_attribute(:allow_mentoring_requests, false)
    assert_nothing_raised do
      m_req.mark_accepted!
    end
  end

  def test_self_request
    req = MentorRequest.new(:student => users(:f_mentor_student), :mentor => users(:f_mentor_student), :program => programs(:albers), :message => "Hi")
    assert !req.valid?
    assert_equal ["Cant get mentored by yourself"], req.errors[:base]
  end

  def test_check_if_student_can_connect_to_mentor
    program = programs(:albers)
    program.zero_match_score_message = 'message'
    student = users(:f_student)
    student.stubs(:can_connect_to_mentor?).returns(false)
    req = MentorRequest.new(:student => student, :mentor => users(:f_mentor_student), :program => program, :message => "Hi")
    assert !req.valid?
    assert_equal ['message'], req.errors[:base]
  end

  def test_student_must_belong_to_program
    program = programs(:ceg)
    mentor = users(:f_mentor)
    student = users(:f_student)
    member_mentor = create_user(:name => 'mentor_name', :role_names => [RoleConstants::MENTOR_NAME], :program => programs(:ceg))

    # Check associations.
    assert !student.member_of?(program)
    assert !mentor.member_of?(program)
    assert member_mentor.member_of?(program)

    assert_no_difference 'MentorRequest.count' do
      # Mentor is also not part of the program
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :student,
        "is not member of the program" do
        MentorRequest.create!(
          :program => program,
          :student => student,
          :mentor => mentor)
      end

      # Only mentor is part of program
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :student,
        "is not member of the program" do
        MentorRequest.create!(
          :program => program,
          :student => student,
          :mentor => member_mentor)
      end
    end
  end

  def test_mentor_must_belong_to_program
    program = programs(:ceg)
    mentor = users(:f_mentor)
    student = users(:f_student)
    member_student = create_user(:program => programs(:ceg))

    # Check associations.
    assert !student.member_of?(program)
    assert !mentor.member_of?(program)
    assert member_student.member_of?(program)

    assert_no_difference 'MentorRequest.count' do
      # Student is also not part of the program
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :mentor,
        "is not member of the program" do
        MentorRequest.create!(
          :program => program,
          :student => student,
          :mentor => mentor)
      end

      # Only student is part of the program
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :mentor,
        "is not member of the program" do
        MentorRequest.create!(
          :program => program,
          :student => member_student,
          :mentor => mentor)
      end
    end
  end

  def test_not_more_than_one_unanswered_request_from_student_to_a_mentor_in_a_program
    # Create a request
    assert_difference 'MentorRequest.count' do
      @first_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
    end

    # Create another request for the same combination
    assert_no_difference 'MentorRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender_id,
        "has already sent a request to this mentor" do
        MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
      end
    end

    @first_request.status = AbstractRequest::Status::REJECTED
    @first_request.response_text = "Sorry rejected"
    @first_request.save!

    # The request can now been saved.
    assert_nothing_raised do
      assert_difference 'MentorRequest.count' do
        @second_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
      end
    end

    @second_request.mark_accepted!

    # The request can now been saved.
    assert_nothing_raised do
      assert_difference 'MentorRequest.count' do
        @second_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
      end
    end
  end

  def test_request_accept_sends_email_to_student
    mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))

    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'Group.count' do
        mentor_request.mark_accepted!
      end
    end

    group = Group.last
    assert_equal(group, mentor_request.reload.group)
    assert mentor_request.accepted?
    assert_equal [users(:f_student)], group.students
    assert_equal [users(:f_mentor)], group.mentors
    assert_equal programs(:albers), group.program

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal mentor_request.student.email, delivered_email.to[0]
    assert_match(/#{mentor_request.mentor.name} has accepted to be your mentor/,
      delivered_email.subject)
    assert_match("groups/#{group.id}", get_html_part_from(delivered_email))

    assert_no_emails do
      assert_no_difference "Group.count" do
        assert_nothing_raised do
          mentor_request.mark_accepted!
        end
      end
    end

    second_request = MentorRequest.create!(:message => "Hi f_mentor", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_no_difference 'Group.count' do
        second_request.mark_accepted!
      end
    end
    assert second_request.accepted?
    assert_equal(group, second_request.reload.group)
  end

  def test_request_accept_for_one_to_many_scenario
    allow_one_to_many_mentoring_for_program(programs(:albers))
    Group.destroy_all

    mentor_request_1 = MentorRequest.create!(:program => programs(:albers),:student => users(:f_student),:mentor => users(:robert), :message => "Hi")
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'Group.count' do
        mentor_request_1.mark_accepted!
      end
    end

    group_1 = Group.last
	  assert_equal(group_1, mentor_request_1.reload.group)
    assert_equal [users(:f_student)], group_1.students
    assert_equal [users(:robert)], group_1.mentors
    assert_equal programs(:albers), group_1.program

    mentor_request_2 = MentorRequest.create!(:program => programs(:albers), :student => users(:rahim), :mentor => users(:robert).reload, :message => "Hi")
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'Group.count' do
        mentor_request_2.mark_accepted!
      end
    end

    group_2 = Group.last
	  assert_equal(group_2, mentor_request_2.reload.group)
    assert_equal [users(:rahim)], group_2.students
    assert_equal [users(:robert)], group_2.mentors
    assert_equal programs(:albers), group_2.program

    mentor_request_3 = MentorRequest.create!(:program => programs(:albers), :student => users(:f_mentor_student), :mentor => users(:robert).reload, :message => "Hi")
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_no_difference 'Group.count' do
        mentor_request_3.mark_accepted!(group_1)
      end
    end

    assert_equal(group_1, mentor_request_3.reload.group)
    assert_equal [users(:f_student), users(:f_mentor_student)], group_1.reload.students
    assert_equal [users(:robert)], group_1.mentors
    assert_equal programs(:albers), group_1.program
  end

  def test_request_reject_creates_no_group_but_sends_email_to_student
    mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))

    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_no_difference 'Group.count' do
        mentor_request.status = AbstractRequest::Status::REJECTED
        mentor_request.response_text = 'I reject'
        mentor_request.save!
      end
    end

    assert mentor_request.reload.rejected?

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal mentor_request.student.email, delivered_email.to[0]
    assert_match(/Request a new mentor - Good unique name is unavailable at this time/, delivered_email.subject)

    assert_match("/members", get_html_part_from(delivered_email))
    assert_match(mentor_request.response_text, get_html_part_from(delivered_email))
  end

  def test_request_reject_for_moderated_groups
    make_member_of(:moderated_program, :f_mentor)
    make_member_of(:moderated_program, :f_student)

    mentor_request = MentorRequest.create!(:program => programs(:moderated_program),:student => users(:f_student), :message => "Hi")

    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_no_difference 'Group.count' do
        mentor_request.update_attributes!({:rejector => users(:f_admin_moderated_program), :status => AbstractRequest::Status::REJECTED, :response_text => 'I reject'})
      end
    end

    assert mentor_request.reload.rejected?
    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal mentor_request.student.email, delivered_email.to[0]
    assert_match("Request a new mentor - #{users(:f_admin_moderated_program).name} is unavailable at this time", delivered_email.subject)
    assert_match(mentor_request.response_text, get_html_part_from(delivered_email))
  end

  def test_active_requests_scope
    MentorRequest.destroy_all
    mentor = users(:f_mentor)
    mentor.update_attribute :max_connections_limit, 4
    assert_equal 4, mentor.max_connections_limit
    students = []
    active_requests = []

    20.times do |i|
      user = create_user(:name => "student", :role_names => [RoleConstants::STUDENT_NAME], :email => "student_#{i}@chronus.com")
      students << user

      mentor_request = MentorRequest.create!(:message => "Hi", :student => user, :mentor => mentor, :program => programs(:albers))

      # Accept or decline some of the requests.
      if (3...6).include?(i)
        mentor_request.mark_accepted!
      elsif (11..15).include?(i)
        mentor_request.status = AbstractRequest::Status::REJECTED
        mentor_request.response_text = "Sorry"
        mentor_request.save
      else
        active_requests << mentor_request
      end
    end

    assert_equal active_requests, MentorRequest.active
  end

   def test_withdrawn_requests_scope
    MentorRequest.destroy_all
    student = users(:f_student)
    withdrawn_requests = []
    mentors= []

    20.times do |i|
      mentor = create_user(:name => "mentor", :role_names => [RoleConstants::MENTOR_NAME], :email => "mentor_#{i}@chronus.com")
      mentors << mentor

      mentor_request = MentorRequest.create!(:message => "Hi", :student => student, :mentor => mentor, :program => programs(:albers))

      if (3..6).include?(i)
        mentor_request.status = AbstractRequest::Status::WITHDRAWN
        mentor_request.response_text = "Sorry!"
        mentor_request.save
        withdrawn_requests << mentor_request
      elsif (11..15).include?(i)
        mentor_request.mark_accepted!
      end
    end

    assert_equal withdrawn_requests, MentorRequest.withdrawn
  end

  def test_closed_requests_scope
    MentorRequest.destroy_all
    student = users(:f_student)
    closed_requests = []
    mentors= []

    10.times do |i|
      mentor = create_user(:name => "mentor", :role_names => [RoleConstants::MENTOR_NAME], :email => "mentor_#{i}@chronus.com")
      mentors << mentor

      mentor_request = MentorRequest.new(:message => "Hi", :student => student, :mentor => mentor, :program => programs(:albers))

      if (3..5).include?(i)
        mentor_request.status = AbstractRequest::Status::CLOSED
        mentor_request.closed_at = Time.now
        mentor_request.response_text = "Sorry!"
        mentor_request.save
        closed_requests << mentor_request
      elsif (7..9).include?(i)
        mentor_request.mark_accepted!
      else
        mentor_request.save!
      end
    end

    assert_equal closed_requests, MentorRequest.closed
  end

  def test_for_program_scope
    # create student and mentor
    student = users(:f_student)
    mentor = users(:f_mentor_student)

    # create mentor_requests
    mentor_request_1 = MentorRequest.create!(:message => "Hi", :student => student, :mentor => mentor, :program => programs(:albers))

    make_member_of(:ceg, student)
    make_member_of(:ceg, mentor)

    mentor_request_2 = MentorRequest.create!(:message => "Hi", :student => student.reload, :mentor => mentor.reload, :program => programs(:ceg))

    # Check whether the scope works
    assert MentorRequest.for_program(programs(:albers)).include?(mentor_request_1)
    assert !MentorRequest.for_program(programs(:albers)).include?(mentor_request_2)
    assert_equal [mentor_request_2], MentorRequest.for_program(programs(:ceg))
  end

  def test_from_student_scope
    student = users(:f_student)
    mentor = users(:f_mentor)

    mentor_request_1 = MentorRequest.create!(:message => "Hi", :student => student, :mentor => mentor, :program => programs(:albers))

    # Request from another student, rahim
    mentor_request_2 = MentorRequest.create!(:message => "Hi", :student => users(:rahim), :mentor => mentor, :program => programs(:albers))

    # Accept request #1 so that we can place another from the same student.
    mentor_request_1.status = AbstractRequest::Status::REJECTED
    mentor_request_1.response_text = "Sorry"
    mentor_request_1.save!

    mentor_request_3 = MentorRequest.create!(:message => "Hi", :student => student, :mentor => mentor, :program => programs(:albers))

    assert_equal [mentor_request_1, mentor_request_3],
      mentor.reload.received_mentor_requests.from_student(student)

    assert_equal [mentor_request_2],
      mentor.reload.received_mentor_requests.from_student(users(:rahim))
  end

  def test_to_mentor_scope
    mentor_request_1 = create_mentor_request(
      :student => users(:f_student), :mentor => users(:f_mentor),
      :program => programs(:albers))

    mentor_request_2 = create_mentor_request(
      :student => users(:f_student), :mentor => users(:robert),
      :program => programs(:albers))

    assert MentorRequest.to_mentor(users(:f_mentor)).include?(mentor_request_1)
    assert !MentorRequest.to_mentor(users(:f_mentor)).include?(mentor_request_2)
    assert !MentorRequest.to_mentor(users(:robert)).include?(mentor_request_1)
    assert MentorRequest.to_mentor(users(:robert)).include?(mentor_request_2)

    student = create_user(:role_names => [RoleConstants::STUDENT_NAME], :program => programs(:moderated_program))
    mreq = create_mentor_request(:student => student, :program => programs(:moderated_program))

    # No change due to the request in a moderated program, which wont have mentor_id
    assert !MentorRequest.to_mentor(users(:f_mentor)).include?(mreq)
    assert !MentorRequest.to_mentor(users(:robert)).include?(mreq)
  end

  def test_has_access
    # Moderated program
    program = programs(:moderated_program)
    assert program.reload.matching_by_mentee_and_admin?
    mentor = create_user(:role_names => [RoleConstants::MENTOR_NAME], :program => program, :name => 'abcde')
    admin = create_user(:role_names => [RoleConstants::ADMIN_NAME], :program => program, :name => 'abcde_one')
    assert program.member?(mentor) && program.member?(admin)

    assert MentorRequest.has_access?(admin, program)
    assert !MentorRequest.has_access?(mentor, program)
    # Say, mentors can manage requests for anyone.
    add_role_permission(fetch_role(:moderated_program, :mentor), 'manage_mentor_requests')
    assert mentor.reload.can_manage_mentor_requests?
    assert MentorRequest.has_access?(mentor, program)

    # User not belonging to the program
    assert !program.member?(users(:f_mentor))
    assert !program.member?(users(:ram))
    assert !MentorRequest.has_access?(users(:f_mentor), program)
    assert !MentorRequest.has_access?(users(:ram), program)
  end

  def test_has_access_in_a_non_moderated_group
    program = programs(:ceg)
    assert program.reload.matching_by_mentee_alone?
    mentor = create_user(:role_names=> [RoleConstants::MENTOR_NAME], :program => program, :name => 'abcde')
    admin = create_user(:role_names => [RoleConstants::ADMIN_NAME], :program => program, :name => 'abcde_one')
    assert program.member?(mentor) && program.member?(admin)

    assert !MentorRequest.has_access?(admin, program)
    assert MentorRequest.has_access?(mentor, program)

    # User not belonging to the program
    assert !program.member?(users(:f_mentor))
    assert !program.member?(users(:ram))
    assert !MentorRequest.has_access?(users(:f_mentor), program)
    assert !MentorRequest.has_access?(users(:ram), program)
  end

  def test_receivers
    assert programs(:albers).matching_by_mentee_alone?
    r = create_mentor_request
    assert_equal [users(:f_mentor)], r.receivers

    MentorRequest.destroy_all
    r = create_mentor_request(:program => programs(:moderated_program), :student => users(:moderated_student))
    assert_equal_unordered [users(:moderated_admin), users(:f_admin_moderated_program)], r.receivers
  end

  def test_response_not_mandatory_for_rejection
    req = MentorRequest.new(:message => "Hi", :student => users(:f_student),:mentor => users(:f_mentor), :program => programs(:albers))
    assert req.valid?
    req.status = AbstractRequest::Status::REJECTED
    assert req.valid?
  end

  def test_assign_mentor
    program = programs(:moderated_program)

    mentor = users(:moderated_mentor)
    student = users(:moderated_student)
    assert mentor.mentoring_groups.empty?
    mentor_request = create_mentor_request(:student => student, :program => program)
    assert_difference 'Group.count' do
      @group = mentor_request.assign_mentor!(mentor, created_by: users(:moderated_admin))
    end

    assert_not_nil @group
    assert_equal [@group], mentor.mentoring_groups.reload
    assert_equal AbstractRequest::Status::ACCEPTED, mentor_request.reload.status
    assert_equal users(:moderated_admin), @group.reload.created_by
  end

  def test_accept_mentor_request_when_mentoring_connections_limit_is_reached
    mentor_req_without_group = mentor_requests(:mentor_request_0)
    mentor = mentor_req_without_group.mentor
    mentor.update_attribute(:max_connections_limit, 1)
    assert_false mentor_req_without_group.mark_accepted!
    mentor.update_attribute(:max_connections_limit, 2)
    assert mentor_req_without_group.mark_accepted!

    mentor_req_with_group = mentor_requests(:mentor_request_1)
    mentor = mentor_req_with_group.mentor
    assert_false mentor_req_with_group.mark_accepted!(mentor.mentoring_groups.active.first)
    mentor.update_attribute(:max_connections_limit, 3)
    assert mentor_req_with_group.mark_accepted!(mentor.mentoring_groups.active.first)
  end

  def test_assign_mentor_adds_to_given_group
    program = programs(:moderated_program)
    make_member_of(:moderated_program, :f_student)
    allow_one_to_many_mentoring_for_program(program)

    assert program.reload.allow_one_to_many_mentoring?

    mentor = users(:moderated_mentor)
    student_1 = users(:moderated_student)
    student_2 = users(:f_student)

    group = create_group(:mentors => [mentor], :student => student_1, :program => program)
    assert_equal [group], mentor.mentoring_groups.reload
    mentor_request = create_mentor_request(:student => student_2, :program => program)

    assert_no_difference 'Group.count' do
      @group = mentor_request.assign_mentor!(group)
    end

    assert_equal group, @group
    assert_equal [@group], mentor.mentoring_groups.reload
    assert_equal_unordered [student_1, student_2], @group.students.reload
    assert_equal @group, mentor_request.group
  end

  def test_assign_mentor_with_mentoring_model
    program = programs(:moderated_program)
    mentor = users(:moderated_mentor)
    student = users(:moderated_student)
    mentoring_model = program.mentoring_models.where(default: false).first
    mentor_request = create_mentor_request(student: student, program: program)
    @group = mentor_request.assign_mentor!(mentor, created_by: users(:moderated_admin), mentoring_model: mentoring_model)
    assert_dynamic_expected_nil_or_equal mentoring_model, @group.mentoring_model
  end

  def test_build_favorites
    make_member_of(:moderated_program, :f_mentor)
    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :f_mentor_student)

    req = MentorRequest.new(:student => users(:f_student), :program => programs(:moderated_program))
    req.build_favorites(["#{users(:f_mentor).id}","#{users(:f_mentor_student).id}"])

    assert_equal 2, req.request_favorites.size
    assert_equal [users(:f_student), users(:f_student)], req.request_favorites.collect(&:user)
    assert_equal [users(:f_mentor), users(:f_mentor_student)], req.request_favorites.collect(&:favorite)
  end

  def test_csv_export
    abstract_preferences(:ignore_2).destroy!
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    invalidate_albers_calendar_meetings
    program = programs(:albers)
    students = [users(:rahim), users(:f_student)]
    mentor1 = users(:f_mentor)
    mentor2 = users(:f_mentor_student)
    ram = users(:ram)
    robert = users(:robert)

    rq1 = program.mentor_requests.create(student: students[0], message: "This is message", mentor: mentor1)
    RequestFavorite.create(user: students[0], favorite: mentor1, note: "hihhi", mentor_request_id: rq1.id, position: 2)
    RequestFavorite.create(user: students[0], favorite: mentor2, note: "hihhi", mentor_request_id: rq1.id, position: 1)

    rq2 = program.mentor_requests.create(student: students[1], message: "This is message2", mentor: mentor1)
    RequestFavorite.create(user: students[1], favorite: mentor1, note: "hihhi", mentor_request_id: rq2.id, position: 1)
    RequestFavorite.create(user: students[1], favorite: mentor2, note: "hihhi", mentor_request_id: rq2.id, position: 2)

    time1 = Time.now - 1.year
    time2 = Time.now - 2.year
    rq1.expects(:created_at).once.returns(time1)
    rq2.expects(:created_at).once.returns(time2)

    # Get the computed data in csv_data array.
    csv_data = []
    CSV.expects(:generate).yields(csv_data)
    Matching::Indexer.perform_program_delta_index(program.id)
    reset_cache(rq1.student)
    reset_cache(rq2.student)
    MentorRequestReport::CSV.generate(programs(:albers), [rq1, rq2])
    expected_line_items = [
      ["Student Name", "Student Email", "Preferred Mentor Name","Preferred Mentor Email","Match Score", "Student's Preference", "Requested On", "Request"],
      ["rahim user", "userrahim@example.com", "Mentor Studenter", "mentrostud@example.com", "90%", "1", DateTime.localize(time1, format: :full_display).to_s, "This is message"],
      ["rahim user", "userrahim@example.com", "Good unique name", "robert@example.com", "90%", "2", DateTime.localize(time1, format: :full_display).to_s, "This is message"],
      ["student example", "rahim@example.com", "Good unique name", "robert@example.com", "90%", "1", DateTime.localize(time2, format: :full_display).to_s, "This is message2"],
      ["student example", "rahim@example.com", "Mentor Studenter", "mentrostud@example.com", "90%", "2", DateTime.localize(time2, format: :full_display).to_s, "This is message2"]
    ]
    assert_equal expected_line_items, csv_data
  end

  def test_header_for_exporting
    assert_equal ["Sender", "Recipient", "Request", "Sent"], MentorRequest.header_for_exporting
  end

  def test_data_for_exporting
    mentor_request = programs(:albers).mentor_requests.first
    assert_equal [["student_a example", "Good unique name", "Hi", DateTime.localize(mentor_request.created_at, format: :short)]], MentorRequest.data_for_exporting([mentor_request])
  end

  def test_export_to_stream
    mentor_request = programs(:albers).mentor_requests.first
    body = Enumerator.new do |stream|
      MentorRequest.export_to_stream(stream, users(:f_admin), [mentor_request.id])
    end
    csv_array = CSV.parse(body.to_a.join)
    assert_equal 2, csv_array.size
    assert_equal ["Sender", "Recipient", "Request", "Sent"], csv_array.first
    assert_equal ["student_a example", "Good unique name", "Hi", DateTime.localize(mentor_request.created_at, format: :short)], csv_array[1]
  end

  def test_sort_by_students
    prog = programs(:albers)
    requests = prog.mentor_requests
    assert_equal Program::SortUsersBy::FULL_NAME, prog.sort_users_by

    sorted_by_student_name = requests.sort {|a, b| a.student.name.downcase <=> b.student.name.downcase}
    sorted_by_student_last_name = requests.sort {|a, b| a.student.last_name.downcase <=> b.student.last_name.downcase}
    assert_equal sorted_by_student_name, MentorRequest.sort_by_student(requests, prog)
    prog.update_attribute(:sort_users_by, Program::SortUsersBy::LAST_NAME)
    assert_equal sorted_by_student_last_name, MentorRequest.sort_by_student(requests, prog)
  end

  def test_should_generate_csv_report
    admin = programs(:albers).admin_users.first
    # With favorite
    req = mentor_requests(:moderated_request_with_favorites)
    assert_emails(1) do
      MentorRequest.generate_and_email_report(admin, [req.id], 'active', :csv)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Your mentoring requests report is here!", email.subject)
    assert_match(/Mentoring Requests-.+\.csv/, email.attachments.first.filename)
    contents = email.attachments.first.body.raw_source.split("\n")[1].split(",")
    assert_false contents.include?("None")

    # Without favorite
    req = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
    assert_emails(1) do
      MentorRequest.generate_and_email_report(admin, [req.id], 'active', :csv)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Your mentoring requests report is here!", email.subject)
    assert_match(/Mentoring Requests-.+\.csv/, email.attachments.first.filename)
    contents = email.attachments.first.body.raw_source.split("\n")[1].split(",")
    assert_equal (1..4).map{"None"}, contents[2..5]
  end

  def test_should_generate_pdf_report
    admin = programs(:albers).admin_users.first
    reqs = []
    reqs << @first_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))

    MentorRequestReport::PDF.expects(:generate).returns("Test pdf content")

    assert_emails(1) do
      assert_no_difference "JobLog.count" do
        MentorRequest.generate_and_email_report(admin,  [1], "active", :pdf)
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Your mentoring requests report is here!", email.subject)
    assert_match(/Mentoring Requests-.+\.pdf/, email.attachments.first.filename)
  end

  def test_mentor_request_reminder
    MentorRequest.destroy_all
    time = Time.now.utc
    mentor_request_1 = MentorRequest.create!(:message => "ASDF", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))
    mentor_request_1.update_attributes(:created_at => (time.at_beginning_of_day - 10.day + 12.hour))
    mentor_request_2 = MentorRequest.create!(:message => "QWER", :program => programs(:albers), :student => users(:f_student), :mentor => users(:mentor_1))
    mentor_request_2.update_attributes(:created_at => (time.at_beginning_of_day - 9.day + 12.hour))
    mentor_request_3 = MentorRequest.create!(:message => "POIU", :program => programs(:albers), :student => users(:f_student), :mentor => users(:mentor_2))
    mentor_request_3.update_attributes(:created_at => (time.at_beginning_of_day - 11.day + 12.hour))

    programs(:albers).update_attribute(:needs_mentoring_request_reminder, false)
    programs(:albers).update_attribute(:mentoring_request_reminder_duration, 10)
    Push::Base.expects(:queued_notify).never
    assert_emails(0) do
      MentorRequest.send_mentor_request_reminders
    end
    programs(:albers).update_attribute(:needs_mentoring_request_reminder, true)
    programs(:albers).update_attribute(:mentoring_request_reminder_duration, 20)
    Push::Base.expects(:queued_notify).never
    assert_emails(0) do
      MentorRequest.send_mentor_request_reminders
    end
    programs(:albers).update_attribute(:needs_mentoring_request_reminder, true)
    programs(:albers).update_attribute(:mentoring_request_reminder_duration, 10)
    Push::Base.expects(:queued_notify).once
    assert_emails(1) do
      MentorRequest.send_mentor_request_reminders
    end

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal mentor_request_1.mentor.email, delivered_email.to[0]
    assert_match(/Reminder: You have a pending request from #{mentor_request_1.student.name}/, delivered_email.subject)
    assert_match(/ASDF/, get_html_part_from(delivered_email))
    assert_not_nil get_html_part_from(delivered_email).match('p/albers/mentor_requests')
    assert_not_nil get_html_part_from(delivered_email).match('src=email_rem')

    assert_not_nil mentor_request_1.reload.reminder_sent_time
    Push::Base.expects(:queued_notify).never
    assert_emails(0) do
      MentorRequest.send_mentor_request_reminders
    end
  end

  def test_can_convert_to_meeting_request
    ar =  MentorRequest.new(program: programs(:albers), allowed_request_type_change: AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST, status: AbstractRequest::Status::NOT_ANSWERED)

    ar.expects(:allow_request_type_change_from_mentor_to_meeting?).returns(false)
    assert_false ar.can_convert_to_meeting_request?

    ar.expects(:allow_request_type_change_from_mentor_to_meeting?).returns(true)
    ar.expects(:active?).returns(false)
    assert_false ar.can_convert_to_meeting_request?

    ar.expects(:allow_request_type_change_from_mentor_to_meeting?).returns(true)
    ar.expects(:active?).returns(true)
    Program.any_instance.expects(:dual_request_mode?).returns(false)
    assert_false ar.can_convert_to_meeting_request?

    ar.expects(:allow_request_type_change_from_mentor_to_meeting?).returns(true)
    ar.expects(:active?).returns(true)
    Program.any_instance.expects(:dual_request_mode?).returns(true)
    assert ar.can_convert_to_meeting_request?
  end

  def test_mentor_request_reminder_admin_matching
    MentorRequest.destroy_all
    time = Time.now.utc

    program = programs(:psg)

    mentor_request_1 = MentorRequest.create!(:message => "ASDF", :program => program, :student => users(:psg_student1))
    mentor_request_1.update_attributes(:created_at => (time.at_beginning_of_day - 10.day + 12.hour))
    mentor_request_2 = MentorRequest.create!(:message => "QWER", :program => program, :student => users(:psg_student2))
    mentor_request_2.update_attributes(:created_at => (time.at_beginning_of_day - 9.day + 12.hour))
    mentor_request_3 = MentorRequest.create!(:message => "POIU", :program => program, :student => users(:psg_student3))
    mentor_request_3.update_attributes(:created_at => (time.at_beginning_of_day - 11.day + 12.hour))

    program.update_attribute(:needs_mentoring_request_reminder, false)
    program.update_attribute(:mentoring_request_reminder_duration, 10)
    Push::Base.expects(:queued_notify).never
    assert_no_emails do
      MentorRequest.send_mentor_request_reminders
    end
    program.update_attribute(:needs_mentoring_request_reminder, true)
    program.update_attribute(:mentoring_request_reminder_duration, 20)
    Push::Base.expects(:queued_notify).never
    assert_no_emails do
      MentorRequest.send_mentor_request_reminders
    end
    program.update_attribute(:needs_mentoring_request_reminder, true)
    program.update_attribute(:mentoring_request_reminder_duration, 10)
    Push::Base.expects(:queued_notify).never
    assert_no_emails do
      MentorRequest.send_mentor_request_reminders
    end
    assert_nil mentor_request_1.reload.reminder_sent_time
  end

  def test_should_generate_pdf_report_with_job_uuid
    admin = programs(:albers).admin_users.first
    reqs = []
    reqs << @first_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => users(:f_student), :mentor => users(:f_mentor))

    MentorRequestReport::PDF.expects(:generate).returns("Test pdf content").twice

    assert_emails do
      assert_difference "JobLog.count" do
        MentorRequest.generate_and_email_report(admin, [1], "active", :pdf, "15")
      end
    end


    assert_no_emails do
      assert_no_difference "JobLog.count" do
        MentorRequest.generate_and_email_report(admin,  [1], "active", :pdf, "15")
      end
    end


    assert_emails do
      assert_difference "JobLog.count" do
        MentorRequest.generate_and_email_report(users(:f_mentor), [1], "active", :pdf, "15")
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        MentorRequest.generate_and_email_report(users(:f_mentor), [1], "active", :pdf, "15")
      end
    end
  end

  def test_to_be_closed_scope
    program = programs(:albers)
    program.update_attribute :mentor_request_expiration_days, 9

    assert_equal program.mentor_requests.to_be_closed.size, 0

    program.mentor_requests[0..1].each do |mr|
      mr.update_attribute :created_at, 10.days.ago
    end

    assert_equal program.mentor_requests.to_be_closed.size, 2
  end

  def test_close_request
    program = programs(:albers)
    program.update_attribute :mentor_request_expiration_days, 9
    mr = program.mentor_requests.last

    mr.stubs(:close!).with("This request was closed automatically since the mentor did not respond within 9 days.").at_least(1)
    mr.close_request!
  end

  def test_mentor_offers_withdrawn_when_request_is_accepted
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?
    offer = create_mentor_offer(:mentor => mentor, :student => mentee, :group => group)
    request = create_mentor_request(:student => mentee, :mentor => mentor, :program => programs(:albers))

    group.update_members(group.mentors + [users(:mentor_1)], group.students)
    assert group.mentors.include? users(:mentor_1)
    offer2 = create_mentor_offer(:mentor => users(:mentor_1), :student => mentee, :group => group)
    assert_emails(1) do
      request.mark_accepted!(group.reload)
    end
    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal request.student.email, delivered_email.to[0]
    #withdraw offer between mentee and mentor_1 if mentee is added to a group with the mentor_1 by some other mentor request acceptance
    assert_equal MentorOffer::Status::WITHDRAWN, offer.reload.status
    assert_equal MentorOffer::Status::WITHDRAWN, offer2.reload.status
  end

  def test_notify_expired_mentor_requests
    program = programs(:albers)
    program.update_attribute :mentor_request_expiration_days, 9
    assert_equal program.mentor_requests.to_be_closed.size, 0
    assert_no_emails do
      MentorRequest.notify_expired_mentor_requests
    end

    program.mentor_requests[0..1].each do |mr|
      mr.update_attribute :created_at, 10.days.ago
    end
    assert_equal program.mentor_requests.to_be_closed.size, 2
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, program.mentor_request_style
    assert_emails(2) do
      MentorRequest.notify_expired_mentor_requests
    end
  end
end
