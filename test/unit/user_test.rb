require_relative './../test_helper.rb'

class UserTest < ActiveSupport::TestCase

  def test_of_member_scope
    assert_equal_unordered [users(:f_student), users(:f_student_pbe), users(:f_student_nwen_mentor)], User.of_member(members(:f_student))
    assert_equal_unordered [users(:ceg_admin), users(:psg_admin)],
      User.of_member(members(:anna_univ_admin))
    assert_equal_unordered [users(:ceg_admin), users(:psg_admin)],
      User.of_member(members(:anna_univ_admin).id)
  end

  def test_of_program_scope
    assert_equal programs(:albers).all_users, User.in_program(programs(:albers))
    assert_equal programs(:ceg).all_users, User.in_program(programs(:ceg))
    assert_equal programs(:ceg).all_users, User.in_program(programs(:ceg).id)

    assert_equal_unordered(
      (programs(:ceg).all_users + programs(:albers).all_users),
      User.in_program([programs(:ceg), programs(:albers)])
    )

    assert_equal_unordered(
      (programs(:psg).all_users + programs(:ceg).all_users),
      User.in_program([programs(:ceg), programs(:psg)])
    )

    assert_equal_unordered(
      (programs(:ceg).all_users + programs(:albers).all_users),
      User.in_program([programs(:ceg), programs(:albers)])
    )
  end

  def test_in_organization_scope
    assert_equal_unordered programs(:org_primary).all_users.collect(&:id),
      User.in_organization(programs(:org_primary)).collect(&:id)
  end

  def test_quick_access_or_pinned_resources
    program = programs(:albers)
    m1 = program.get_role(RoleConstants::MENTOR_NAME).id
    s1 = program.get_role(RoleConstants::STUDENT_NAME).id
    user = users(:f_mentor)
    admin_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTORS)
    admin_view1 = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTEES)
    resource = create_resource(title: "title1", content: "content1", programs: { program => [m1, s1] } )
    resource_publication = program.resource_publications.create!(resource: resource, show_in_quick_links: false,position: 0)
    resource_publication.role_ids = [m1, s1]
    resource_publication.save

    resource1 = create_resource(title: "title2", content: "content2", programs: { program => [m1, s1] } )
    resource_publication1 = program.resource_publications.create!(resource: resource1, admin_view_id: admin_view.id, position: 1)
    resource_publication1.role_ids = [m1, s1]
    resource_publication1.save

    resource2 = create_resource(title: "title3", content: "content3", programs: { program => [m1, s1] } )
    resource_publication2 = program.resource_publications.create!(resource: resource2,  admin_view_id: admin_view.id, position: 2)
    resource_publication2.role_ids = [m1, s1]
    resource_publication2.save

    resource3 = create_resource(title: "title4", content: "content4", programs: { program => [m1, s1] } )
    resource_publication3 = program.resource_publications.create!(resource: resource2, admin_view_id: admin_view1.id, position: 2)
    resource_publication3.role_ids = [m1, s1]
    resource_publication3.save

    User.any_instance.expects(:get_accessible_admin_view_ids).returns([admin_view.id])
    resource_publications = ResourcePublication.where(id: [resource_publication.id, resource_publication1.id, resource_publication2.id, resource_publication3.id])
    assert_equal [resource_publication1, resource_publication2], user.get_quick_access_or_pinned_resources(resource_publications)
    User.any_instance.expects(:get_accessible_admin_view_ids).returns([admin_view.id, admin_view1.id])
    assert_equal [resource_publication1, resource_publication2, resource_publication3], user.get_quick_access_or_pinned_resources(resource_publications)
    resource_publication.update_attributes(show_in_quick_links: true)
    User.any_instance.expects(:get_accessible_admin_view_ids).returns([admin_view.id, admin_view1.id])
    assert_equal [resource_publication, resource_publication1, resource_publication2, resource_publication3], user.get_quick_access_or_pinned_resources(resource_publications)
  end

  def test_default_accessible_resources_for_pinnning
    program = programs(:albers)
    m1 = program.get_role(RoleConstants::MENTOR_NAME).id
    s1 = program.get_role(RoleConstants::STUDENT_NAME).id
    user = users(:f_mentor)
    admin_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTORS)
    resource = create_resource(title: "title1", content: "content1", programs: { program => [m1, s1] } )
    resource_publication = program.resource_publications.create!(resource: resource, show_in_quick_links: false,position: 0)
    resource_publication.role_ids = [m1, s1]
    resource_publication.save
    assert_equal resource, user.accessible_resources(default_pinned_resources: true).first

    resource1 = create_resource(title: "title2", content: "content2", programs: { program => [m1, s1] } )
    resource_publication1 = program.resource_publications.create!(resource: resource1, admin_view_id: admin_view.id, position: 1)
    resource_publication1.role_ids = [m1, s1]
    resource_publication1.save

    resource2 = create_resource(title: "title3", content: "content3", programs: { program => [m1, s1] } )
    resource_publication2 = program.resource_publications.create!(resource: resource2, admin_view_id: admin_view.id, position: 2)
    resource_publication2.role_ids = [m1, s1]
    resource_publication2.save

    pinned_resources = [resource1, resource2]
    assert_equal [resource1, resource2, resource], user.get_default_resources_for_pinning([resource1.id, resource2.id], pinned_resources, resources_widget: true)
    assert_equal [resource1, resource2], user.get_default_resources_for_pinning([resource1.id, resource2.id], pinned_resources)
    resource_publication.update_attributes(show_in_quick_links: true)

    resource3 = create_resource(title: "title4", content: "content4", programs: { program => [m1, s1] } )
    resource_publication3 = program.resource_publications.create!(resource: resource2, show_in_quick_links: true, admin_view_id: admin_view.id, position: 2)
    resource_publication3.role_ids = [m1, s1]
    resource_publication3.save
    pinned_resources = [resource, resource1, resource2, resource3]
    assert_equal [resource, resource1, resource2, resource3], user.get_default_resources_for_pinning([resource.id, resource1.id, resource2.id, resource3.id], pinned_resources)
  end

  def test_track_user_role_transtions
    user = users(:f_mentor)
    student_role = user.roles[0].program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    mentor_role = user.roles[0].program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    assert_equal_hash({"state" => {"from"=>nil, "to"=>"active"}, "role" => {"from"=>nil, "to"=>[mentor_role.id]}}, user.reload.state_transitions.first.info_hash)
    assert_equal_hash({role: {"from_role"=>[], "to_role"=>[]}}, user.reload.state_transitions.first.connection_membership_info_hash)
    user.roles = [mentor_role, student_role]
    user.reload.track_user_role_addition(student_role)
    assert_equal_hash({"state" => {"from"=>"active", "to"=>"active"}, "role" => {"from"=>[mentor_role.id], "to"=>[mentor_role.id, student_role.id]}}, user.reload.state_transitions.last.info_hash)
    user.reload.track_user_role_removal(student_role)
    assert_equal_hash({"state" => {"from"=>"active", "to"=>"active"}, "role" => {"from"=>[mentor_role.id, student_role.id], "to"=>[mentor_role.id]}}, user.reload.state_transitions.last.info_hash)
  end

  def test_sorted_users
    prog = programs(:albers)
    assert_equal Program::SortUsersBy::FULL_NAME, prog.sort_users_by
    assert prog.student_users.size > 1

    # Users sorted by full name
    names_sorted_by_full_name = prog.student_users.to_a.sort {|a,b| a.name.downcase <=> b.name.downcase}.collect(&:name)
    assert_equal names_sorted_by_full_name, User.sort(prog.student_users, prog).collect(&:name)

    # Users sorted by last name
    names_sorted_by_last_name = prog.student_users.to_a.sort {|a,b| a.last_name.downcase <=> b.last_name.downcase}.collect(&:name)
    prog.update_attribute(:sort_users_by, Program::SortUsersBy::LAST_NAME)
    assert_equal names_sorted_by_last_name, User.sort(prog.student_users, prog).collect(&:name)
  end

  def test_priority_array_for_match_score_sorting
    assert_equal [-10, -50], User.priority_array_for_match_score_sorting(10, 50)
    assert_equal [-10, 0], User.priority_array_for_match_score_sorting(10, nil)
    assert_equal [0, -50], User.priority_array_for_match_score_sorting(nil, "50")
  end

  def test_pending_mentor_request_of
    user = users(:f_mentor)
    assert_nil user.received_mentor_requests.active.from_student(users(:f_mentor_student)).first
    assert_false user.pending_mentor_request_of?(users(:f_mentor_student))
    mr = create_mentor_request(:mentor => user, :student => users(:f_mentor_student))
    assert_equal mr, user.pending_mentor_request_of?(users(:f_mentor_student))
  end

  def test_mentoring_mode_option_text
    user = users(:f_mentor)

    assert_equal user.mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING
    assert_equal user.mentoring_mode_option_text, "Ongoing and One-time Mentoring"

    user.update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    assert_equal user.mentoring_mode_option_text, "Ongoing Mentoring"

    user.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    assert_equal user.mentoring_mode_option_text, "One-time Mentoring"

    user.update_attribute(:mentoring_mode, User::MentoringMode::NOT_APPLICABLE)
    assert_equal user.mentoring_mode_option_text, "display_string.NA".translate
  end

  def test_new_mentor_requests_count
    user = users(:f_mentor)
    assert_equal 11, user.new_mentor_requests_count
    req = create_mentor_request(:mentor => user, :student => users(:f_student))
    assert_equal 12, user.new_mentor_requests_count
    create_mentor_request(:mentor => user, :student => users(:f_mentor_student))
    assert_equal 13, user.new_mentor_requests_count
    req.status = AbstractRequest::Status::REJECTED
    req.save(:validate => false)
    assert_equal 12, user.new_mentor_requests_count
  end

  def test_new_mentor_request_mail_should_bypass_pending_notif_and_deliver_immediately
    user = users(:f_mentor)
    req = nil
    [UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, UserConstants::DigestV2Setting::ProgramUpdates::DAILY, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY].each do |setting|
      user.program_notification_setting = setting
      assert_difference "ActionMailer::Base.deliveries.size", 1, "expected to send email if program_notification_setting is '#{setting}'" do
        req = create_mentor_request(:mentor => user, :student => users(:f_student))
      end
      assert req.program.matching_by_mentee_alone?
      req.destroy
    end

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      req = create_mentor_request(:mentor => user, :student => users(:f_student))
    end
    assert req.program.matching_by_mentee_alone?
    req.destroy
  end

  def test_is_available_for_mentoring
    user = users(:f_mentor)
    Program.any_instance.stubs(:consider_mentoring_mode?).returns(false)

    user.mentoring_mode = User::MentoringMode::ONGOING
    assert_false user.is_available_only_for_ongoing_mentoring?

    user.mentoring_mode = User::MentoringMode::ONE_TIME
    assert_false user.is_available_only_for_one_time_mentoring?

    user.mentoring_mode = User::MentoringMode::ONE_TIME_AND_ONGOING
    assert_false user.is_available_for_ongoing_and_one_time_mentoring?

    Program.any_instance.stubs(:consider_mentoring_mode?).returns(true)

    user.mentoring_mode = User::MentoringMode::ONGOING
    assert user.is_available_only_for_ongoing_mentoring?
    assert_false user.is_available_only_for_one_time_mentoring?
    assert_false user.is_available_for_ongoing_and_one_time_mentoring?

    user.mentoring_mode = User::MentoringMode::ONE_TIME
    assert user.is_available_only_for_one_time_mentoring?
    assert_false user.is_available_only_for_ongoing_mentoring?
    assert_false user.is_available_for_ongoing_and_one_time_mentoring?

    user.mentoring_mode = User::MentoringMode::ONE_TIME_AND_ONGOING
    assert user.is_available_for_ongoing_and_one_time_mentoring?
    assert_false user.is_available_only_for_ongoing_mentoring?
    assert_false user.is_available_only_for_one_time_mentoring?
  end

  def test_qa_question
    user = users(:f_student)
    q1 = create_qa_question(:user => user)
    q2 = create_qa_question(:user => user)
    assert_equal [q1, q2], user.qa_questions
    assert_difference('QaQuestion.count', -2) do
      user.destroy
    end
  end

  def test_state_changer_must_have_privileges
    student = users(:f_student)
    add_role_permission(fetch_role(:albers, :student), 'manage_user_states')
    assert users(:f_student).can_manage_user_states?
    assert users(:ceg_admin).can_manage_user_states?
    assert !users(:f_mentor).can_manage_user_states?

    # No permission
    student.state_changer = users(:f_mentor)
    assert_false student.valid?
    assert student.errors[:state_changer]

    # Priveleged user of some other program tries to reject
    student.state_changer = users(:ceg_admin)
    assert_false student.valid?
    assert student.errors[:state_changer]

    # Priveleged user
    student.state_changer = users(:rahim)
    assert student.valid?

    add_role_permission(fetch_role(:albers, :mentor), 'manage_user_states')
    student.state_changer = users(:f_mentor).reload
    assert student.valid?
  end

  def test_admin_create
    assert_difference "User.count" do
      create_user(:role_names => [RoleConstants::ADMIN_NAME])
    end
  end

  # Successful creation of user
  def test_user_create_success
    user = nil
    assert_nothing_raised do
      assert_difference "User.count" do
        user = create_user
      end
    end

    # The default notification setting should be all
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, user.program_notification_setting)
  end

  # User must belong to a program.
  def test_requires_program
    user = User.new
    assert_false user.valid?
    assert user.errors[:program]
  end

  # Test role is present and one among the valid values
  def test_requires_role_only_on_create
    user = programs(:albers).users.new
    assert_false user.valid?
    assert user.errors[:roles]

    # Removing a role of an existing user should not raise exception.
    assert_nothing_raised do
      users(:f_mentor).remove_role(RoleConstants::MENTOR_NAME)
    end
  end

  def test_reactivation_state_validations
    user = users(:f_mentor)
    member = user.member
    user.update_attribute :state, User::Status::SUSPENDED
    assert_false user.valid?
    assert_equal ["is not included in the list"], user.errors[:track_reactivation_state]
    assert_equal ["is not included in the list"], user.errors[:track_reactivation_state]

    user.update_attribute(:track_reactivation_state, User::Status::SUSPENDED)
    assert_false user.valid?
    assert_equal ["is not included in the list"], user.errors[:track_reactivation_state]
    assert_empty user.errors[:global_reactivation_state]

    member.update_attribute(:state, Member::Status::SUSPENDED)
    assert_false user.valid?
    assert_empty user.errors[:track_reactivation_state]
    assert_equal ["is not included in the list"], user.errors[:global_reactivation_state]

    user.update_attribute(:track_reactivation_state, User::Status::ACTIVE)
    assert_false user.valid?
    assert_empty user.errors[:track_reactivation_state]
    assert_equal ["is not included in the list"], user.errors[:global_reactivation_state]

    user.update_attribute(:global_reactivation_state, User::Status::ACTIVE)
    assert user.valid?
    user.update_attribute(:track_reactivation_state, nil)
    assert user.valid?
  end

  def test_check_cannot_reactivate_when_member_suspended
    user = users(:inactive_user)
    member = user.member
    assert member.suspended?
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member, "is suspended and hence the user cannot be reactivated" do
      user.reactivate_in_program!(users(:psg_admin), { global_reactivation: true })
    end

    member.update_attribute(:state, Member::Status::ACTIVE)
    assert_nothing_raised do
      user.reactivate_in_program!(users(:psg_admin), { global_reactivation: true })
    end
  end

  def test_cannot_add_suspended_member_to_program
    user = User.new
    user.program = programs(:no_mentor_request_program)
    user.role_names = [RoleConstants::MENTOR_NAME]
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member, "can't be blank" do
      user.save!
    end

    member = members(:f_mentor)
    member.update_attribute(:state, Member::Status::SUSPENDED)
    user.member = member
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member, "is suspended and hence cannot be added to the program" do
      user.save!
    end
  end

  def test_program_notification_setting
    assert_no_difference 'User.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :program_notification_setting do
        create_user(:program_notification_setting => 10, :role_names => [RoleConstants::MENTOR_NAME])
      end
    end

    assert_difference('User.count', 1) do
      create_user(:program_notification_setting => UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, :role_names => [RoleConstants::MENTOR_NAME], :name => "notify_test")
    end
  end


  def test_user_has_one_recommendation
    rahim = users(:rahim)
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal recommendation, rahim.mentor_recommendation
  end

  def test_mentor_recommendation_dependent_destroy
    rahim = users(:rahim)
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal recommendation, rahim.mentor_recommendation
    assert recommendation.valid?
    rahim.destroy
    assert_raise(ActiveRecord::RecordNotFound) do
      recommendation.reload
    end
  end

  def test_has_one_published_mentor_recommendation_published
    rahim = users(:rahim)
    expected_recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal expected_recommendation, rahim.published_mentor_recommendation
  end

  def test_has_one_published_mentor_recommendation_drafted
    rahim = users(:rahim)
    expected_recommendation = mentor_recommendations(:mentor_recommendation_1)
    expected_recommendation.status = MentorRecommendation::Status::DRAFTED
    expected_recommendation.save!
    assert_nil rahim.published_mentor_recommendation
  end

  def test_get_hash_notes
    rahim = users(:rahim)
    ram = users(:ram)
    robert = users(:robert)
    expected_notes_hash_rahim = {
      ram.id => "Test note 1 from the admin",
      robert.id => "Test note 2 from the admin"
    }
    assert_equal Hash.new, robert.get_notes_hash
    assert_equal expected_notes_hash_rahim, rahim.get_notes_hash
  end


  # Creation of user record with invalid max_connections_limit
  #
  def test_user_numericality_of_max_connections_limit
    assert_no_difference 'User.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :max_connections_limit do
        create_user(:max_connections_limit => "abcd", :role_names => [RoleConstants::MENTOR_NAME])
      end
    end
  end

  def test_member_of
    u = users(:ram)
    u.program = programs(:ceg)
    u.save

    assert u.member_of?(programs(:ceg))
  end

  # Named scopes for retrieving users based on roles, User.mentors,
  # User.students
  #
  def test_role_based_scopes
    students = User.all[0..4]
    mentors = User.all[5..9]
    students.each do |student|
      student.roles = [fetch_role(:albers, :student)]
      student.save!
    end

    mentors.each do |mentor|
      mentor.roles = [fetch_role(:albers, :mentor)]
      mentor.save!
    end

    assert_equal students, (students & User.students)
    assert_equal mentors, (mentors & User.mentors)
  end

  # User#students should return the students of the mentor via his group(s).
  def test_my_students
    mentor = users(:mentor_5)
    assert mentor.students.empty? # No students yet for the mentor

    assigned_students = []

    5.upto(14) do |i|
      student = users("student_#{i}".to_sym)

      if i % 2 == 0
        # Create a group with the given mentor and student.
        create_group(:mentors => [mentor], :students => [student], :program => programs(:albers))

        assigned_students << student
      end
    end

    assert_equal assigned_students.size, mentor.reload.mentoring_groups.size
    assert_equal_unordered assigned_students, mentor.students
    assert_equal_unordered assigned_students, mentor.students(:active)
    assert_equal_unordered assigned_students, mentor.students(:all)
    assert_equal [], mentor.students(:closed)
    assert_equal [], mentor.students(:drafted)
    assert_equal_unordered assigned_students, mentor.students(:active_or_drafted)

    group_to_terminate = mentor.mentoring_groups.first
    group_to_terminate.terminate!(users(:f_admin), "Test reason", group_to_terminate.program.permitted_closure_reasons.first.id)
    updated_students = assigned_students - group_to_terminate.students

    assert_equal assigned_students.size, mentor.reload.mentoring_groups.count
    assert_equal assigned_students.size - 1, mentor.reload.mentoring_groups.active.count
    assert_equal_unordered updated_students, mentor.students
    assert_equal_unordered updated_students, mentor.students(:active)
    assert_equal_unordered assigned_students, mentor.students(:all)
    assert_equal group_to_terminate.students, mentor.students(:closed)
    assert_equal [], mentor.students(:drafted)
    assert_equal_unordered updated_students, mentor.students(:active_or_drafted)
  end

  # User#students should return the students of the mentor via his group(s).
  def test_my_students_for_a_mentor_mentee_user
    user = create_user(:role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert user.students.empty? # No students yet for the mentor

    assigned_students = []

    # Create 10 students and assign some of them to the group.
    1.upto(10) do |i|
      student = create_user(:name => "student", :role_names => [RoleConstants::STUDENT_NAME], :email => "student_#{i}@chronus.com")

      if i % 2 == 0
        # Create a group with the given mentor and student.
        create_group(:mentors => [user], :students => [student], :program => programs(:albers))

        assigned_students << student
      end
    end

    1.upto(3) do |i|
      mentor = create_user(:name => "mentor", :role_names => [RoleConstants::MENTOR_NAME], :email => "mentor_#{i}@chronus.com")
      create_group(:mentors => [mentor], :students => [user], :program => programs(:albers))
    end

    assert_equal_unordered assigned_students, user.reload.students
  end

  # User#mentors should return the mentors of the student via his group(s).
  def test_my_mentors
    # Create a student
    student= create_user(:role_names => [RoleConstants::STUDENT_NAME])
    assert student.mentors.empty? # No mentor yet for the student

    mentors = []

    # Create 10 mentors and make some of them the mentor of the student.
    1.upto(10) do |i|
      mentor = create_user(:name => "student", :role_names => [RoleConstants::MENTOR_NAME], :email => "student_#{i}@chronus.com")

      if i % 2 == 0
        # Create a group with the given mentor and student.
        create_group(:mentors => [mentor], :students => [student], :program => programs(:albers))

        mentors << mentor
      end
    end

    assert_equal 5, student.reload.studying_groups.count
    assert_equal_unordered mentors, student.mentors
    assert_equal_unordered mentors, student.mentors(:active)
    assert_equal_unordered mentors, student.mentors(:all)
    assert_equal [], student.mentors(:closed)
    assert_equal [], student.mentors(:drafted)
    assert_equal_unordered mentors, student.mentors(:published)

    group_to_terminate = student.studying_groups.first
    group_to_terminate.terminate!(users(:f_admin), "Test reason", group_to_terminate.program.permitted_closure_reasons.first.id)
    updated_mentors = mentors - group_to_terminate.mentors

    assert_equal 5, student.reload.studying_groups.count
    assert_equal 4, student.reload.studying_groups.active.count
    assert_equal_unordered updated_mentors, student.mentors
    assert_equal_unordered updated_mentors, student.mentors(:active)
    assert_equal_unordered mentors, student.mentors(:all)
    assert_equal group_to_terminate.mentors, student.mentors(:closed)
    assert_equal [], student.mentors(:drafted)
    assert_equal_unordered mentors, student.mentors(:published)
  end

  def test_ordered_viewed_by_users_from_last_program_update
    user = users(:f_mentor)
    u1 = users(:f_student)
    u2 = users(:f_mentor_student)
    ProfileView.create!(user: user, viewed_by: u1)
    ProfileView.create!(user: user, viewed_by: u2)
    assert_equal [u2, u1], user.ordered_viewed_by_users_from_last_program_update(5)
    assert_equal [u2], user.ordered_viewed_by_users_from_last_program_update(1)
    assert_equal [], user.ordered_viewed_by_users_from_last_program_update(0)
    assert u2.respond_to?(:visible_to?)
    User.any_instance.expects(:visible_to?).twice.returns(false)
    assert_equal [], user.ordered_viewed_by_users_from_last_program_update(5)
  end

  def test_digest_v2_work_or_education
    user = users(:f_mentor)
    assert_equal_hash({:company=>"Microsoft", :key=>:experience_with_job_title, :job_title=>"Lead Developer"}, user.digest_v2_work_or_education)
    user.member.experiences[1].current_job = true
    assert_equal_hash({:company=>"Mannar", :key=>:experience_with_job_title, :job_title=>"Chief Software Architect And Programming Lead"}, user.digest_v2_work_or_education)
    user.member.experiences[1].job_title = nil
    assert_equal_hash({:company=>"Mannar", :key=>:experience_without_job_title}, user.digest_v2_work_or_education)
    user.member.experiences.each{|exp| exp.destroy}
    assert_equal_hash({:school_name=>"Indian college", :key=>:school_name}, user.reload.digest_v2_work_or_education)
  end

  def test_get_selected_connection_membership_and_details_for_digest_v2
    user = users(:f_mentor)
    assert_false user.digest_v2_group_update_required?
    selected_connection_memberships, selected_connection_membership_details = user.get_selected_connection_membership_and_details_for_digest_v2
    assert_equal [], selected_connection_memberships
    assert_equal_hash({}, selected_connection_membership_details)
    user.last_group_update_sent_time = 1.year.ago
    assert_equal 1, user.connection_memberships.size
    membership = user.connection_memberships[0]
    selected_connection_memberships, selected_connection_membership_details = user.get_selected_connection_membership_and_details_for_digest_v2
    assert_equal [], selected_connection_memberships
    assert_equal [membership.id], selected_connection_membership_details.keys
    assert_equal [], selected_connection_membership_details[membership.id][:upcoming_tasks]
    assert_equal [], selected_connection_membership_details[membership.id][:pending_tasks]
    assert_equal [], selected_connection_membership_details[membership.id][:pending_notifications]
    membership.send_email(user, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE, nil, nil, {})
    membership.reload
    user.reload
    user.last_group_update_sent_time = 1.year.ago
    selected_connection_memberships, selected_connection_membership_details = user.get_selected_connection_membership_and_details_for_digest_v2
    assert_equal [membership], selected_connection_memberships
    assert_equal_hash({membership.id => {upcoming_tasks: [], pending_tasks: [], pending_notifications: membership.pending_notifications}}, selected_connection_membership_details)

    User.any_instance.stubs(:digest_v2_group_update_required?).returns(true)
    user = users(:pbe_mentor_0)
    student = users(:pbe_student_0)
    membership = user.connection_memberships[0]
    topic = create_topic(forum: membership.group.forum, user: student)
    assert user.program.project_based?
    assert membership.group.pending?
    selected_connection_memberships, selected_connection_membership_details = user.reload.get_selected_connection_membership_and_details_for_digest_v2
    assert_equal [membership], selected_connection_memberships
    assert_equal_hash({membership.id => {upcoming_tasks: [], pending_tasks: [], pending_notifications: membership.reload.pending_notifications}}, selected_connection_membership_details)
    post1 = create_post(topic: topic, user: student)
    post2 = create_post(topic: topic, user: student)
    ViewedObject.create(ref_obj: post1, user: user)
    selected_connection_memberships, selected_connection_membership_details = user.reload.get_selected_connection_membership_and_details_for_digest_v2
    assert_equal_hash({membership.id => {upcoming_tasks: [], pending_tasks: [], pending_notifications: [membership.reload.pending_notifications.last]}}, selected_connection_membership_details)
    ViewedObject.create(ref_obj: post2, user: user)
    selected_connection_memberships, selected_connection_membership_details = user.reload.get_selected_connection_membership_and_details_for_digest_v2
    assert_equal_hash({membership.id => {upcoming_tasks: [], pending_tasks: [], pending_notifications: []}}, selected_connection_membership_details)
  end

  def test_is_topic_or_post_viewed
    group = groups(:mygroup)
    group.mentoring_model = mentoring_models(:mentoring_models_1)
    group.mentoring_model.allow_forum = true
    group.save
    group.create_group_forum
    mentor = group.mentors.first
    student = group.students.first
    topic1 = create_topic(forum: group.forum, user: mentor)
    post1 = create_post(topic: topic1, user: mentor)
    post2 = create_post(topic: topic1, user: mentor)
    assert_false student.is_topic_or_post_viewed?(topic1)
    assert_false student.is_topic_or_post_viewed?(post1)
    assert_false student.is_topic_or_post_viewed?(post2)
    ViewedObject.create(ref_obj: post1, user: student)
    assert student.is_topic_or_post_viewed?(topic1)
    assert student.is_topic_or_post_viewed?(post1)
    assert_false student.is_topic_or_post_viewed?(post2)
    ViewedObject.create(ref_obj: post2, user: student)
    assert student.is_topic_or_post_viewed?(post2)
  end

  def test_get_received_requests_count_and_action
    user = users(:f_mentor)
    assert_equal [12, [:meeting_requests_url, {}]], user.get_received_requests_count_and_action
    user.received_meeting_requests.destroy_all
    assert_equal [11, [:mentor_requests_url, { filter: AbstractRequest::Filter::TO_ME }]], user.reload.get_received_requests_count_and_action
    user.received_mentor_requests.destroy_all
    user = users(:f_student)
    create_mentor_offer
    user.received_meeting_requests.destroy_all
    user.received_mentor_requests.destroy_all
    assert_equal [1, [:mentor_offers_url, {}]], user.reload.get_received_requests_count_and_action
    user.received_mentor_offers.destroy_all
    assert_equal [0, [{}]], user.reload.get_received_requests_count_and_action
  end

  def test_immediate_program_update
    user = users(:f_mentor)
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    assert user.immediate_program_update?
    (UserConstants::DigestV2Setting::ProgramUpdates.all - [UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE]).each do |other_state|
      user.program_notification_setting = other_state
      assert_false user.immediate_program_update?
    end
  end

  def test_digest_v2_program_update
    user = users(:f_mentor)
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    assert_false user.digest_v2_program_update?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND
    assert_false user.digest_v2_program_update?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::NONE
    assert_false user.digest_v2_program_update?
    (UserConstants::DigestV2Setting::ProgramUpdates.all - [UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND, UserConstants::DigestV2Setting::ProgramUpdates::NONE]).each do |other_state|
      user.program_notification_setting = other_state
      assert user.digest_v2_program_update?
    end
  end

  def test_digest_v2_group_update_required
    user = users(:f_mentor)
    user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::WEEKLY
    user.last_group_update_sent_time = 2.weeks.ago
    assert user.digest_v2_group_update_required?
    user.last_group_update_sent_time = 1.day.ago
    assert_false user.digest_v2_group_update_required?
    user.last_group_update_sent_time = 2.weeks.ago
    assert user.digest_v2_group_update_required?
    user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::DAILY
    assert user.digest_v2_group_update_required?
    user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::NONE
    assert_false user.digest_v2_group_update_required?
  end

  def test_digest_v2_program_update_required
    user = users(:f_mentor)
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    user.last_program_update_sent_time = 2.weeks.ago
    assert user.digest_v2_program_update_required?
    user.last_program_update_sent_time = 1.day.ago
    assert_false user.digest_v2_program_update_required?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    user.last_program_update_sent_time = 2.weeks.ago
    assert_false user.digest_v2_program_update_required?
    user.last_program_update_sent_time = 1.day.ago
    assert_false user.digest_v2_program_update_required?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    user.last_program_update_sent_time = 2.weeks.ago
    assert user.digest_v2_program_update_required?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    assert user.digest_v2_program_update_required?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    assert user.digest_v2_program_update_required?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    assert_false user.digest_v2_program_update_required?
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::NONE
    assert_false user.digest_v2_program_update_required?
  end

  def test_digest_v2_required
    user = users(:f_mentor)
    user.expects(:digest_v2_group_update_required?).returns(true)
    assert user.digest_v2_required?
    user.expects(:digest_v2_group_update_required?).returns(false)
    user.expects(:digest_v2_program_update_required?).returns(true)
    assert user.digest_v2_required?
    user.expects(:digest_v2_group_update_required?).returns(false)
    user.expects(:digest_v2_program_update_required?).returns(false)
    assert_false user.digest_v2_required?
  end

  def test_set_last_weekly_updates_sent_time
    user = users(:f_mentor)
    time_now = Time.now
    Timecop.freeze(time_now) do
      user.send(:set_last_weekly_updates_sent_time)
      assert_equal time_now.to_i, user.last_program_update_sent_time.to_time.to_i
      assert_equal time_now.to_i, user.last_group_update_sent_time.to_time.to_i
    end
  end

  def test_get_selected_connection_memberships_priority_for_digest_v2
    user = users(:f_mentor)
    details = {pending_tasks: [1], upcoming_tasks: [2], pending_notifications: [3]}
    assert_equal 0, user.send(:get_selected_connection_memberships_priority_for_digest_v2, details)
    details[:pending_tasks] = []
    assert_equal 1, user.send(:get_selected_connection_memberships_priority_for_digest_v2, details)
    details[:upcoming_tasks] = []
    assert_equal 2, user.send(:get_selected_connection_memberships_priority_for_digest_v2, details)
    details[:pending_notifications] = []
    assert_equal 3, user.send(:get_selected_connection_memberships_priority_for_digest_v2, details)
  end

  def test_digest_v2_update_start_time
    user = users(:f_mentor)
    time_now = Time.now
    Timecop.freeze(time_now) do
      assert_equal ((time_now - 5.days) + DigestV2Utils::Trigger::ALLOWED_HOURS_TO_SEND_EMAILS.hours).to_i, user.send(:digest_v2_update_start_time, 5).to_i
    end
  end

  def test_digest_v2_group_update_start_time
    user = users(:f_mentor)
    time_now = Time.now
    Timecop.freeze(time_now) do
      user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::WEEKLY
      assert_equal ((time_now - 7.days) + DigestV2Utils::Trigger::ALLOWED_HOURS_TO_SEND_EMAILS.hours).to_i, user.send(:digest_v2_group_update_start_time).to_i
    end
  end

  def test_digest_v2_program_update_start_time
    user = users(:f_mentor)
    time_now = Time.now
    Timecop.freeze(time_now) do
      user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
      assert_equal ((time_now - 7.days) + DigestV2Utils::Trigger::ALLOWED_HOURS_TO_SEND_EMAILS.hours).to_i, user.send(:digest_v2_program_update_start_time).to_i
    end
  end

  def test_studying_groups_and_mentor_connections_map
    assert_empty users(:f_student).studying_groups
    assert_equal({}, users(:f_student).mentor_connections_map)

    assert_equal [groups(:group_4)], users(:student_4).studying_groups
    assert_equal({}, users(:student_4).mentor_connections_map)

    assert_equal_unordered [groups(:old_group), groups(:group_2), groups(:group_inactive)], users(:student_2).studying_groups
    assert_equal( { users(:robert) => [groups(:old_group)], users(:not_requestable_mentor) => [groups(:group_2)], users(:mentor_1) => [groups(:group_inactive)] }, users(:student_2).mentor_connections_map)

    assert_equal [groups(:multi_group)], users(:psg_student1).studying_groups
    assert_equal( { users(:psg_mentor1) => [groups(:multi_group)], users(:psg_mentor2) => [groups(:multi_group)], users(:psg_mentor3) => [groups(:multi_group)] }, users(:psg_student1).mentor_connections_map)
  end

  def test_mentoring_groups_and_mentee_connections_map
    assert_empty users(:mentor_3).mentoring_groups
    assert_equal({}, users(:mentor_3).mentee_connections_map)

    assert_equal [groups(:group_4)], users(:requestable_mentor).mentoring_groups
    assert_equal({}, users(:requestable_mentor).mentee_connections_map)

    assert_equal_unordered [groups(:group_5), groups(:group_inactive), groups(:drafted_group_2), groups(:drafted_group_3)], users(:mentor_1).mentoring_groups
    assert_equal( { users(:student_1) => [groups(:group_5)], users(:student_2) => [groups(:group_inactive)], users(:student_3) => [groups(:drafted_group_2)], users(:drafted_group_user) => [groups(:drafted_group_3)] }, users(:mentor_1).mentee_connections_map)

    assert_equal [groups(:multi_group)], users(:psg_mentor1).mentoring_groups
    assert_equal( { users(:psg_student1) => [groups(:multi_group)], users(:psg_student2) => [groups(:multi_group)], users(:psg_student3) => [groups(:multi_group)] }, users(:psg_mentor1).mentee_connections_map)
  end

  def test_should_create_recent_activity_on_mentor_create
    assert_difference 'RecentActivity.count' do
      @user = create_user(:role_names => [RoleConstants::MENTOR_NAME])
    end

    activity = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTOR_JOIN_PROGRAM, activity.action_type
    assert_equal RecentActivityConstants::Target::ADMINS, activity.target

    assert_nil activity.for
    assert_equal @user, activity.get_user(@user.program)
    assert_equal [@user.program], activity.programs
    assert_equal @user.id, activity.ref_obj_id
    assert_equal User.name, activity.ref_obj_type

    assert_difference 'RecentActivity.count', -1 do
      @user.destroy
    end
  end

  # Email is sent only from controller. So, no model callback should trigger
  # email delivery
  #
  def test_should_not_deliver_mail_for_mentor_create
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      create_user(:role_names => [RoleConstants::MENTOR_NAME])
    end
  end

  def test_user_recent_scope
    month_old_users = User.all[0..4]
    month_old_users.each do |user|
      user.update_attribute :created_at, 25.days.ago
    end

    week_old_users = User.all[5..9]
    week_old_users.each do |user|
      user.update_attribute :created_at, 5.days.ago
    end

    assert_equal(week_old_users, (week_old_users & User.recent(1.week.ago)))
    assert_equal(month_old_users, (month_old_users & User.recent(1.month.ago)))
  end

  def test_show_recommended_ongoing_mentors
    mentor = users(:f_mentor)
    student = users(:f_student)
    assert student.show_recommended_ongoing_mentors?
    assert_false mentor.show_recommended_ongoing_mentors?
  end

  def test_received_mentor_requests
    mentor = users(:f_mentor)

    requests = MentorRequest.where(receiver_id: mentor.id).to_a
    assert_equal requests, mentor.received_mentor_requests
  end

  def test_sent_mentor_requests
    student = users(:f_student)
    mentors = []
    requests = []

    # No requests yet.
    assert student.sent_mentor_requests.empty?

    2.times do |i|
      user = create_user(:name => "student", :role_names => [RoleConstants::MENTOR_NAME], :email => "student_#{i}@chronus.com")
      mentors << user

      requests << MentorRequest.create!(:student => student, :mentor => user, :program => programs(:albers), :message => "Hi")
    end

    # Create another request which was not sent by the student.
    MentorRequest.create!(:student => create_user(:name => "name_mentor", :role_names => [RoleConstants::STUDENT_NAME]), :mentor => users(:f_mentor),
      :program => programs(:albers), :message => "Hi")

    assert_equal requests, student.reload.sent_mentor_requests

    #Testing the dependent destroy
    assert_difference "MentorRequest.count", -2 do
      student.destroy
    end
  end

  def test_received_project_requests
    user = users(:f_admin_pbe)
    req = ProjectRequest.create!(:message => "Hi", :sender_id => users(:f_student_pbe).id, :sender_role_id => users(:f_student_pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).id, :group_id => groups(:group_pbe_1).id, :program => programs(:pbe))
    req.mark_accepted(user)
    assert_equal_unordered [req], user.received_project_requests
  end

  def test_sent_project_requests
    student = users(:f_student_pbe)
    requests = []
    5.times do |i|
      req = ProjectRequest.create!(:message => "Hi", :sender_id => student.id, :group_id => groups("group_pbe_#{i}").id, :program => programs(:pbe))
      requests << req
    end
    assert_equal_unordered requests, student.sent_project_requests
  end

  def test_recently_joined
    user = create_user

    # New user, joined just now.
    assert user.recently_joined?

    User.skip_timestamping do
      user.created_at = Time.now - (User::NEW_USER_PERIOD + 1.minute)
      user.save!
    end

    # No more a new user
    assert !user.recently_joined?
  end

  def test_send_email_for_notification_setting_all
    p = create_post(topic: create_old_topic)
    # Notification setting is ALL
    u = create_user
    ChronusMailer.expects(:forum_notification).once.with(u, p, {}).returns(stub(:deliver_now))
    u.send_email(p, RecentActivityConstants::Type::POST_CREATION)
  end

  def test_message_is_sent_to_suspended_user
    member = members(:f_student)
    members(:f_student).update_attribute :state, Member::Status::SUSPENDED

    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference('PendingNotification.count') do
        create_message(:sender => members(:f_admin), :receiver => member)
      end
    end
  end

  def test_send_email_for_notification_setting_aggregate
    p = create_post(topic: create_old_topic)
    # Notification setting is DAILY_DIGEST
    u = create_user(:program_notification_setting => UserConstants::DigestV2Setting::ProgramUpdates::DAILY)

    notif = nil
    assert_difference('PendingNotification.count') do
      notif = u.send_email(p, RecentActivityConstants::Type::POST_CREATION)
    end
    assert_equal(u, notif.ref_obj_creator)
    assert_equal(p, notif.ref_obj)
    assert_equal(u.program, notif.program)
    assert_equal([notif], u.reload.pending_notifications)
  end

  def test_send_email_for_notification_setting_weekly_digest
    p = create_post(topic: create_old_topic)
    # Notification setting is WEEKLY_DIGEST
    u = create_user(:program_notification_setting => UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY)

    notif = nil
    assert_difference('PendingNotification.count') do
      notif = u.send_email(p, RecentActivityConstants::Type::POST_CREATION)
    end
    assert_equal(u, notif.ref_obj_creator)
    assert_equal(p, notif.ref_obj)
    assert_equal(u.program, notif.program)
    assert_equal([notif], u.reload.pending_notifications)
  end

  def test_deleting_a_user_deletes_pending_notifications
    p = create_post(topic: create_old_topic)
    # Notification setting is ALL
    u = create_user(:program_notification_setting => UserConstants::DigestV2Setting::ProgramUpdates::DAILY)
    u.send_email(p, RecentActivityConstants::Type::POST_CREATION)

    assert_difference('PendingNotification.count', -1) do
      assert_difference('User.count', -1) do
        u.destroy
      end
    end
  end

  def test_pending_notifications_should_dependent_destroy_on_user_deletion
    student  = users(:f_student)
    mentor = users(:f_mentor)
    #Testing has_many association
    pending_notifications = []
    action_types = [RecentActivityConstants::Type::USER_SUSPENSION, RecentActivityConstants::Type::USER_CAMPAIGN_EMAIL_NOTIFICATION]
    assert_difference "PendingNotification.count", 2 do
        action_types.each do |action_type|
            pending_notifications << student.pending_notification_references.create!(
            ref_obj_creator: mentor,
            ref_obj: student,
            program: student.program,
            action_type: action_type)
        end
    end
    #Testing dependent destroy
    assert_equal pending_notifications, student.pending_notification_references
    assert_difference 'User.count', -1 do
      assert_difference 'PendingNotification.count', -2 do
        student.destroy
      end
    end
  end

  def test_same_member
    assert users(:f_mentor).same_member?(users(:f_mentor))
    assert_false users(:f_mentor).same_member?(users(:f_student))
    assert users(:f_mentor).same_member?(users(:f_mentor_nwen_student))
  end

  def test_my_request_loosely_managed
    student = users(:f_student)
    mentor_1 = users(:f_mentor)
    mentor_2 = users(:robert)
    assert_nil student.my_request(:to_mentor => mentor_1)
    assert_nil student.my_request(:to_mentor => mentor_2)

    req_1 = create_mentor_request(:student => student, :mentor => mentor_1)
    req_2 = create_mentor_request(:student => student, :mentor => mentor_2)
    assert_equal req_1, student.my_request(:to_mentor => mentor_1)
    assert_equal req_2, student.my_request(:to_mentor => mentor_2)
  end

  def test_new_from_params_for_student
    prog = programs(:albers)
    me = create_member(:first_name => "student", :last_name => "Test", :email => "student@email.com")
    assert_difference 'User.count' do
      uobj = User.new_from_params(
        :member => me,
        :program => prog,
        :created_by => users(:f_admin),
        :role_names => [RoleConstants::STUDENT_NAME],
        :creation_source => User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED
      )
      uobj.save!
    end

    u = User.last
    assert_equal(programs(:albers), u.program)
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, u.program_notification_setting)
    assert_equal User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED, u.creation_source
  end

  def test_valid_creation_source
    assert User::CreationSource.valid_creation_source? User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED
    assert User::CreationSource.valid_creation_source? User::CreationSource::UNKNOWN
  end

  def test_create_from_params_failure
    cu = create_member(:email => "mentor@email.com")
    assert_no_difference 'User.count' do
      # No roles
      u = User.new_from_params(
        :member => cu,
        :program => programs(:albers),
        :created_by => users(:f_admin)
      )

      assert_false u.valid?
    end
  end

  def test_create_with_new_from_params_should_create_recent_activity_admin_add_type
    cu = create_member
    assert_difference 'RecentActivity.count' do
      assert_difference 'User.count' do
        opts = {:program => programs(:albers), :created_by => users(:f_admin),
          :name => "Mentor Test", :email => "mentor@email.com",
          :role_names => [RoleConstants::MENTOR_NAME], :member => cu}
        u = User.new_from_params(opts)
        assert u.save
      end
    end

    activity = RecentActivity.last
    @user = User.last
    assert_equal RecentActivityConstants::Type::ADMIN_ADD_MENTOR, activity.action_type
    assert_equal RecentActivityConstants::Target::ADMINS, activity.target

    assert_nil activity.for
    assert_equal @user, activity.get_user(@user.program)
    assert_equal [@user.program], activity.programs
    assert_equal @user.id, activity.ref_obj_id
    assert_equal User.name, activity.ref_obj_type
  end

  def test_notification_for_imported_profile_from_another_program
    programs(:nwen).roles.find_by(name: RoleConstants::ADMIN_NAME).customized_term.update_attribute :term, "Manager"
    programs(:nwen).roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attributes({:term => "Advisor" , :term_downcase => "advisor"})
    user = programs(:nwen).users.new
    user.member = members(:mentor_3)
    user.created_by = users(:f_admin)
    user.imported_from_other_program = true
    user.role_names = [RoleConstants::MENTOR_NAME]

    UserObserver.expects(:delay).returns(UserObserver).once

    assert_difference 'RecentActivity.count' do
      assert_emails 1 do
        assert_difference 'User.count' do
          user.save!
        end
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [user.email], email.to
    assert_equal "#{user.first_name}, #{users(:f_admin).name} invites you to join as a mentor!", email.subject

    activity = RecentActivity.last
    assert_equal RecentActivityConstants::Type::ADMIN_ADD_MENTOR, activity.action_type
    assert_equal RecentActivityConstants::Target::ADMINS, activity.target
  end

  def test_answer_for
    org_q = create_question(:organization => programs(:org_primary))
    user = User.includes([:member => :profile_answers]).find(2)

    assert_nil user.answer_for(org_q)
    a1 = ProfileAnswer.create!(:profile_question => org_q, :answer_text => "Whatever", :ref_obj => user.member)
    assert_equal a1, user.answer_for(org_q)
  end

  def test_save_answer_should_success
    user = users(:f_student)
    question = profile_questions(:single_choice_q)
    assert user.save_answer!(question, "opt_2"), "expected save_answer to success"
    assert_equal "opt_2", user.answer_for(question).answer_value
  end

  def test_save_answer_should_remove_answer
    user = users(:f_student)
    question = profile_questions(:single_choice_q)
    assert_raise ActiveRecord::RecordInvalid do
      assert !user.save_answer!(question, "aha"), "expected save_answer to fail"
    end
    assert_nil user.answer_for(question)
  end

  def test_save_answer_should_remove_answer_if_invalid_location
    user = users(:f_mentor)
    question = profile_questions(:profile_questions_3)
    assert_no_difference "Location.count" do
      assert user.save_answer!(question, "Some Unknown Town"), "expected save_answer to success"
      assert_nil user.answer_for(question)
    end
  end

  def test_save_answer_should_success_for_existion_location
    user = users(:f_mentor)
    question = profile_questions(:profile_questions_3)
    answer = profile_answers(:location_chennai_ans)
    assert_no_difference "Location.count" do
      assert user.save_answer!(question, "New Delhi, Delhi, India"), "expected save_answer to success"
      assert_instance_of ProfileAnswer, user.answer_for(question)
      assert_equal "New Delhi, Delhi, India", user.answer_for(question).answer_text
      assert_instance_of Location, user.answer_for(question).location
    end
  end

  def test_save_answer
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    user = users(:mentor_7)

      assert_difference("ProfileAnswer.count") do
        assert user.save_answer!(q, "Abc")
      end

    ans = ProfileAnswer.last
    assert_equal(q, ans.profile_question)
    assert_equal(user.member, ans.ref_obj)
    assert_equal("Abc", ans.answer_value)

    assert_difference("ProfileAnswer.count") do
        assert user.save_answer!(profile_questions(:string_q), "Great")
      end

    ans = ProfileAnswer.last
    assert_equal("Great", ans.answer_value)
    assert_equal(profile_questions(:string_q), ans.profile_question)
    assert_equal(ans.ref_obj, user.member)
  end

  def test_save_answer_failure
    # Answer contains an invalid choice. Answer should not be created
    assert_no_difference("ProfileAnswer.count") do
      assert_raise ActiveRecord::RecordInvalid do
        assert !users(:mentor_5).save_answer!(profile_questions(:multi_choice_q), ["Klm"])
      end
    end
  end

  def test_user_save_answer_for_existing_answer
    user = users(:f_mentor)
    existing_ans_1 = user.answer_for(profile_questions(:multi_choice_q))
    existing_ans_2 = user.answer_for(profile_questions(:single_choice_q).reload)

    assert_equal ['Stand', 'Run'], existing_ans_1.answer_value
    assert_equal "opt_1", existing_ans_2.answer_value

    assert_no_difference("ProfileAnswer.count") do
      assert user.save_answer!(profile_questions(:multi_choice_q), ["Walk"])
      assert user.save_answer!(profile_questions(:single_choice_q), "opt_2")
    end

    assert_equal ['Walk'], existing_ans_1.reload.answer_value
    assert_equal 'opt_2', existing_ans_2.reload.answer_value
  end

  def test_user_save_answer_new_member_attribute
    user = users(:f_mentor)
    existing_ans_1 = user.answer_for(profile_questions(:multi_choice_q))
    assert_equal ['Stand', 'Run'], existing_ans_1.answer_value

    assert_raise ActiveRecord::RecordInvalid, "Validation failed: Profile question has already been taken" do
      assert user.save_answer!(profile_questions(:multi_choice_q), ["Walk"], true)
    end
    assert_equal ['Stand', 'Run'], existing_ans_1.reload.answer_value
  end

  def test_can_receive_mentoring_requests
    create_mentor_offer
    # users(:f_mentor) now has 1 connection, 1 sent_mentor_offer and 11 active mentoring_requests
    mentor = users(:f_mentor)
    student = users(:f_student)

    mentor.update_attribute(:max_connections_limit, 13)
    assert_false mentor.reload.can_receive_mentoring_requests?

    mentor.update_attribute(:max_connections_limit, 14)
    assert mentor.reload.can_receive_mentoring_requests?

    assert_false student.is_mentor?
    student.update_attribute(:max_connections_limit, 14)
    assert_false student.reload.can_receive_mentoring_requests?
  end

  def test_can_mentor
    # users(:f_mentor) has currently one connection and limit of two
    assert users(:f_mentor).can_mentor?

    create_group(:mentor => users(:f_mentor))
    assert !users(:f_mentor).reload.can_mentor?

    student = users(:f_student)
    assert_false student.is_mentor?
    student.update_attribute(:max_connections_limit, 5)
    assert_false student.reload.can_mentor?
  end

  def test_get_favorite_mentor
    assert_nil users(:f_student).get_user_favorite(users(:f_mentor))

    user_fav = create_favorite
    assert_equal user_fav, users(:f_student).reload.get_user_favorite(users(:f_mentor))
  end

  # Should be a student belonging to moderated groups
  def test_student_of_moderated_groups
    assert !users(:f_student).student_of_moderated_groups?
    assert !users(:f_mentor).student_of_moderated_groups?

    assert users(:moderated_student).reload.student_of_moderated_groups?
    assert !users(:moderated_mentor).reload.student_of_moderated_groups?
  end

  def test_can_send_mentor_request
    program = programs(:moderated_program)
    user = users(:f_student)
    user.program.update_attributes!(min_preferred_mentors: 0)

    #The student is not part of a moderated group
    assert user.ready_to_request?

    make_member_of(:moderated_program, :f_student)
    # The student dont have favorite, also min preferred mentors is 2
    assert user.ready_to_request?

    program.update_attribute(:min_preferred_mentors, 2)
    # The min preferred mentors is 2
    assert_false user.reload.ready_to_request?

    create_favorite
    create_favorite(:favorite => users(:moderated_mentor))
    assert user.ready_to_request?
  end

  def test_prompt_to_request
    p = programs(:moderated_program)
    #The student is not part of a moderated group
    assert !users(:f_student).prompt_to_request?

    make_member_of(:moderated_program, :f_student)
    # The student dont have favorite nor requests
    assert !users(:f_student).reload.prompt_to_request?

    create_favorite
    # The min preferred mentors is 0
    assert users(:f_student).reload.prompt_to_request?

    p.update_attribute(:min_preferred_mentors, 2)
    # The min preferred mentors is 2
    assert !users(:f_student).reload.prompt_to_request?


    create_favorite(:favorite => users(:moderated_mentor))
    # The min preferred mentors is 2
    assert users(:f_student).reload.prompt_to_request?

    req = MentorRequest.new(:program => p, :student => users(:f_student), :message => "Hi")
    req.build_favorites([users(:f_mentor).id, users(:moderated_mentor).id])
    req.save!
    assert !users(:f_student).reload.prompt_to_request?

    MentorRequest.destroy_all
    assert users(:f_student).reload.prompt_to_request?

    create_group(:mentors => [users(:moderated_mentor)], :program => p)
    assert !users(:f_student).reload.prompt_to_request?

    Group.destroy_all
    assert users(:f_student).reload.prompt_to_request?
    p.update_attribute(:allow_mentoring_requests, false)
    assert !users(:f_student).reload.prompt_to_request?

    p.update_attribute(:allow_mentoring_requests, true)
    assert users(:f_student).reload.prompt_to_request?

    users(:f_student).roles[0].remove_permission("send_mentor_request")
    assert_false users(:f_student).reload.prompt_to_request?
  end

  # Should return true if the user is the admin of the program
  def test_admin_of_program
    user = users(:f_admin)
    assert user.admin_of?(programs(:albers))
    assert_false user.admin_of?(programs(:ceg))

    # Student becomes an admin
    student = users(:f_student)
    student.add_role(RoleConstants::ADMIN_NAME)
    assert student.admin_of?(programs(:albers))
  end

  def test_email_sent_for_deletion_of_user
    RecentActivity.destroy_all
    user = create_user(:role_names => [RoleConstants::ADMIN_NAME])
    assert_equal 1, RecentActivity.count
    assert_equal RecentActivityConstants::Type::ADMIN_CREATION, RecentActivity.last.action_type
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference 'RecentActivity.count' do
        assert_difference('User.count', -1) do
          user.demote_from_role!([RoleConstants::ADMIN_NAME], users(:f_admin))
        end
      end
    end
    assert_equal RecentActivityConstants::Type::USER_DEMOTION, RecentActivity.last.action_type
  end

  def test_user_deleted_when_no_role
    RecentActivity.destroy_all
    user = create_user(:role_names => [RoleConstants::MENTOR_NAME])
    assert_equal 1, RecentActivity.count
    activity = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTOR_JOIN_PROGRAM, activity.action_type
    assert_equal RecentActivityConstants::Target::ADMINS, activity.target
    Matching.expects(:remove_mentor_later).never
    Matching.expects(:perform_users_delta_index_and_refresh).never
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference 'RecentActivity.count' do
        assert_difference('User.count', -1) do
          user.demote_from_role!([RoleConstants::MENTOR_NAME], users(:f_admin))
        end
      end
    end
    assert_equal RecentActivityConstants::Type::USER_DEMOTION, RecentActivity.last.action_type
  end

  def test_demote_from_admin
    user = users(:f_admin)
    assert user.is_admin?
    assert_nil(user.max_connections_limit)

    assert_difference('RecentActivity.count', 1) do
      user.promote_to_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
      user.reload
      assert_equal(user.program.default_max_connections_limit, user.max_connections_limit)
    end

    Matching.expects(:remove_mentor_later).once
    # User is removed from admin
    assert_difference('RecentActivity.count', 1) do
      assert_difference('ActionMailer::Base.deliveries.size') do
        user.demote_from_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
      end
    end
    assert_false user.is_mentor?
    assert_equal users(:f_admin), user.state_changer

    assert_no_difference('ActionMailer::Base.deliveries.size') do
      user.demote_from_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
    end
  end

  def test_cleanup_explicit_user_preferences
    user = users(:f_mentor_student)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: user.program, role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], profile_question: prof_q)
    ExplicitUserPreference.create!(
      { user: user,
        role_question: prog_mentor_question,
        question_choices: [prof_q.question_choices.first]
      })
    assert user.explicit_user_preferences.present?
    user.demote_from_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    assert user.explicit_user_preferences.empty?
  end

  def test_get_active_or_recently_closed_groups
    user = users(:f_mentor)
    assert_equal [groups(:mygroup)], user.get_active_or_recently_closed_groups
    user = users(:mkr_student)
    assert_equal [groups(:mygroup)], user.get_active_or_recently_closed_groups
    groups(:mygroup).update_column(:status, Group::Status::CLOSED)
    user = users(:f_mentor)
    assert_equal [], user.get_active_or_recently_closed_groups
    user = users(:mkr_student)
    assert_equal [], user.get_active_or_recently_closed_groups
  end

  def test_demote_role_mentor_student
    user = users(:f_mentor)
    user.role_names += [RoleConstants::STUDENT_NAME]
    user.save!
    member = user.member

    ProfileQuestion.destroy_all
    pq1 = create_profile_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "This will me a mentor question", :organization => programs(:org_primary))
    pq2 = create_profile_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "This will me a mentee question", :organization => programs(:org_primary))
    pq3 = create_profile_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "This will me a mentor question in this program and student question in different different program", :organization => programs(:org_primary))

    create_role_question(:profile_question => pq1, :role_names => [RoleConstants::MENTOR_NAME])
    create_role_question(:profile_question => pq2, :role_names => [RoleConstants::STUDENT_NAME])
    create_role_question(:profile_question => pq3, :role_names => [RoleConstants::MENTOR_NAME])
    create_role_question(:profile_question => pq3, :role_names => [RoleConstants::STUDENT_NAME], :program => programs(:nwen))

    ProfileAnswer.create!(:profile_question => pq1, :answer_text => "I am a mentor", :ref_obj => member)
    pa2 = ProfileAnswer.create!(:profile_question => pq2, :answer_text => "I am a mentee", :ref_obj => member)
    pa3 = ProfileAnswer.create!(:profile_question => pq3, :answer_text => "I am a mentor in albers and mentee in nwen", :ref_obj => member)

    Group.destroy_all
    g0 = create_group(:program => programs(:albers),
     :mentors => [user],
     :students => [users(:f_student)],
     :status => Group::Status::ACTIVE,
     :creator_id => users(:f_admin).id)
    g1 = create_group(:program => programs(:albers),
     :mentors => [user],
     :students => [users(:student_1)],
     :status => Group::Status::DRAFTED,
     :creator_id => users(:f_admin).id)
    g2 = create_group(:program => programs(:albers),
     :mentors => [users(:f_mentor_student)],
     :students => [user],
     :status => Group::Status::DRAFTED,
     :creator_id => users(:f_admin).id)

    Forum.destroy_all
    forum1 = create_forum(:access_role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], :name => "For both mentors and students" )
    forum2 = create_forum(:access_role_names => [RoleConstants::MENTOR_NAME])
    Subscription.create!(ref_obj: forum1, user: users(:f_admin))
    Subscription.create!(ref_obj: forum2, user: users(:f_admin))

    topic1 = create_topic(:title => "student topic", :forum => forum1, :user => users(:f_admin))
    topic2 = create_topic(:title => "mentor topic", :forum => forum2, :user => users(:f_admin))

    assert_difference 'Subscription.count', 4 do
      Subscription.create!(ref_obj: forum2, user: user)
      @student_forum_subscription = Subscription.create!(ref_obj: forum1, user: user)
      Subscription.create!(ref_obj: topic2, user: user)
      @student_topic_subscription = Subscription.create!(ref_obj: topic1, user: user)
    end

    ProgramEvent.destroy_all
    admin_view = programs(:albers).admin_views.where(:default_view => AbstractView::DefaultType::ALL_USERS).first
    assert_difference 'ProgramEvent.count', 1 do
      @mentor_event = programs(:albers).program_events.new(:title => "Mentor Event", :location => "chennai, tamilnadu, india", :start_time => 30.days.from_now, :status => ProgramEvent::Status::PUBLISHED, :program => programs(:albers), :user => users(:ram), :time_zone => "Asia/Kolkata")
      @mentor_event.admin_view = admin_view
      @mentor_event.email_notification = false
      @mentor_event.save!
    end
    assert_difference 'ProgramEvent.count', 1 do
      @event_for_both_roles = programs(:albers).program_events.new(:title => "Both Event", :location => "chennai, tamilnadu, india", :start_time => 30.days.from_now, :status => ProgramEvent::Status::PUBLISHED, :program => programs(:albers), :user => users(:ram), :time_zone => "Asia/Kolkata")
      @event_for_both_roles.admin_view = admin_view
      @event_for_both_roles.email_notification = false
      @event_for_both_roles.save!
    end
    RecentActivity.destroy_all
    assert_difference "EventInvite.count", 2 do
      assert_difference "RecentActivity.count", 2 do
        @mentor_event.event_invites.create!(user: user, status: EventInvite::Status::YES)
        @ror_mentor_invite = @event_for_both_roles.event_invites.create!(user: user, status: EventInvite::Status::NO)
      end
    end

    FavoritePreference.create!({preference_marker_user: user, preference_marked_user: users(:mentor_1)})
    IgnorePreference.create!({preference_marker_user: user, preference_marked_user: users(:mentor_1)})
    assert_equal 1, user.mentee_marked_favorite_preferences.size
    assert_equal 1, user.mentee_marked_ignore_preferences.size
    assert_equal 1, user.favorite_preferences.size
    assert_equal 1, user.ignore_preferences.size

    recent_activities1 = RecentActivity.all
    assert_false recent_activities1.collect(&:action_type).include?(RecentActivityConstants::Type::USER_DEMOTION)
    assert recent_activities1.collect(&:action_type).include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT)
    assert recent_activities1.collect(&:action_type).include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT)
    Matching.expects(:remove_mentor_later).once

    assert_no_difference 'EventInvite.count' do
      assert_difference 'ProfileAnswer.count', -1 do
        assert_difference 'Group.count', -1 do
          assert_difference 'Subscription.count', -2 do
            assert_difference('RecentActivity.count', 1) do
              assert_difference('ActionMailer::Base.deliveries.size') do
                assert_difference('FavoritePreference.count', -1) do
                  assert_difference('IgnorePreference.count', -1) do
                    user.demote_from_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
                  end
                end
              end
            end
          end
        end
      end
    end

    assert g0.reload.present?
    assert g2.reload.present?
    assert @student_forum_subscription.reload.present?
    assert @student_topic_subscription.reload.present?
    assert pa2.reload.present?
    assert pa3.reload.present?
    recent_activities2 = RecentActivity.all
    assert recent_activities2.collect(&:action_type).include?(RecentActivityConstants::Type::USER_DEMOTION)
    assert recent_activities2.collect(&:action_type).include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT)
    assert recent_activities2.collect(&:action_type).include?(RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT)
    user.reload
    assert_equal 0, user.mentee_marked_favorite_preferences.size
    assert_equal 0, user.mentee_marked_ignore_preferences.size
    assert_equal 1, user.favorite_preferences.size
    assert_equal 1, user.ignore_preferences.size
  end

  def test_remove_preferences
    user = users(:f_mentor)
    user.role_names += [RoleConstants::STUDENT_NAME]

    FavoritePreference.create!({preference_marker_user: user, preference_marked_user: users(:mentor_1)})
    IgnorePreference.create!({preference_marker_user: user, preference_marked_user: users(:mentor_1)})
    assert_equal 1, user.mentee_marked_favorite_preferences.size
    assert_equal 1, user.mentee_marked_ignore_preferences.size
    assert_equal 1, user.favorite_preferences.size
    assert_equal 1, user.ignore_preferences.size

    assert_difference('FavoritePreference.count', -1) do
      assert_difference('IgnorePreference.count', -1) do
        user.remove_preferences([RoleConstants::STUDENT_NAME])
      end
    end
    user.reload
    assert_equal 1, user.mentee_marked_favorite_preferences.size
    assert_equal 1, user.mentee_marked_ignore_preferences.size
    assert_equal 0, user.favorite_preferences.size
    assert_equal 0, user.ignore_preferences.size

    assert_difference('FavoritePreference.count', -1) do
      assert_difference('IgnorePreference.count', -1) do
        user.remove_preferences([RoleConstants::MENTOR_NAME])
      end
    end
    user.reload
    assert_equal 0, user.mentee_marked_favorite_preferences.size
    assert_equal 0, user.mentee_marked_ignore_preferences.size
    assert_equal 0, user.favorite_preferences.size
    assert_equal 0, user.ignore_preferences.size
  end

  def test_promote_to_role_for_pending_users
    user = users(:f_mentor)
    user.update_attribute(:state, User::Status::PENDING)
    assert user.profile_pending?
    assert_false user.is_student?

    user.promote_to_role!([RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], users(:f_admin))
    assert user.profile_pending?
    assert user.is_student?
  end

  def test_promote_to_role_for_suspended_users
    user = users(:f_mentor)
    suspend_user(user)
    assert user.suspended?
    assert_false user.is_student?

    user.promote_to_role!([RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], users(:f_admin))
    assert user.is_student?
    assert user.active?
  end

  def test_promote_to_role_without_email
    user = users(:f_student)
    assert_false user.is_admin?
    assert_difference('RecentActivity.count') do
      assert_difference('ActionMailer::Base.deliveries.size') do
        user.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin), :no_email => true)
      end
    end
  end

  def test_promote_to_role
    user = users(:f_student)
    assert_false user.is_admin?
    assert_difference('RecentActivity.count') do
      assert_difference('ActionMailer::Base.deliveries.size') do
        user.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
      end
    end

    assert user.is_admin?
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      user.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    end
    assert_equal users(:f_admin), user.state_changer
    assert_nil RecentActivity.last.message
    assert_equal RecentActivityConstants::Target::ADMINS, RecentActivity.last.target

    user = users(:f_mentor)
    assert !user.is_student?
    user.promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin), "Test Reason")
    assert user.reload.is_student?
    assert_equal "Test Reason", RecentActivity.last.message
    assert_equal RecentActivityConstants::Target::ADMINS, RecentActivity.last.target
  end

  # admin adds additional roles to himself
  def test_promote_to_role_for_self_promotion
    user = users(:f_admin)
    assert user.is_admin?
    assert_false user.is_mentor?
    assert_difference('RecentActivity.count') do
      assert_no_difference('ActionMailer::Base.deliveries.size') do
        user.promote_to_role!(RoleConstants::MENTOR_NAME, user)
      end
    end

    assert user.is_mentor?
    assert_equal user, user.state_changer
  end

  def test_promote_to_role_should_delete_not_applicable_answers
    user = users(:f_admin)
    User.expects(:delay).returns(Delayed::Job)
    Delayed::Job.expects(:delete_not_applicable_answers).with([user.member_id], [RoleConstants::MENTOR_NAME])
    user.promote_to_role!(RoleConstants::MENTOR_NAME, user)
  end

  def test_promote_to_roles_should_delete_not_applicable_answers
    user = users(:f_admin)
    User.expects(:delay).at_least(0).returns(Delayed::Job)
    Delayed::Job.expects(:delete_not_applicable_answers).with([user.member_id], [RoleConstants::MENTOR_NAME])
    Delayed::Job.expects(:bulk_create_ra_and_mail_for_promoting_to_role)
    Delayed::Job.expects(:track_state_changes_for_bulk_role_addition)
    Delayed::Job.expects(:process_users_reactivation).never
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [user.id]).times(0)
    DelayedEsDocument.expects(:delayed_update_es_document).with(User, user.id).times(0)
    assert_equal true, User.promote_to_roles(user.program, [user.id], [RoleConstants::MENTOR_NAME], user, "")
  end

  def test_get_accessible_admin_view_ids
    program = programs(:albers)
    all_users_view_id = program.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS).id
    all_mentors_view_id = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTORS).id

    user = users(:f_mentor)
    assert_equal [all_users_view_id, all_mentors_view_id], user.get_accessible_admin_view_ids
    assert_equal [all_mentors_view_id], user.get_accessible_admin_view_ids(admin_view_ids: [all_mentors_view_id])

    user = users(:f_student)
    assert_equal [all_users_view_id], user.get_accessible_admin_view_ids
    assert_equal [all_users_view_id], user.get_accessible_admin_view_ids(admin_view_ids: [all_users_view_id])
    assert_empty user.get_accessible_admin_view_ids(admin_view_ids: [all_mentors_view_id])
  end

  def test_promote_to_roles
    program = programs(:albers)
    user = users(:f_mentor)
    user_2 = users(:mentor_1)
    user_3 = users(:mentor_2)
    suspend_user(user)
    suspend_user(user_2)
    user_2.member.update_attribute(:state, Member::Status::SUSPENDED)
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [user.id]).times(3)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [user_3.id]).times(1)
    assert_difference "UserStateChange.count", 2 do
      assert_difference "ConnectionMembershipStateChange.count", (user.connection_memberships.size + user_3.connection_memberships.size) do
        assert_equal true, User.promote_to_roles(program, [user.id, user_2.id, user_3.id], [RoleConstants::STUDENT_NAME], users(:f_admin), "")
      end
    end

    state_change = { "from" => User::Status::SUSPENDED, "to" => User::Status::ACTIVE }
    user_state_change = user.reload.state_transitions.last.info_hash
    assert user.active?
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], user.role_names
    assert_equal state_change, user_state_change["state"]
    assert_equal_unordered [mentor_role.id], user_state_change["role"]["from"]
    assert_equal_unordered [student_role.id, mentor_role.id], user_state_change["role"]["to"]

    assert user_2.reload.suspended? # Globally suspended users are ignored
    assert_equal [RoleConstants::MENTOR_NAME], user_2.role_names

    state_change = { "from" => User::Status::ACTIVE, "to" => User::Status::ACTIVE }
    user_state_change = user_3.reload.state_transitions.last.info_hash
    assert user_3.active?
    assert_equal state_change, user_state_change["state"]
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], user.role_names
    assert_equal_unordered [mentor_role.id], user_state_change["role"]["from"]
    assert_equal_unordered [student_role.id, mentor_role.id], user_state_change["role"]["to"]
  end

  def test_promote_to_roles_admin
    user = users(:mentor_1)
    program = user.program
    program.stubs(:standalone?).returns(true)
    User.stubs(:delay).returns(User)
    assert_equal true, User.promote_to_roles(program, [user.id], [RoleConstants::ADMIN_NAME], user, "")
  end

  def test_delete_not_applicable_answers
    member = members(:f_student)
    gender_question = programs(:org_primary).profile_questions_with_email_and_name.find_by(question_text: "Gender")
    mentor_gender_question = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question == gender_question}[0]
    mentor_gender_question.update_attributes(:required => true)

    assert gender_question.required_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert_false gender_question.required_for(programs(:albers), RoleConstants::STUDENT_NAME)

    answer = ProfileAnswer.create!(:profile_question => gender_question, :ref_obj => member, :not_applicable => true)
    assert answer.not_applicable
    assert_equal [answer], member.profile_answers

    User.delete_not_applicable_answers(member.id, [RoleConstants::MENTOR_NAME])
    assert_blank member.reload.profile_answers
  end

  def test_role_promotion_demotion_does_delta_indexing
    user = users(:f_mentor)

    assert_false user.is_student?
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [user.id]).times(2)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [user.member.id])
    user.promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    assert user.is_student?

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [user.id])
    user.demote_from_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    assert_false user.is_student?
  end

  def test_should_create_mentor_student_user
    assert_difference 'User.count' do
      @user = create_user(
        :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    end

    assert @user.is_mentor_and_student?
  end

  def test_admin_only_admin_and_other
    assert users(:f_admin).is_admin_only?
    assert !users(:f_admin).admin_and_other?

    users(:f_admin).add_role(RoleConstants::MENTOR_NAME)
    assert !users(:f_admin).is_admin_only?
    assert users(:f_admin).admin_and_other?

    users(:f_admin).remove_role(RoleConstants::MENTOR_NAME)
    assert users(:f_admin).is_admin_only?
    assert !users(:f_admin).admin_and_other?
  end

  def test_recent_activity_creation_admin_role_update_to_mentor
    assert_difference "RecentActivity.count" do
      users(:f_admin).promote_to_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
    end

    recent_activity = RecentActivity.last
    assert_equal RecentActivityConstants::Type::USER_PROMOTION, recent_activity.action_type
    assert_equal users(:f_admin), recent_activity.ref_obj
    assert_equal RecentActivityConstants::Target::ADMINS, recent_activity.target
  end

  def test_recent_activity_creation_admin_role_update_to_mentor_student
    assert_difference "RecentActivity.count" do
      users(:f_admin).promote_to_role!(
        [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], users(:f_admin))
    end

    recent_activity = RecentActivity.last
    assert_equal RecentActivityConstants::Type::USER_PROMOTION, recent_activity.action_type
    assert_equal users(:f_admin), recent_activity.ref_obj
    assert_equal RecentActivityConstants::Target::ADMINS, recent_activity.target
  end

  def test_recent_activity_creation_admin_name_update
    assert_no_difference "RecentActivity.count" do
      members(:f_admin).update_attribute(:first_name, "New Stud")
    end
  end

  def test_name
    setup_admin_custom_term
    assert_equal "Freakin Admin (Super Admin)", users(:f_admin).name
    assert_equal "Freakin Admin", users(:f_admin).name(name_only: true)
    assert_equal "Good unique name", users(:f_mentor).name
  end

  def test_email
    assert_nil users(:f_admin).attributes["email"]
    assert_equal users(:f_admin).member.email, users(:f_admin).email
  end

  def test_location_name
    assert_nil users(:f_mentor).attributes["location_name"]
    assert_equal users(:f_mentor).location.full_address, users(:f_mentor).location_name
  end

  def test_display_name
    admin = users(:f_admin)
    mentor = users(:f_mentor)
    assert_equal 'You', admin.display_name(admin)
    assert_equal admin.name, admin.display_name
    assert_equal mentor.name, mentor.display_name(admin)
  end

  def test_find_by_email_program
    assert_equal users(:f_admin), User.find_by_email_program(users(:f_admin).email, programs(:albers))
    assert_not_equal users(:f_admin), User.find_by_email_program(users(:f_admin).email, programs(:ceg))
    assert_nil User.find_by_email_program("", programs(:albers))
  end

  def test_search_by_name_with_email_or_name
    program = programs(:albers)

    assert_equal [users(:f_admin)], User.search_by_name_with_email(program, "Freakin Admin <ram@example.com>").to_a
    assert_equal [users(:f_admin)], User.search_by_name_with_email(program, "<ram@example.com>").to_a
    assert_equal [], User.search_by_name_with_email(program, "ram@example.com").to_a
    assert_equal [users(:f_admin)], User.search_by_name_with_email(program, "Freakin Admin").to_a
    assert_equal [users(:f_admin)], User.search_by_name_with_email(program, "+Freakin Admin").to_a
    assert_equal [users(:f_admin)], User.search_by_name_with_email(program, "+Freakin").to_a
    assert_equal [], User.search_by_name_with_email(program, "<ram@example.com>", false).to_a
  end

  def test_validation_uniqueness_of_programid
    me = create_member

    assert_difference 'User.count', 1 do
      @u = User.new
      @u.program = programs(:albers)
      @u.member = me
      @u.role_names = [RoleConstants::STUDENT_NAME]
      @u.save!
    end

    assert_no_difference 'User.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :program, "has this user already" do
        u = User.new
        u.program = programs(:albers)
        u.member = @u.member
        u.role_names = [RoleConstants::STUDENT_NAME]
        u.save!
      end
    end
  end

  def test_validate_presense_of_roles
    me = create_member

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :roles, "can't be blank" do
      @u = User.new
      @u.program = programs(:albers)
      @u.member = me
      @u.role_names = []
      @u.save!
    end

    assert_difference 'User.count', 1 do
      @u = User.new
      @u.program = programs(:albers)
      @u.member = me
      @u.role_names = [RoleConstants::STUDENT_NAME]
      @u.save!
    end
  end

  def test_name_with_email
    assert_equal users(:f_mentor).name(:name_only => true) + " <#{users(:f_mentor).email}>",
      users(:f_mentor).name_with_email

    assert_equal users(:ram).name(:name_only => true) + " <#{users(:ram).email}>",
      users(:ram).name_with_email
  end

  def test_belongs_to_group
    student = create_user(:role_names => [RoleConstants::STUDENT_NAME], :name => 'tstud')
    mentor = create_user(:role_names => [RoleConstants::MENTOR_NAME], :name => 'tmentor')

    g1 = create_group(:student => student)
    assert(student.belongs_to_group?(g1))
    assert(!mentor.belongs_to_group?(g1))

    g2 = create_group(:mentors => [mentor])
    assert(mentor.belongs_to_group?(g2))
    assert(!student.belongs_to_group?(g2))
  end

  def test_user_state_machine
    user = create_user
    user.state_changer = users(:f_admin)
    user.state_change_reason = "State changed"
    assert user.active?

    user.delete!
    assert user.deleted?

    user.activate!
    assert user.active?

    suspend_user(user)
    assert user.suspended?

    user.activate!
    assert user.active?
  end

  def test_user_active_scope
    program = programs(:albers)
    user = users(:f_mentor)
    assert program.users.active.include?(user)

    suspend_user(user)
    assert_false program.users.active.include?(user)
  end

  def test_last_answers_update_time
    ProfileAnswer.destroy_all
    u = users(:f_mentor)
    member = u.member

    assert_equal(0, u.profile_answers.size)
    assert_equal(0, u.answers_last_updated_at)

    # Only one question
    q = create_mentor_question(:organization => programs(:org_primary))
    t = 1.days.ago

    ProfileAnswer.skip_timestamping do
      assert_difference 'ProfileAnswer.count' do
        member.profile_answers.create!(:profile_question => q.profile_question, :created_at => t, :answer_text => "abc", :updated_at => t)
      end
    end

    u.profile_answers.reload
    assert_equal(t.to_i, u.answers_last_updated_at)

    # More than 1 question
    q = create_mentor_question(:organization => programs(:org_primary))
    t1 = 1.hour.ago
    ProfileAnswer.skip_timestamping do
      member.profile_answers.create!(:profile_question => q.profile_question, :created_at => t1, :answer_text => "abc", :updated_at => t1)
    end

    u.profile_answers.reload
    assert_equal(t1.to_i, u.answers_last_updated_at)
  end

  def test_import_members_from_subprograms
    assert_false programs(:albers).allow_track_admins_to_access_all_users
    assert_false users(:f_admin).import_members_from_subprograms?

    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)
    users(:f_admin).program.reload
    assert users(:f_admin).import_members_from_subprograms?

    assert_false users(:f_mentor).is_admin?
    assert_false users(:f_mentor).import_members_from_subprograms?
  end

  def test_has_many_answers
    member = members(:mentor_5)
    u = users(:mentor_5)
    prog_q = create_question(:organization => member.organization)

    a1 = member.profile_answers.create!(:ref_obj => member, :profile_question => profile_questions(:string_q), :answer_text => "Def")
    a2 = ProfileAnswer.create!(:ref_obj => member, :profile_question => prog_q, :answer_text => "abc")
    a3 = member.profile_answers.create!(:ref_obj => member, :profile_question => profile_questions(:single_choice_q), :answer_value => "opt_1")

    assert_equal_unordered [a1, a2, a3], u.profile_answers
  end

  def test_profile_score_for_student_default
    programs(:org_primary).profile_questions_with_email_and_name.destroy_all
    u = create_user(:role_names => [RoleConstants::STUDENT_NAME])
    assert_equal ProfileCompletion::Score::DEFAULT, u.profile_score.default

    # No custom questions
    assert_equal 0, u.program.role_questions_for([RoleConstants::STUDENT_NAME]).count
    assert_equal 0, u.profile_score.profile

    # No Image
    assert_nil u.member.profile_picture
    assert_equal 0, u.profile_score.image
  end

  def test_profile_score_for_student_default_with_question_unanswered
    programs(:org_primary).profile_questions.destroy_all
    u = create_user(:role_names => [RoleConstants::STUDENT_NAME])
    create_question(:role_names => [RoleConstants::STUDENT_NAME])
    # Email and name are the other questions
    assert_equal 3, u.program.profile_questions_for([RoleConstants::STUDENT_NAME]).count
    assert_equal 0, u.profile_score.profile
    assert_equal ProfileCompletion::Score::DEFAULT, u.profile_score.sum
  end

  def test_profile_score_for_student_with_image
    u = create_user(:role_names => [RoleConstants::STUDENT_NAME])
    mu = u.member
    mu.profile_picture = ProfilePicture.new(:image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    mu.save!
    assert_equal 5, u.profile_score.image
    assert_equal 5, u.profile_score.profile_image_ratio
  end

  def test_profile_score_for_student_default_with_one_question_unanswered_other_answered
    programs(:org_primary).profile_questions.destroy_all
    u = create_user(:role_names => [RoleConstants::STUDENT_NAME])
    q = create_question
    q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"])
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q, :answer_value => "")
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q1, :answer_value => "Def")
    # Image is unanswered
    assert_equal((ProfileCompletion::Score::PROFILE/3.0).round, u.reload.profile_score.profile)
  end

  def test_has_many_articles
    assert_equal [articles(:kangaroo), articles(:draft_article)], users(:f_mentor).articles
    assert_equal [], users(:f_mentor_ceg).articles

    ceg_article = create_article(
      :author => members(:f_mentor_ceg),
      :organization => programs(:org_anna_univ),
      :published_programs => [programs(:ceg)])

    assert_equal [articles(:kangaroo), articles(:draft_article)], users(:f_mentor).reload.articles
    assert_equal [ceg_article], users(:f_mentor_ceg).reload.articles
  end

  def test_profile_score_set_custom_profile_score_with_unaswered_image
    programs(:org_primary).profile_questions.destroy_all
    u = create_user(:role_names => [RoleConstants::STUDENT_NAME])
    p = User::ProfileScore.new(u)
    assert_equal 0 ,p.profile
    # Creating question
    q = create_question(:role_names => [RoleConstants::STUDENT_NAME])
    u.reload
    p.set_custom_profile_score(u)
    assert_equal 0, p.profile

    q1 = create_question(:role_names => [RoleConstants::STUDENT_NAME], :question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"])
    a = ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q, :answer_value => "")
    a1 = ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q1, :answer_value => "Def")
    u.reload
    p.set_custom_profile_score(u)
    assert_equal((ProfileCompletion::Score::PROFILE/3.0).round, p.profile)

    #with dependent questions
    create_question(:role_names => [RoleConstants::STUDENT_NAME], :conditional_question_id => q1.id, :conditional_match_text => "Abc")
    u.reload
    p.set_custom_profile_score(u)
    assert_equal((ProfileCompletion::Score::PROFILE/3.0).round, p.profile)
    a1.update_attributes!(:answer_value => "Abc")
    u.reload
    p.set_custom_profile_score(u)
    assert_equal(((ProfileCompletion::Score::PROFILE)/4.0).round, p.profile)
  end

  def test_articles_marked_helpful
    member = members(:f_admin)

    # Mark the first article helpful
    art = create_article
    art.mark_as_helpful!(member)
    assert art.rated_by_user?(member)

    # Mark another
    art2 = create_article
    assert_false art2.rated_by_user?(member)
    art2.mark_as_helpful!(member)
    assert art2.rated_by_user?(member)

    art.unmark_as_helpful!(member)
    assert_false art.reload.rated_by_user?(member)
  end

  def test_mentor_user_should_have_max_connections_limit
    p = programs(:albers)
    p.default_max_connections_limit = 10
    p.save!

    assert_equal(10, p.reload.default_max_connections_limit)
    u = create_user(:role_names => [RoleConstants::MENTOR_NAME])
    assert_equal(10, u.max_connections_limit)
  end

  def test_student_or_admin_should_not_have_max_connections_limit
    student = create_user(:role_names => [RoleConstants::STUDENT_NAME], :name => "stud")
    assert_nil(student.max_connections_limit)

    admin = create_user(:role_names => [RoleConstants::ADMIN_NAME], :name => 'admin')
    assert_nil(admin.max_connections_limit)
  end

  def test_has_many_roles
    user = create_user
    user.program.roles.destroy_all
    assert user.roles.reload.empty?
    role_1 = create_role(name: 'manager')
    role_2 = create_role(name: 'general_manager')
    assert_difference 'user.roles.reload.count', 2 do
      user.roles << role_1
      user.roles << role_2
    end
    assert_equal [role_1, role_2], user.roles
  end

  def test_is_role
    user = create_user
    user.roles.destroy_all
    role_1 = create_role(:name => 'manager')
    role_2 = create_role(:name => 'general_manager')
    role_3 = create_role(:name => 'assistant')
    assert !user.is_manager?
    assert !user.is_general_manager?
    assert !user.is_manager_or_general_manager?
    assert !user.is_manager_and_general_manager?
    user.roles << role_1
    assert user.is_manager?
    assert user.is_manager_only?
    assert !user.is_general_manager_only?
    assert !user.is_general_manager?
    assert user.is_manager_or_general_manager?
    assert !user.is_manager_and_general_manager?
    user.roles << role_2
    assert user.is_manager?
    assert !user.is_manager_only?
    assert !user.is_general_manager_only?
    assert user.is_general_manager?
    assert user.is_manager_or_general_manager?
    assert user.is_manager_and_general_manager?
    assert !user.is_manager_and_general_manager_and_assistant?
    assert user.is_manager_or_general_manager_or_assistant?
    user.roles << role_3
    assert user.is_manager_and_general_manager_and_assistant?
  end

  def test_has_role
    user = users(:f_student)
    assert !user.has_role?('mentor')
    user.add_role('mentor')
    assert user.has_role?('mentor')
  end

  def test_add_role
    user = users(:f_student)
    assert !user.is_mentor?
    user.add_role('mentor')
    assert user.is_mentor?

    assert_raise AuthorizationManager::NoSuchRoleForProgramException do
      user.add_role('engineer')
    end
  end

  def test_remove_role
    user = create_user
    create_role(:name => 'manager')
    create_role(:name => 'general_manager')
    user.program.roles.reload
    assert !user.is_manager?
    user.add_role('manager')
    assert user.is_manager?
    user.remove_role('manager')
    assert !user.is_manager?

    assert_raise AuthorizationManager::RoleNotFoundForUserException do
      user.remove_role('general_manager')
    end
  end

  def test_permission_checks
    user = create_user
    role_1 = create_role(:name => 'manager')
    role_2 = create_role(:name => 'investigator')
    p_1 = create_permission("eat_chocolate")
    p_2 = create_permission("climb_mountain")
    p_3 = create_permission("watch_tv")
    role_1.permissions << p_2
    role_2.permissions << p_3
    Permission.all_permissions = nil

    # No permissions.
    assert !user.reload.can_eat_chocolate?
    assert !user.can_climb_mountain?
    assert !user.can_watch_tv?

    # manager role gives p_2 permission
    user.add_role('manager')
    assert !user.reload.can_eat_chocolate?
    assert user.can_climb_mountain?
    assert !user.can_watch_tv?

    # investigator role gives p_3 permission
    user.add_role('investigator')
    assert !user.reload.can_eat_chocolate?
    assert user.can_climb_mountain?
    assert user.can_watch_tv?

    # role_1 now gets additional permission of p_1, hence the user
    role_1.permissions << p_1
    assert user.reload.can_eat_chocolate?
    assert user.can_climb_mountain?
    assert user.can_watch_tv?

    assert_raise AuthorizationManager::NoSuchPermissionException do
      user.can_open_door?
    end
  end

  def test_view_management_console
    manage_role = create_role(:name => 'manage')
    manager = create_user(:name => 'manager', :role_names => ['manage'])
    assert !manager.view_management_console?
    add_role_permission(manage_role, 'approve_membership_request')
    assert !manager.view_management_console?
    add_role_permission(manage_role, 'manage_mentor_requests')
    assert !manager.view_management_console?

    random_perm = RoleConstants::MANAGEMENT_PERMISSIONS.sample
    add_role_permission(manage_role, random_perm)
    assert manager.view_management_console?

    (RoleConstants::MANAGEMENT_PERMISSIONS - [random_perm]).each do |perm|
      add_role_permission(manage_role, perm)
    end
    assert manager.view_management_console?
  end

  def test_state_transition_allowed_in_api
    user = users(:f_mentor)
    assert user.state_transition_allowed_in_api?(User::Status::PENDING)
    assert user.state_transition_allowed_in_api?(User::Status::SUSPENDED)

    user.stubs(:can_be_removed_or_suspended?).returns(false)
    assert user.state_transition_allowed_in_api?(User::Status::PENDING)
    assert_false user.state_transition_allowed_in_api?(User::Status::SUSPENDED)
  end

  def test_suspend_from_program
    user = users(:f_mentor)
    assert user.active?
    assert_nil user.last_deactivated_at
    n_connected_users = user.mentors.size + user.students.size
    current_time = Time.now

    number_of_emails = get_pending_requests_and_offers_count(user) + 1
    Matching.expects(:perform_users_delta_index_and_refresh).with([user.id], user.program_id, {}).once
    Timecop.freeze(current_time) do
      assert_difference "RecentActivity.count", 1 do
        assert_difference "PendingNotification.count", n_connected_users do
          assert_emails number_of_emails do
            assert_difference "JobLog.count", n_connected_users + 1 do
              user.suspend_from_program!(users(:f_admin), "Suspension reason")
            end
          end
        end
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert user.suspended?
    assert_equal User::Status::ACTIVE, user.track_reactivation_state
    assert_nil user.global_reactivation_state
    assert_equal users(:f_admin), user.state_changer
    assert_equal "Suspension reason", user.state_change_reason
    assert current_time, user.last_deactivated_at
    assert_equal [user.email], email.to
    assert_equal "Your membership has been deactivated", email.subject
  end

  def test_suspend_from_program_with_options
    user = users(:f_mentor)
    assert user.active?
    member = user.member.update_attribute(:state, Member::Status::SUSPENDED)
    n_connected_users = user.students.size + user.mentors.size
    number_of_emails = get_pending_requests_and_offers_count(user)

    options = { send_email: false, global_suspension: true }
    assert_difference "RecentActivity.count", 1 do
      assert_no_difference "PendingNotification.count" do
        assert_no_difference "JobLog.count" do
          assert_emails number_of_emails do
            user.suspend_from_program!(users(:f_admin), "Suspension reason", options)
          end
        end
      end
    end
    assert user.suspended?
    assert_nil user.track_reactivation_state
    assert_equal User::Status::ACTIVE, user.global_reactivation_state
    assert_equal users(:f_admin), user.state_changer
    assert_equal "Suspension reason", user.state_change_reason
  end

  def test_suspend_from_program_suspended_profiles
    suspend_user(users(:f_mentor))
    suspended_user = users(:inactive_user)
    suspended_user_2 = users(:f_mentor)
    assert suspended_user.suspended?

    assert_no_difference "RecentActivity.count" do
      assert_no_difference "PendingNotification.count" do
        assert_no_difference "JobLog.count" do
          assert_no_emails do
            suspended_user.suspend_from_program!(users(:psg_admin), "Suspension reason")
            suspended_user_2.suspend_from_program!(users(:f_admin), "Suspension reason", global_suspension: true)
          end
        end
      end
    end
    assert suspended_user.suspended?
    assert suspended_user_2.suspended?
    assert_nil suspended_user.state_changer || suspended_user_2.state_changer
    assert_nil suspended_user.track_reactivation_state
    assert_equal User::Status::ACTIVE, suspended_user_2.track_reactivation_state
    assert_equal User::Status::ACTIVE, suspended_user.global_reactivation_state
    assert_equal User::Status::SUSPENDED, suspended_user_2.global_reactivation_state
  end

  def test_reactivate_in_program_active_before_suspension
    user = users(:f_mentor)
    suspend_user(user)

    Matching.expects(:perform_users_delta_index_and_refresh).with([user.id], user.program_id, {}).once
    user.stubs(:profile_incomplete_roles).returns([RoleConstants::MENTOR_NAME])
    assert_difference "RecentActivity.count", 1 do
      assert_emails 1 do
        user.reactivate_in_program!(users(:f_admin))
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert user.active?
    assert_equal users(:f_admin), user.state_changer
    assert_not_nil user.activated_at
    assert_nil user.track_reactivation_state
    assert_nil user.global_reactivation_state
    assert_equal [user.email], email.to
    assert_equal "Your account is now reactivated!", email.subject
  end

  def test_reactivate_in_program_pending_before_suspension
    user_1 = users(:foster_mentor1)
    user_2 = users(:foster_mentor2)
    suspend_user(user_1, track: User::Status::PENDING)
    suspend_user(user_2, track: User::Status::PENDING)

    Matching.expects(:perform_users_delta_index_and_refresh).with([user_1.id], user_1.program_id, {}).once
    Matching.expects(:perform_users_delta_index_and_refresh).with([user_2.id], user_2.program_id, {}).once
    user_1.stubs(:can_be_published?).returns(false)
    user_2.stubs(:can_be_published?).returns(true)
    assert_difference "RecentActivity.count", 2 do
      assert_emails 2 do
        user_1.reactivate_in_program!(users(:foster_admin))
        user_2.reactivate_in_program!(users(:foster_admin))
      end
    end
    emails = ActionMailer::Base.deliveries.last(2)
    assert user_1.pending?
    assert user_2.active?
    assert_equal users(:foster_admin), user_1.state_changer
    assert_equal users(:foster_admin), user_2.state_changer
    assert_not_nil user_1.activated_at && user_2.activated_at
    assert_nil user_1.track_reactivation_state || user_2.track_reactivation_state
    assert_nil user_1.global_reactivation_state || user_2.global_reactivation_state
    assert_equal_unordered [user_1.email, user_2.email], emails.collect(&:to).flatten
    assert_equal "Your account is now reactivated!", emails.collect(&:subject).uniq[0]
  end

  def test_can_be_published
    user = users(:f_student)
    assert user.groups.empty?
    assert user.can_be_published?
    user.stubs(:profile_incomplete_roles).returns(['something'])
    assert_false user.can_be_published?
    user.stubs(:groups).returns([groups(:mygroup)])
    assert user.can_be_published?
    Group.any_instance.stubs(:status).returns('some status')
    assert_false user.can_be_published?
  end

  def test_reactivate_in_program_send_email_set_false
    user = users(:f_mentor)
    suspend_user(user)

    assert_difference "RecentActivity.count", 1 do
      assert_no_emails do
        user.reactivate_in_program!(users(:f_admin), send_email: false)
      end
    end
    assert user.active?
    assert_equal users(:f_admin), user.state_changer
    assert_not_nil user.activated_at
    assert_nil user.track_reactivation_state
  end

  def test_reactivate_in_program_global_and_track_reactivation
    user = users(:f_mentor)
    suspend_user(user, track: User::Status::ACTIVE, global: User::Status::SUSPENDED)

    assert_no_difference "RecentActivity.count" do
      assert_no_emails do
        user.reactivate_in_program!(users(:f_admin), global_reactivation: true)
      end
    end
    assert user.suspended?
    assert_nil user.state_changer
    assert_nil user.activated_at
    assert_equal User::Status::ACTIVE, user.track_reactivation_state
    assert_nil user.global_reactivation_state

    assert_difference "RecentActivity.count", 1 do
      assert_emails 1 do
        user.reactivate_in_program!(users(:f_admin))
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert user.active?
    assert_not_nil user.state_changer
    assert_not_nil user.activated_at
    assert_nil user.track_reactivation_state
    assert_nil user.global_reactivation_state
    assert_equal [user.email], email.to
    assert_equal "Your account is now reactivated!", email.subject
  end

  def test_reactivate_in_program_non_suspended_profiles
    active_user = users(:f_mentor)
    pending_user = users(:foster_mentor1)
    assert active_user.active?
    assert pending_user.pending?

    assert_no_difference "RecentActivity.count" do
      assert_no_emails do
        active_user.reactivate_in_program!(users(:f_admin))
        pending_user.reactivate_in_program!(users(:foster_admin))
      end
    end
    assert active_user.active?
    assert pending_user.pending?
    assert_nil active_user.state_changer || pending_user.state_changer
    assert_nil active_user.activated_at || pending_user.activated_at
  end

  # Tests for user destroy
  def test_destroy_of_user_should_destroy_announcements
    Announcement.destroy_all
    RecentActivity.destroy_all
    assert_difference('RecentActivity.count') do
      create_announcement(
        :program => programs(:albers),
        :admin => users(:f_admin),
        :title => "Hello",
        :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    end

    assert_difference 'RecentActivity.count', -1 do
      assert_difference "Announcement.count", -1 do
        users(:f_admin).destroy
      end
    end
  end

  def test_destroy_student_should_destroy_accepted_rejected_membership_requests
    MembershipRequest.destroy_all
    r1 = create_membership_request(roles: [RoleConstants::STUDENT_NAME])
    r2 = create_membership_request(roles: [RoleConstants::MENTOR_NAME])

    r1.admin = users(:f_admin)
    r2.admin = users(:f_admin)
    r1.update_attributes!(:status => MembershipRequest::Status::ACCEPTED, :accepted_role_names => [RoleConstants::STUDENT_NAME])
    r2.update_attributes!(:status => MembershipRequest::Status::REJECTED, :response_text => "Reason")

    assert_difference "MembershipRequest.count", -2 do
      users(:f_admin).destroy
    end
  end

  def test_destroy_student_should_destroy_comments
    a = create_article(:user => users(:f_mentor))
    Comment.create!(:publication => a.get_publication(programs(:albers)), :user => users(:f_student), :body => "Hi")
    assert_difference "Comment.count", -1 do
      users(:f_student).destroy
    end
  end

  def test_destroy_user_should_move_member_to_dormant_state_if_only_user
    assert_equal 4, members(:f_mentor).users.size
    assert_no_difference "Member.count" do
      assert_difference "User.count", -1 do
        users(:f_mentor).destroy
      end
    end

    assert members(:f_mentor_student).active?
    assert_equal 1, members(:f_mentor_student).users.size
    assert_no_difference "Member.count" do
      assert_difference "User.count", -1 do
        users(:f_mentor_student).destroy
      end
    end
    assert members(:f_mentor_student).reload.dormant?
  end

  def test_destroy_mentoring_connection_if_only_mentor
    assert groups(:multi_group).mentors.include?(users(:psg_mentor3))
    assert groups(:multi_group).mentors.size > 1
    assert_no_difference "Group.count" do
      assert_difference "User.count", -1 do
        users(:psg_mentor3).destroy
      end
    end

    assert_equal [users(:f_mentor)], groups(:mygroup).mentors
    assert_difference "Group.count", -1 do
      assert_difference "User.count", -1 do
        users(:f_mentor).destroy
      end
    end
  end

  def test_destroy_mentoring_connection_if_only_mentee
    assert groups(:multi_group).students.include?(users(:psg_student3))
    assert groups(:multi_group).students.size > 1
    assert_no_difference "Group.count" do
      assert_difference "User.count", -1 do
        users(:psg_student3).destroy
      end
    end

    assert_equal [users(:mkr_student)], groups(:mygroup).students
    assert_difference "Group.count", -1 do
      assert_difference "User.count", -1 do
        users(:mkr_student).destroy
      end
    end
  end

  def test_connection_limit_as_mentee_reached
    Group.destroy_all

    assert_nil programs(:albers).max_connections_for_mentee
    assert_false users(:f_student).connection_limit_as_mentee_reached?

    programs(:albers).update_attribute(:max_connections_for_mentee, 1)
    g1 = create_group(:student => users(:f_student))
    assert users(:f_student).reload.connection_limit_as_mentee_reached?
    assert_false users(:f_student).prompt_to_request?

    programs(:albers).update_attribute(:max_connections_for_mentee, 2)
    assert_false users(:f_student).reload.connection_limit_as_mentee_reached?

    create_group(:student => users(:f_student), :mentors => [users(:f_mentor_student)])
    assert users(:f_student).reload.connection_limit_as_mentee_reached?
    assert_false users(:f_student).prompt_to_request?

    g1.terminate!(users(:f_admin), "", g1.program.permitted_closure_reasons.first.id)
    assert_false users(:f_student).reload.connection_limit_as_mentee_reached?
  end

  def test_pending_request_limit_reached_for_mentee
    MentorRequest.destroy_all

    assert_nil programs(:albers).max_pending_requests_for_mentee
    assert_false users(:f_student).pending_request_limit_reached_for_mentee?

    programs(:albers).update_attribute(:max_pending_requests_for_mentee, 1)
    r1 = create_mentor_request(:student => users(:f_student))
    assert users(:f_student).reload.pending_request_limit_reached_for_mentee?
    assert_false users(:f_student).prompt_to_request?

    programs(:albers).update_attribute(:max_pending_requests_for_mentee, 2)
    assert_false users(:f_student).reload.pending_request_limit_reached_for_mentee?

    create_mentor_request(:student => users(:f_student), :mentor => users(:f_mentor_student))
    assert users(:f_student).reload.pending_request_limit_reached_for_mentee?
    assert_false users(:f_student).prompt_to_request?

    r1.mark_accepted!
    assert_false users(:f_student).pending_request_limit_reached_for_mentee?
  end

  # To test that max connections limit cannot be less than the number of students to the mentor through active groups
  def test_max_connections_limit_must_be_always_greater_than_students_count_and_non_negative
    allow_one_to_many_mentoring_for_program(programs(:albers))

    mentor_1 = users(:mentor_5)
    student_1 = users(:student_5)
    student_2 = users(:student_6)
    student_3 = users(:student_7)
    assert mentor_1.groups.empty?

    mentor_1.max_connections_limit = -5
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :max_connections_limit do
      mentor_1.save!
    end
    assert_equal true, mentor_1.errors[:max_connections_limit].include?(UserConstants::NEGATIVE_CONNECTIONS_LIMIT_ERROR_MESSAGE)

    mentor_1.max_connections_limit = 0
    assert_nothing_raised do
      mentor_1.save!
    end
    assert_equal 0, mentor_1.max_connections_limit
    mentor_1.update_attribute(:max_connections_limit, 4)
    g1 = create_group(:mentors => [mentor_1], :students => [student_1, student_3])
    g2 = create_group(:mentors => [mentor_1], :students => [student_2])
    mentor_1.max_connections_limit = 2
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :max_connections_limit do
      mentor_1.save!
    end
    assert_equal [UserConstants::MAX_CONNECTIONS_LIMIT_ERROR_MESSAGE], mentor_1.errors[:max_connections_limit]
    assert_equal 4, mentor_1.reload.max_connections_limit

    g1.terminate!(users(:f_admin), 'sorry', g1.program.permitted_closure_reasons.first.id)
    assert_equal Group::Status::CLOSED, g1.status
    assert_equal 1, mentor_1.students.size
    mentor_1.max_connections_limit = 1
    assert_nothing_raised do
      mentor_1.save!
    end
    assert_equal 1, mentor_1.max_connections_limit
  end

  def test_has_many_groups
    allow_one_to_many_mentoring_for_program(programs(:albers))
    mentor_1 = users(:mentor_5)
    mentor_2 = users(:mentor_6)
    student_1 = users(:student_5)
    student_2 = users(:student_6)
    student_3 = users(:student_7)

    assert mentor_1.groups.empty?
    assert mentor_2.groups.empty?
    assert student_1.groups.empty?
    assert student_2.groups.empty?
    assert student_3.groups.empty?
    g1 = create_group(:mentors => [mentor_1], :students => [student_1, student_3])
    g2 = create_group(:mentors => [mentor_2], :students => [student_3])
    g3 = create_group(:mentors => [mentor_2], :students => [student_2, student_1])
    mentor_1.groups.reload
    mentor_2.groups.reload
    student_1.groups.reload
    student_2.groups.reload
    student_3.groups.reload

    assert_equal [g1], mentor_1.groups
    assert_equal 1, mentor_1.groups.count
    assert_equal [g2, g3], mentor_2.groups
    assert_equal 2, mentor_2.groups.count
    assert_equal [g1, g3], student_1.groups
    assert_equal 2, student_1.groups.count
    assert_equal [g3], student_2.groups
    assert_equal 1, student_2.groups.count
    assert_equal [g1, g2], student_3.groups
    assert_equal 2, student_3.groups.count
  end

  def test_slots_available
    users(:ram).update_attribute(:max_connections_limit, 3)
    assert_equal 0, users(:ram).students.size
    assert_equal 3, users(:ram).slots_available

    make_member_of(:moderated_program, :ram)
    make_member_of(:moderated_program, :f_student)
    p = programs(:moderated_program)

    req = create_mentor_request(:student => users(:f_student), :mentor => nil, :program => p)
    req.assign_mentor!(users(:ram))
    assert_equal 2, users(:ram).reload.slots_available
    assert_equal 1, users(:ram).students.size
  end

  def test_slots_available_with_mentor_requests
    users(:f_mentor).update_attribute(:max_connections_limit, 3)
    assert_equal 1, users(:f_mentor).students.size
    assert_equal 2, users(:f_mentor).slots_available
    assert_equal 0, users(:f_mentor).slots_available_for_mentor_request

    users(:f_mentor).update_attribute(:max_connections_limit, 15)
    assert_equal 1, users(:f_mentor).students.size
    assert_equal 14, users(:f_mentor).slots_available
    assert_equal 3, users(:f_mentor).slots_available_for_mentor_request

    req = create_mentor_request(:student => users(:f_student), :mentor => users(:f_mentor), :program => programs(:albers))
    assert_equal 1, users(:f_mentor).students.size
    assert_equal 14, users(:f_mentor).slots_available
    assert_equal 2, users(:f_mentor).slots_available_for_mentor_request
  end

  def test_cached_available_and_can_accept_request
    assert_false users(:f_student).cached_available_and_can_accept_request?
    mentor = users(:f_mentor)
    program = mentor.program
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    program.update_attribute(:allow_one_to_many_mentoring, true)
    program.reload
    create_mentor_offer
    current_mentees = Connection::MenteeMembership.where(group_id: Group.with_mentor(mentor).active_or_drafted.pluck(:id)).count
    assert current_mentees > 0
    pending_mentor_requests = MentorRequest.where(receiver_id: mentor.id, status: AbstractRequest::Status::NOT_ANSWERED).count
    assert pending_mentor_requests > 0
    pending_mentor_offers = MentorOffer.from_mentor(mentor).pending.count
    assert pending_mentor_offers > 0
    mentor.update_attribute(:max_connections_limit, current_mentees + pending_mentor_requests + pending_mentor_offers + 1)
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert mentor.reload.cached_available_and_can_accept_request?
    Rails.cache.clear
    mentor.update_attribute(:max_connections_limit, pending_mentor_requests + pending_mentor_offers + 1)
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert_false mentor.reload.cached_available_and_can_accept_request?
    Connection::MenteeMembership.where(group_id: Group.with_mentor(mentor).active_or_drafted.pluck(:id)).destroy_all
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert mentor.reload.cached_available_and_can_accept_request?
    Rails.cache.clear
    mentor.update_attribute(:max_connections_limit, pending_mentor_offers + 1)
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert_false mentor.reload.cached_available_and_can_accept_request?
    MentorRequest.where(receiver_id: mentor.id, status: AbstractRequest::Status::NOT_ANSWERED).destroy_all
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert mentor.reload.cached_available_and_can_accept_request?
    Rails.cache.clear
    mentor.update_attribute(:max_connections_limit, 1)
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert_false mentor.reload.cached_available_and_can_accept_request?
    MentorOffer.from_mentor(mentor).pending.destroy_all
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert mentor.reload.cached_available_and_can_accept_request?
  end

  def test_filled_slots
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    users(:f_mentor).update_attribute(:max_connections_limit, 5)

    assert_equal 1, users(:f_mentor).students.size
    assert_equal 1, users(:f_mentor).filled_slots

    create_mentor_offer
    assert_equal 2, users(:f_mentor).reload.filled_slots
    assert_equal 1, users(:f_mentor).students.size

    make_member_of(:moderated_program, :f_mentor)
    make_member_of(:moderated_program, :f_student)
    p = programs(:moderated_program)

    assert_equal 2, users(:f_mentor).reload.filled_slots
    assert_equal 1, users(:f_mentor).students.size
  end

  def test_has_one_user_setting
    user = users(:f_mentor)
    assert_equal user.user_setting, user_settings(:f_mentor)
    assert_difference "UserSetting.count", -1 do
      assert_difference "User.count", -1 do
        user.destroy
      end
    end
  end

  def test_connected_with
    assert_empty users(:f_mentor).common_groups(users(:f_student))
    assert_false users(:f_mentor).connected_with?(users(:f_student))

    assert_equal [groups(:mygroup)], users(:f_mentor).common_groups(users(:mkr_student))
    assert users(:f_mentor).connected_with?(users(:mkr_student))

    assert_equal [groups(:mygroup)], users(:mkr_student).common_groups(users(:f_mentor))
    assert users(:mkr_student).connected_with?(users(:f_mentor))

    groups(:mygroup).terminate!(users(:f_admin), "some reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    assert_equal [groups(:mygroup)], users(:mkr_student).common_groups(users(:f_mentor))
    assert users(:mkr_student).connected_with?(users(:f_mentor))
  end

  def test_profile_incomplete_function_for_student
    q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::STUDENT_NAME], :required => true)
    q2 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["xyz", "Def"], :role_names => [RoleConstants::STUDENT_NAME], :required => true)
    u = users(:f_student)
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q1, :answer_value => "Abc")
    assert_equal [RoleConstants::STUDENT_NAME], u.reload.profile_incomplete_roles
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q2, :answer_value => "xyz")
    assert_equal [], u.reload.profile_incomplete_roles
  end

  def test_profile_incomplete_function_for_mentor
    q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    q2 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["xyz", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    u = users(:f_mentor)
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q1, :answer_value => "Abc")
    assert_equal [RoleConstants::MENTOR_NAME], u.reload.profile_incomplete_roles
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q2, :answer_value => "xyz")
    assert_equal [], u.reload.profile_incomplete_roles
  end

  def test_profile_incomplete_function_for_user_who_is_mentor_and_student
    q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    q2 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["xyz", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)

    q3 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["klm", "Def"], :role_names => [RoleConstants::STUDENT_NAME], :required => true)
    q4 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["pqr", "Def"], :role_names => [RoleConstants::STUDENT_NAME], :required => true)

    u = users(:f_mentor)
    u.add_role(RoleConstants::STUDENT_NAME)
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q1, :answer_value => "Abc")
    assert_equal [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME], u.reload.profile_incomplete_roles
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q3, :answer_value => "klm")
    assert_equal [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME], u.reload.profile_incomplete_roles
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q2, :answer_value => "xyz")
    assert_equal [RoleConstants::STUDENT_NAME], u.reload.profile_incomplete_roles
    ProfileAnswer.create!(:ref_obj => u.member, :profile_question => q4, :answer_value => "pqr")
    assert_equal [], u.reload.profile_incomplete_roles
  end

  def test_profile_pending
    u = users(:f_mentor)
    u.update_attribute(:state, User::Status::PENDING)
    assert u.reload.profile_pending?
    u.update_attribute(:state, User::Status::ACTIVE)
    assert !u.reload.profile_pending?
  end

  def test_profile_active
    u = users(:pending_user)
    assert_false u.reload.profile_active?
    u.update_attribute(:state, User::Status::ACTIVE)
    assert u.reload.profile_active?
  end

  def test_profile_incomplete_for
    mentor_q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    student_q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["klm", "Def"], :role_names => [RoleConstants::STUDENT_NAME], :required => true)
    u_mentor = users(:f_mentor)
    program = programs(:albers)
    assert u_mentor.profile_incomplete_for?(RoleConstants::MENTOR_NAME)
    assert !u_mentor.profile_incomplete_for?(RoleConstants::MENTOR_NAME, program, {required_questions: []})
    u_mentor.member.profile_answers.create!(:ref_obj => u_mentor.member, :profile_question => mentor_q1, :answer_value => "Abc")
    assert !u_mentor.reload.profile_incomplete_for?(RoleConstants::MENTOR_NAME)
    assert u_mentor.reload.profile_incomplete_for?(RoleConstants::MENTOR_NAME, program, {required_questions: [profile_questions(:student_string_q)]})
    u_student= users(:f_student)
    assert u_student.reload.profile_incomplete_for?(RoleConstants::STUDENT_NAME)
    assert !u_student.reload.profile_incomplete_for?(RoleConstants::STUDENT_NAME, program, {required_questions: []})
    u_student.member.profile_answers.create!(:ref_obj => u_student.member, :profile_question => student_q1, :answer_value => "klm")
    assert !u_student.reload.profile_incomplete_for?(RoleConstants::STUDENT_NAME)
    assert u_student.reload.profile_incomplete_for?(RoleConstants::STUDENT_NAME, program, {required_questions: [profile_questions(:student_string_q)]})
  end

  def test_profile_incomplete_questions
    mentor_q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    student_q1 = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["klm", "Def"], :role_names => [RoleConstants::STUDENT_NAME], :required => true)

    u_mentor = users(:f_mentor)
    program = programs(:albers)
    assert_equal [mentor_q1], u_mentor.profile_incomplete_questions(RoleConstants::MENTOR_NAME, program)
    assert_equal [], u_mentor.profile_incomplete_questions(RoleConstants::MENTOR_NAME, program, {required_questions: []})
    answer = u_mentor.member.profile_answers.create!(:ref_obj => u_mentor.member, :profile_question => mentor_q1, :answer_value => "Abc")
    assert_equal [], u_mentor.reload.profile_incomplete_questions(RoleConstants::MENTOR_NAME, program)
    assert_equal [profile_questions(:student_string_q)], u_mentor.reload.profile_incomplete_questions(RoleConstants::MENTOR_NAME, program, {required_questions: [profile_questions(:student_string_q)]})

    u_student = users(:f_student)
    assert_equal [student_q1], u_student.reload.profile_incomplete_questions(RoleConstants::STUDENT_NAME, program)
    assert_equal [], u_student.reload.profile_incomplete_questions(RoleConstants::STUDENT_NAME, program, {required_questions: []})
    u_student.member.profile_answers.create!(:ref_obj => u_student.member, :profile_question => student_q1, :answer_value => "klm")
    assert_equal [], u_student.reload.profile_incomplete_questions(RoleConstants::STUDENT_NAME, program)
    assert_equal [profile_questions(:student_string_q)], u_student.reload.profile_incomplete_questions(RoleConstants::STUDENT_NAME, program, {required_questions: [profile_questions(:student_string_q)]})

    conditional_mandatory_mentor_q1 = create_question(question_type: ProfileQuestion::Type::MULTI_CHOICE, question_choices: ["1", "2", "3"], role_names: [RoleConstants::MENTOR_NAME], required: true, conditional_question_id: mentor_q1.id, conditional_match_text: "Abc")
    assert_equal_unordered [conditional_mandatory_mentor_q1], u_mentor.reload.profile_incomplete_questions(RoleConstants::MENTOR_NAME, program)
    answer.answer_value = "Def"
    answer.save
    assert_equal_unordered [], u_mentor.reload.profile_incomplete_questions(RoleConstants::MENTOR_NAME, program)
  end

  def test_profile_incomplete_roles_for_limited_questions_where_both_questions_are_marked_required
    programs(:org_primary).profile_questions.destroy_all
    q1 = create_question(:question_text => "Native", :question_type => ProfileQuestion::Type::STRING, :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    rq = q1.role_questions.create(:role => programs(:albers).get_role(RoleConstants::STUDENT_NAME), :required => true)

    u_mentor_student = users(:f_mentor)
    u_mentor_student.add_role(RoleConstants::STUDENT_NAME)

    # COMMENT Should be assert_equal
    assert u_mentor_student.profile_incomplete_for?(RoleConstants::MENTOR_NAME)
    assert u_mentor_student.profile_incomplete_for?(RoleConstants::STUDENT_NAME)
    ProfileAnswer.create!(:ref_obj => u_mentor_student.member, :profile_question => q1, :answer_text => "Abc")
    u_mentor_student.reload
    assert !u_mentor_student.profile_incomplete_for?(RoleConstants::MENTOR_NAME)
    assert !u_mentor_student.profile_incomplete_for?(RoleConstants::STUDENT_NAME)
  end

  def test_profile_incomplete_roles_for_limited_questions_where_both_questions_are_not_marked_required
    programs(:org_primary).profile_questions.destroy_all
    # Two optional question that is duplicated.
    q = create_question(:question_text => "Native", :question_type => ProfileQuestion::Type::STRING, :role_names => [RoleConstants::MENTOR_NAME])
    rq = q.role_questions.create(:role => programs(:albers).get_role(RoleConstants::STUDENT_NAME))
    u_mentor_student= users(:f_mentor)
    u_mentor_student.add_role(RoleConstants::STUDENT_NAME)
    assert !u_mentor_student.profile_incomplete_for?(RoleConstants::MENTOR_NAME)
    assert !u_mentor_student.profile_incomplete_for?(RoleConstants::STUDENT_NAME)
  end

  def test_profile_incomplete_roles_for_limited_questions_where_mentor_question_is_marked_required
    programs(:org_primary).profile_questions.destroy_all
    # Optional in mentor profile and required in student profile.
    q7 = create_question(
      :question_text => "Street",
      :question_type => ProfileQuestion::Type::STRING,
      :role_names => [RoleConstants::MENTOR_NAME],
      :required => true,
      :program => programs(:albers))
    rq = q7.role_questions.create(:role => programs(:albers).get_role(RoleConstants::STUDENT_NAME))

    u_mentor_student= users(:f_mentor)
    u_mentor_student.add_role(RoleConstants::STUDENT_NAME)
    programs(:albers).reload

    # COMMENT 4 cases. 1), without any answer, 2) with mentor answer 3) with student answer 4) with both answers
    assert u_mentor_student.profile_incomplete_for?(RoleConstants::MENTOR_NAME)
    assert !u_mentor_student.profile_incomplete_for?(RoleConstants::STUDENT_NAME)
    a1 = ProfileAnswer.create!(:ref_obj => u_mentor_student.member, :profile_question => q7, :answer_text => "Abc")
    u_mentor_student.reload
    assert !u_mentor_student.profile_incomplete_for?(RoleConstants::MENTOR_NAME)
    assert !u_mentor_student.profile_incomplete_for?(RoleConstants::STUDENT_NAME)
  end

  def test_draft_articles
    assert_equal([articles(:draft_article)], Article.drafts)
  end

  def test_has_many_private_notes
    assert_equal [
      connection_private_notes(:mygroup_mentor_1),
      connection_private_notes(:mygroup_mentor_2)],
      users(:f_mentor).private_notes

    assert_equal [connection_private_notes(:group_2_student_1)],
      users(:student_2).private_notes

    assert_equal [], users(:student_7).private_notes
  end

  def test_accessible_program_forums
    mentor_user = users(:f_mentor)
    admin_user = users(:f_admin)
    common_forum = forums(:common_forum)
    assert_equal [forums(:forums_2), common_forum], mentor_user.accessible_program_forums
    assert_equal [forums(:forums_1), forums(:forums_2), common_forum], admin_user.accessible_program_forums

    common_forum.update_attribute(:group_id, groups(:mygroup).id)
    assert_equal [forums(:forums_2)], mentor_user.accessible_program_forums
    assert_equal [forums(:forums_1), forums(:forums_2)], admin_user.accessible_program_forums

    ceg_forum = create_forum(program: programs(:ceg))
    assert_false admin_user.accessible_program_forums.include?(ceg_forum)
  end

  def test_add_user_directly
    assert_false users(:f_admin).add_user_directly?([])

    assert users(:f_admin).can_add_non_admin_profiles?
    assert users(:f_admin).add_user_directly?([RoleConstants::MENTOR_NAME])

    assert users(:f_admin).can_add_non_admin_profiles?
    assert users(:f_admin).add_user_directly?([RoleConstants::STUDENT_NAME])

    assert users(:f_admin).add_user_directly?([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert users(:f_admin).add_user_directly?([RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME])

    assert users(:f_admin).can_manage_admins?
    assert users(:f_admin).add_user_directly?([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME])
  end

  def test_accessible_resources
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    s2 = programs(:nwen).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:title => "A", :programs => {programs(:albers) => [m1, s1], programs(:nwen) => [s2]})
    r2 = create_resource(:title => "B", :programs => {programs(:albers) => [m1]})
    r3 = create_resource(:title => "C", :programs => {programs(:albers) => [s1]})
    r4 = create_resource(:title => "D", :programs => {programs(:nwen) => [s2]})


    assert_equal [r1, r2], users(:f_mentor).accessible_resources
    assert_equal [r1, r3], users(:f_student).accessible_resources
    assert_equal [r1, r2, r3], users(:f_mentor_student).accessible_resources
    assert_equal [r1, r4], users(:f_mentor_nwen_student).accessible_resources

    assert_equal [r1, r2, r3], users(:f_mentor_student).accessible_resources(sort_field: "title")
    assert_equal [r1, r2, r3], users(:f_mentor_student).accessible_resources(sort_field: "title", sort_order: "asc")
    assert_equal [r3, r2, r1], users(:f_mentor_student).accessible_resources(sort_field: "title", sort_order: "desc")

    assert_equal [r1, r2], users(:f_mentor).accessible_resources(only_quick_links: true, resources_widget: true)
    assert_equal [r1, r3], users(:f_student).accessible_resources(only_quick_links: true, resources_widget: true)
  end

  def test_can_create_group_without_approval
    user = users(:f_mentor_pbe)

    r1 = user.program.roles.find_by(name: "student")
    r2 = user.program.roles.find_by(name: "mentor")

    User.any_instance.stubs(:roles).returns(Role.where(id: [r1.id, r2.id]))

    assert r1.needs_approval_to_create_circle?
    assert r2.needs_approval_to_create_circle?

    assert_false user.can_create_group_without_approval?

    r1.add_permission(RolePermission::CREATE_PROJECT_WITHOUT_APPROVAL)
    user.roles.reload
    assert user.can_create_group_without_approval?
  end

  def test_can_be_shown_proposed_groups
    admin_user = users(:f_admin_pbe)
    mentor_user = users(:f_student_pbe)
    mentee_user = users(:pbe_student_1)

    assert admin_user.can_manage_connections?
    assert mentor_user.groups.proposed.present?
    assert mentee_user.groups.proposed.empty?
    assert admin_user.groups.proposed.empty?

    User.any_instance.stubs(:can_create_group_without_approval?).returns(true)

    assert admin_user.can_be_shown_proposed_groups?
    assert mentor_user.can_be_shown_proposed_groups?
    assert_false mentee_user.can_be_shown_proposed_groups?

    User.any_instance.stubs(:can_create_group_without_approval?).returns(false)
    assert mentee_user.can_be_shown_proposed_groups?

    User.any_instance.stubs(:can_create_group_without_approval?).returns(true)
    admin_user.program.roles.find_by(name: "admin").remove_permission("manage_connections")
    admin_user.roles.reload
    assert_false admin_user.can_be_shown_proposed_groups?
  end

  def test_send_welcome_email
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)
    student_user = users(:f_student)
    mentor_student_user = users(:f_mentor_student)

    ChronusMailer.expects(:welcome_message_to_admin).once.returns(stub(:deliver_now))
    ChronusMailer.expects(:welcome_message_to_mentor).never
    ChronusMailer.expects(:welcome_message_to_mentee).never
    User.send_welcome_email(admin_user, [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    ChronusMailer.expects(:welcome_message_to_admin).never
    ChronusMailer.expects(:welcome_message_to_mentor).once.returns(stub(:deliver_now))
    ChronusMailer.expects(:welcome_message_to_mentee).never
    User.send_welcome_email(mentor_user, [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    ChronusMailer.expects(:welcome_message_to_admin).never
    ChronusMailer.expects(:welcome_message_to_mentor).never
    ChronusMailer.expects(:welcome_message_to_mentee).once.returns(stub(:deliver_now))
    User.send_welcome_email(student_user, [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    ChronusMailer.expects(:welcome_message_to_admin).never
    ChronusMailer.expects(:welcome_message_to_mentor).never
    ChronusMailer.expects(:welcome_message_to_mentee).once.returns(stub(:deliver_now))
    User.send_welcome_email(mentor_student_user, [RoleConstants::ADMIN_NAME, RoleConstants::STUDENT_NAME])
  end

  def test_allowed_to_send_message
    group = groups(:mygroup)
    program = group.program
    group_mentor = group.mentors.first
    group_student = group.students.first
    admin_user = users(:f_admin)
    non_admin_user = users(:f_student)

    assert program.allow_user_to_send_message_outside_mentoring_area?
    assert group_student.allowed_to_send_message?(group_mentor)
    assert admin_user.allowed_to_send_message?(group_mentor)
    assert non_admin_user.allowed_to_send_message?(group_mentor)

    program.update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)
    assert group_student.reload.allowed_to_send_message?(group_mentor)
    assert admin_user.reload.allowed_to_send_message?(group_mentor)
    assert_false non_admin_user.reload.allowed_to_send_message?(group_mentor)

    group.update_members(group.mentors, group.students + [non_admin_user])
    assert group_student.reload.allowed_to_send_message?(group_mentor)
    assert admin_user.reload.allowed_to_send_message?(group_mentor)
    assert non_admin_user.reload.allowed_to_send_message?(group_mentor)

    Group.any_instance.stubs(:scraps_enabled?).returns(false)
    assert_false group_student.reload.allowed_to_send_message?(group_mentor)
    assert admin_user.reload.allowed_to_send_message?(group_mentor)
    assert_false non_admin_user.reload.allowed_to_send_message?(group_mentor)

    Group.any_instance.stubs(:scraps_enabled?).returns(true)
    group.terminate!(admin_user, "Reason", program.permitted_closure_reasons.first.id)
    assert_false group_student.reload.allowed_to_send_message?(group_mentor)
    assert admin_user.reload.allowed_to_send_message?(group_mentor)
    assert_false non_admin_user.reload.allowed_to_send_message?(group_mentor)
  end

  def test_allowed_to_send_message_for_accepted_meeting
    chronus_s3_utils_stub
    student = users(:f_student)
    mentor = users(:f_mentor)
    programs(:albers).update_attribute :allow_user_to_send_message_outside_mentoring_area, false
    assert_false student.allowed_to_send_message?(mentor)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, members: [members(:f_student), members(:f_mentor)], :requesting_student => users(:f_student))
    assert_false student.allowed_to_send_message?(mentor)
    meeting.member_meetings.each do |mm|
      mm.update_attributes(attending: MemberMeeting::ATTENDING::YES)
    end
    assert student.allowed_to_send_message?(mentor)
  end

  def test_visible_to
    assert users(:f_mentor).visible_to?(users(:f_student))

    fetch_role(:albers, :student).remove_permission('view_mentors')
    assert_false users(:f_student).reload.can_view_mentors?

    assert_false users(:f_mentor).visible_to?(users(:f_student))
    assert_false users(:f_mentor).visible_to?(users(:student_2))
    assert users(:f_student).visible_to?(users(:f_student))
    assert users(:f_mentor).visible_to?(users(:f_mentor_student))
    assert users(:mentor_3).visible_to?(users(:f_mentor_student))

    users(:mentor_3).add_role(RoleConstants::STUDENT_NAME)
    assert users(:mentor_3).visible_to?(users(:f_mentor_student))

    fetch_role(:albers, :student).remove_permission('view_students')
    assert_false users(:f_student).reload.can_view_students?

    assert_false users(:student_2).visible_to?(users(:f_student))
    assert_false users(:f_student).visible_to?(users(:student_2).reload)
    assert users(:f_student).visible_to?(users(:f_mentor_student).reload)
    assert users(:f_student).visible_to?(users(:f_student))

    fetch_role(:albers, :mentor).remove_permission('view_students')

    # Both mentors and students cannot see students.
    assert_false users(:f_student).visible_to?(users(:f_mentor_student).reload)

    create_group(:students => [users(:f_student)], :mentors => [users(:f_mentor_student)])
    assert users(:f_student).reload.visible_to?(users(:f_mentor_student).reload)

    # Testing for other non default roles
    assert_false users(:f_user).visible_to?(users(:f_student).reload)
    programs(:albers).add_role_permission('student','view_users')
    assert users(:f_user).visible_to?(users(:f_student).reload)
  end

  def test_visible_to_with_accepted_meeting
    chronus_s3_utils_stub
    assert users(:f_mentor).visible_to?(users(:f_student))

    fetch_role(:albers, :student).remove_permission('view_mentors')
    assert_false users(:f_student).reload.can_view_mentors?
    assert_false users(:f_mentor).visible_to?(users(:f_student))
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, members: [members(:f_student), members(:f_mentor)], :requesting_student => users(:f_student))
    assert_false users(:f_mentor).visible_to?(users(:f_student))
    meeting.member_meetings.each do |mm|
      mm.update_attributes(attending: MemberMeeting::ATTENDING::YES)
    end
    assert users(:f_mentor).visible_to?(users(:f_student))
  end

  def test_has_accepted_flash_mentoring_meeting_with
    chronus_s3_utils_stub
    student = users(:f_student)
    mentor = users(:f_mentor)
    assert_false student.has_accepted_flash_mentoring_meeting_with?(mentor)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, members: [members(:f_student), members(:f_mentor)], :requesting_student => users(:f_student))
    assert_false student.has_accepted_flash_mentoring_meeting_with?(mentor)
    meeting.member_meetings.each do |mm|
      mm.update_attributes(attending: MemberMeeting::ATTENDING::YES)
    end
    assert student.has_accepted_flash_mentoring_meeting_with?(mentor)
  end

  def test_visible_to_if_recommended
    albers_mentoring = programs(:albers)
    robert = users(:robert)
    rahim = users(:rahim)
    other_student = users(:f_student)
    albers_mentoring.roles.find_by(name: "student").remove_permission("view_mentors")
    assert_false robert.visible_to?(other_student)
    assert robert.visible_to?(rahim)
  end

  def test_is_recommended
    ram = users(:ram)
    rahim = users(:rahim)
    other_student = users(:f_student)
    assert ram.is_recommended?(rahim)
    assert_false ram.is_recommended?(other_student)
  end

  def test_update_profile_updated_at
    assert_nil users(:f_admin).profile_updated_at
    users(:f_admin).set_last_profile_update_time
    assert users(:f_admin).reload.profile_updated_at
  end

  def test_suspended
    assert users(:inactive_user).suspended?
    assert_false users(:f_mentor).suspended?
  end

  def test_user_active_or_pending
    active_user = users(:f_mentor)
    pending_user = users(:foster_mentor1)
    suspended_user = users(:inactive_user)

    assert active_user.active_or_pending?
    assert pending_user.active_or_pending?
    assert_false suspended_user.active_or_pending?
  end

  def test_publish_profile
    user = users(:pending_user)
    admin = users(:f_admin)

    assert_no_emails do
      user.publish_profile!(admin)
    end
    assert_equal users(:f_admin), user.created_by
    assert user.active?

    create_question(question_type: ProfileQuestion::Type::MULTI_CHOICE, question_choices: ["Abc", "Def"], role_names: user.role_names, required: true)
    assert user.profile_incomplete_roles.present?
    assert_no_emails do
      user.publish_profile!(admin)
    end
    assert user.active?
  end

  def test_standalone_program_admin_becomes_organization_admin
    admin1 = create_user(:email => 'admin_gen@chronus.com', :role_names => [RoleConstants::ADMIN_NAME], :program => programs(:foster), :state => User::Status::ACTIVE)
    assert admin1.member.admin?
    admin1.demote_from_role!(RoleConstants::ADMIN_NAME, users(:foster_admin))

    user = users(:foster_mentor1)
    assert_false user.is_admin?
    assert_false user.member.admin?
    user.promote_to_role!(RoleConstants::ADMIN_NAME, users(:foster_admin))
    assert user.reload.is_admin?
    assert user.member.admin?
  end

  def test_answered_qa_questions
    user = users(:f_admin)
    question_1 = qa_questions(:what)
    assert_equal [], user.answered_qa_questions

    #Creating two answers for same question
    create_qa_answer(:qa_question => question_1, :user => user)
    create_qa_answer(:qa_question => question_1, :user => user)
    assert_equal [question_1], user.reload.answered_qa_questions

    question_2 = qa_questions(:why)
    create_qa_answer(:qa_question => question_2, :user => user)
    assert_equal [question_1, question_2], user.reload.answered_qa_questions
  end

  def test_should_destroy_user_favorites_on_destroying_the_user
    assert_equal 0,  users(:ram).favorited_requests.count
    assert_difference 'UserFavorite.count', 2 do
      UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "He is the best")
      UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor_student), :note => "He is the bestest")
    end
    assert_equal 1, users(:f_mentor_student).reload.being_favorites.count
    assert_difference 'UserFavorite.count', -1 do
      assert_difference 'User.count', -1 do
        users(:f_mentor_student).destroy
      end
    end
  end

  def test_update_roles
    u1 = users(:f_mentor)
    u2 = users(:f_mentor_nwen_student)

    assert_equal ["mentor"], u1.role_names
    assert_equal ["student"], u2.role_names

    u2.update_roles(["mentor"])
    u2.reload
    assert_equal ["mentor"], u2.role_names

    u1.update_roles(["student"])
    u1.reload
    assert_equal ["student"], u1.role_names

    u2.update_roles(["student"])
    u2.reload
    assert_equal ["student"], u2.role_names
  end

  def test_activities_to_show
    assert users(:f_mentor).activities_to_show[0].empty?

    activities = []

    0.upto(4) do |i|
      activities << RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS,
        :created_at => i.days.ago,
        :ref_obj => announcements(:assemble))
    end

    assert_equal [activities.reverse, activities.first.id], users(:f_mentor).activities_to_show
  end

  def test_activities_to_show_for_other_non_admin_roles
    user = users(:f_user)
    assert user.activities_to_show[0].empty?

    mentor_activity = RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS,
        :created_at => 1.days.ago,
        :ref_obj => announcements(:assemble))
    student_activity = RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTEES,
        :created_at => 1.days.ago,
        :ref_obj => announcements(:assemble))
    all_activity = RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::ALL,
        :created_at => 1.days.ago,
        :ref_obj => announcements(:assemble))
    other_non_admin_activity = RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::OTHER_NON_ADMINISTRATIVE_ROLES,
        :created_at => 1.days.ago,
        :ref_obj => announcements(:assemble))
    assert_false user.activities_to_show[0].include?(mentor_activity)
    assert_false user.activities_to_show[0].include?(student_activity)
    assert user.activities_to_show[0].include?(all_activity)
    assert user.activities_to_show[0].include?(other_non_admin_activity)
  end

  def test_activities_to_show_with_mentoring_connection_v2_enabled
    activities = []

    create_scrap(:group => groups(:mygroup), :sender => groups(:mygroup).students.first.member)
    activities << RecentActivity.last
    p = programs(:albers)

    p.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    grouped_activites = users(:f_mentor).activities_to_show[0]
    assert_not_equal activities, grouped_activites
  end

  def test_grouped_activities_doesnt_fetch_activities_targeted_at_none
    assert_difference "RecentActivity.count" do
      RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::NONE
      )
    end

    assert_equal [[], false], users(:moderated_student).activities_to_show
    assert_equal [[], false], users(:moderated_mentor).activities_to_show
    assert_equal [[], false], users(:moderated_admin).activities_to_show
  end

  def test_scrap_activities_are_not_for_display
    activities = []

    create_scrap(:group => groups(:mygroup), :sender => groups(:mygroup).students.first.member)
    activities << RecentActivity.last

    grouped_activites = users(:f_mentor).activities_to_show[0]
    assert grouped_activites.empty?
    grouped_activites = users(:f_admin).activities_to_show[0]
    assert grouped_activites.empty?
  end

  def test_grouped_activities_ignores_disabled_feature_activities
    p = programs(:albers)

    RecentActivity.create!(
      :programs => [programs(:albers)],
      :action_type => RecentActivityConstants::Type::ARTICLE_CREATION,
      :target => RecentActivityConstants::Target::ADMINS,
      :ref_obj => articles(:economy),
      :member => articles(:economy).author
    )

    RecentActivity.create!(
      :programs => [programs(:albers)],
      :action_type => RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL,
      :target => RecentActivityConstants::Target::USER,
      :ref_obj => articles(:economy),
      :member => members(:f_student),
      :for => articles(:economy).author
    )

    comment = Comment.create(
      :publication => articles(:economy).get_publication(programs(:albers)),
      :user => users(:rahim), :body => "Abc")

    RecentActivity.create!(
      :programs => [programs(:albers)],
      :action_type => RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION,
      :member => comment.user.member,
      :ref_obj => comment,
      :target => RecentActivityConstants::Target::ALL
    )

    assert users(:f_admin).activities_to_show[0].any?
    p.organization.enable_feature(FeatureName::ARTICLES, false)
    assert !p.reload.organization.has_feature?(FeatureName::ARTICLES)
    assert users(:f_mentor).activities_to_show[0].empty?
  end

  def test_grouped_activities_ignores_qa_when_disabled
    p = programs(:albers)
    assert p.reload.organization.has_feature?(FeatureName::ANSWERS)

    RecentActivity.create!(
      :programs => [programs(:albers)],
      :action_type => RecentActivityConstants::Type::QA_QUESTION_CREATION,
      :target => RecentActivityConstants::Target::ALL,
      :ref_obj => qa_questions(:what),
      :member => qa_questions(:what).user.member
    )

    RecentActivity.create!(
      :programs => [programs(:albers)],
      :action_type => RecentActivityConstants::Type::QA_ANSWER_CREATION,
      :target => RecentActivityConstants::Target::ALL,
      :ref_obj => qa_answers(:for_question_why),
      :member => qa_answers(:for_question_why).user.member
    )

    assert_equal users(:f_mentor).activities_to_show[0].count, 2
    p.organization.enable_feature(FeatureName::ANSWERS, false)
    assert !p.reload.organization.has_feature?(FeatureName::ANSWERS)
    assert users(:f_mentor).reload.activities_to_show[0].empty?
  end

  def test_grouped_activities_ignores_membership_req_activities_when_disabled
    p = programs(:albers)

    assert_difference('RecentActivity.count') do
      create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    end

    ra = RecentActivity.last
    assert_equal(MembershipRequest.to_s, ra.ref_obj_type)
    assert_equal(RecentActivityConstants::Type::CREATE_MEMBERSHIP_REQUEST, ra.action_type)
    assert_equal(RecentActivityConstants::Target::ADMINS, ra.target)

    assert users(:f_admin).activities_to_show[0].any?

    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.save

    assert users(:f_mentor).activities_to_show[0].empty?
  end

  def test_activities_to_show_as_actor
    assert users(:f_mentor).activities_to_show(:actor => users(:f_mentor))[0].empty?
    assert users(:f_mentor).activities_to_show(:actor => users(:mentor_1))[0].empty?

    f_mentor_activities = []
    mentor_1_activities = []

    mentor_1_activities << RecentActivity.create!(
      :programs => [programs(:albers)],
      :member => members(:mentor_1),
      :action_type => RecentActivityConstants::Type::ARTICLE_CREATION,
      :ref_obj => articles(:kangaroo),
      :target => RecentActivityConstants::Target::ALL
    )

    assert_equal f_mentor_activities.reverse, users(:f_mentor).activities_to_show(:actor => users(:f_mentor))[0]
    assert_equal mentor_1_activities.reverse, users(:f_mentor).activities_to_show(:actor => users(:mentor_1))[0]

    f_mentor_activities << RecentActivity.create!(
      :programs => [programs(:albers)],
      :member => members(:f_mentor),
      :action_type => RecentActivityConstants::Type::ARTICLE_CREATION,
      :ref_obj => articles(:kangaroo),
      :target => RecentActivityConstants::Target::ALL
    )

    assert_equal f_mentor_activities.reverse, users(:f_mentor).activities_to_show(:actor => users(:f_mentor))[0]
    assert_equal mentor_1_activities.reverse, users(:f_mentor).activities_to_show(:actor => users(:mentor_1))[0]

    f_mentor_activities << RecentActivity.create!(
      :programs => [programs(:albers)],
      :member => members(:f_mentor),
      :action_type => RecentActivityConstants::Type::ARTICLE_CREATION,
      :ref_obj => articles(:kangaroo),
      :target => RecentActivityConstants::Target::ALL
    )

    assert_equal f_mentor_activities.reverse, users(:f_mentor).activities_to_show(:actor => users(:f_mentor))[0]
    assert_equal mentor_1_activities.reverse, users(:f_mentor).activities_to_show(:actor => users(:mentor_1))[0]
  end

  def test_activities_to_show_with_offset_and_length
    assert users(:f_mentor).activities_to_show[0].empty?

    activities = []

    0.upto(4) do |i|
      activities << RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS,
        :created_at => i.days.ago,
        :ref_obj => announcements(:assemble))
    end

    activities.reverse!

    assert_equal activities,                      users(:f_mentor).activities_to_show[0]
    assert_equal [activities[3], activities[4]],  users(:f_mentor).activities_to_show(:offset_id => activities[2].id)[0]
    assert_equal [activities[4]],                 users(:f_mentor).activities_to_show(:offset_id => activities[3].id)[0]
    assert_equal [],                              users(:f_mentor).activities_to_show(:offset_id => activities[4].id)[0]
    assert_equal activities - [activities[0]],    users(:f_mentor).activities_to_show(:offset_id => activities[0].id)[0]
    assert_equal [],                              users(:f_mentor).activities_to_show(:offset_id => activities[0].id - 5)[0]
  end

  def test_education_valid
    user = users(:f_student)
    member = user.member
    member.educations.all.collect(&:destroy)
    question = profile_questions(:multi_education_q)
    answer = user.answer_for(question) || member.profile_answers.build( :profile_question => question)
    edu = answer.educations.build(:school_name => nil, :major => "My Major")
    edu.profile_answer = answer
    assert !member.valid?
    assert member.errors[:educations].blank?
    assert_equal ["is invalid"], member.errors[:profile_answers]
  end

  def test_experience_valid
    user = users(:f_student)
    member = user.member
    member.experiences.all.collect(&:destroy)
    question = profile_questions(:multi_experience_q)
    answer = user.answer_for(question) || member.profile_answers.build( :profile_question => question)
    exp = answer.experiences.build(:job_title => "SDE")
    exp.profile_answer = answer
    assert !member.valid?
    assert member.errors[:experiences].blank?
    assert_equal ["is invalid"], member.errors[:profile_answers]
  end

  def test_can_be_shown_group_start_date
    group = groups(:mygroup)
    user = users(:mkr_student)
    admin_user = users(:f_admin)

    Group.any_instance.stubs(:drafted?).returns(true)
    Group.any_instance.stubs(:proposed?).returns(false)
    Group.any_instance.stubs(:pending?).returns(false)
    Group.any_instance.stubs(:has_member?).returns(false)
    assert admin_user.can_be_shown_group_start_date?(group)

    Group.any_instance.stubs(:drafted?).returns(true)
    Group.any_instance.stubs(:proposed?).returns(false)
    Group.any_instance.stubs(:pending?).returns(false)
    Group.any_instance.stubs(:has_member?).returns(false)
    assert_false user.can_be_shown_group_start_date?(group)

    Group.any_instance.stubs(:drafted?).returns(false)
    Group.any_instance.stubs(:proposed?).returns(true)
    Group.any_instance.stubs(:pending?).returns(false)
    Group.any_instance.stubs(:has_member?).returns(false)
    assert admin_user.can_be_shown_group_start_date?(group)

    Group.any_instance.stubs(:drafted?).returns(false)
    Group.any_instance.stubs(:proposed?).returns(true)
    Group.any_instance.stubs(:pending?).returns(false)
    Group.any_instance.stubs(:has_member?).returns(true)
    assert user.can_be_shown_group_start_date?(group)

    Group.any_instance.stubs(:drafted?).returns(false)
    Group.any_instance.stubs(:proposed?).returns(true)
    Group.any_instance.stubs(:pending?).returns(false)
    Group.any_instance.stubs(:has_member?).returns(false)
    assert_false user.can_be_shown_group_start_date?(group)

    Group.any_instance.stubs(:drafted?).returns(false)
    Group.any_instance.stubs(:proposed?).returns(false)
    Group.any_instance.stubs(:pending?).returns(true)
    Group.any_instance.stubs(:has_member?).returns(false)
    assert admin_user.can_be_shown_group_start_date?(group)

    Group.any_instance.stubs(:drafted?).returns(false)
    Group.any_instance.stubs(:proposed?).returns(false)
    Group.any_instance.stubs(:pending?).returns(true)
    Group.any_instance.stubs(:has_member?).returns(true)
    assert user.can_be_shown_group_start_date?(group)

    Group.any_instance.stubs(:drafted?).returns(false)
    Group.any_instance.stubs(:proposed?).returns(false)
    Group.any_instance.stubs(:pending?).returns(true)
    Group.any_instance.stubs(:has_member?).returns(false)
    assert_false user.can_be_shown_group_start_date?(group)
  end

  def test_can_set_start_date_for_group
    group = groups(:mygroup)
    user = users(:mkr_student)
    admin_user = users(:f_admin)

    assert admin_user.can_set_start_date_for_group?(group)

    assert_false group.has_member?(users(:f_student))
    assert_false users(:f_student).can_set_start_date_for_group?(group)

    connection_membership = group.membership_of(user)
    assert_false connection_membership.owner
    assert_false user.can_set_start_date_for_group?(group)

    connection_membership.update_attribute(:owner, true)
    assert user.can_set_start_date_for_group?(group)
  end

  def test_publication_valid
    user = users(:f_student)
    member = user.member
    member.publications.all.collect(&:destroy)
    question = profile_questions(:multi_publication_q)
    answer = user.answer_for(question) || member.profile_answers.build( :profile_question => question)
    exp = answer.publications.build(:publisher => "Publisher")
    exp.profile_answer = answer
    assert !member.valid?
    assert member.errors[:publications].blank?
    assert_equal ["is invalid"], member.errors[:profile_answers]
  end

  def test_manager_valid
    user = users(:f_student)
    member = user.member
    question = profile_questions(:manager_q)
    answer = user.answer_for(question) || member.profile_answers.build( :profile_question => question)
    manager = answer.build_manager(:first_name => "name")
    manager.profile_answer = answer
    assert !member.valid?
    assert member.errors[:manager].blank?
    assert_equal ["is invalid"], member.errors[:profile_answers]
  end


  def test_skype_id
    skype_question = programs(:org_primary).profile_questions.skype_question.first
    users(:f_mentor).member.profile_answers.create!(:profile_question => skype_question, :answer_text => 'api', :ref_obj => members(:f_mentor))
    assert_equal 'api', users(:f_mentor).skype_id
  end

  def test_user_location
    location = locations(:chennai)
    user = users(:f_mentor)
    loc_ques = profile_answers(:location_chennai_ans).profile_question
    answer = user.answer_for(loc_ques)
    answer.update_attribute :location, location
    assert_equal location, user.location
    assert_equal location.full_address, user.location_name
    assert_equal 3, user.location.profile_answers_count
    assert_equal "Chennai, Tamil Nadu, India", user.location.full_address
  end

  def test_can_view_received_mentor_requests
    assert users(:f_mentor).can_view_received_mentor_requests?
    assert_false users(:f_admin).can_view_received_mentor_requests?
  end

  def test_can_manage_mentoring_sessions
    assert_false users(:f_mentor).can_manage_mentoring_sessions?
    assert users(:f_admin).can_manage_mentoring_sessions?
  end

  def test_primary_home_tab_range
    u = users(:f_student)
    u.update_attribute :primary_home_tab, 2
    assert u.valid?

    u.update_attribute :primary_home_tab, 4
    assert_false u.valid?
  end

  def test_get_meeting_slots_booked_in_the_month
    invalidate_albers_calendar_meetings
    user = users(:f_mentor)
    meeting1 = meetings(:f_mentor_mkr_student)
    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    view_date = meeting1.start_time
    start_time = view_date.end_of_month.end_of_day  - (2.days + 5.hours + 30.minutes)
    end_time = view_date.end_of_month.end_of_day + 3.days + 5.hours
    update_recurring_meeting_start_end_date(daily_meeting, start_time, end_time)

    slots = user.get_meeting_slots_booked_in_the_month(view_date)
    assert_equal 4, slots

    daily_meeting.add_exception_rule_at(daily_meeting.occurrences.first.start_time.to_s)
    slots = user.get_meeting_slots_booked_in_the_month(view_date)
    assert_equal 3, slots
  end

  def test_get_received_pending_meeting_requests_in_the_month
    user = users(:f_mentor)
    program = user.program
    student = users(:mkr_student)
    time = "2025-03-05 18:15:00".to_time
    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true,start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert_equal 1, user.get_received_pending_meeting_requests_in_the_month(time + 2.days)
    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true,start_time: time.next_month, end_time: time.next_month + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert_equal 1, user.get_received_pending_meeting_requests_in_the_month(time + 2.days)

    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true,start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    create_meeting_proposed_slot({start_time: time + 3.days, end_time: time + 3.days + 30.minutes, meeting_request_id: meeting_request.id})
    create_meeting_proposed_slot({start_time: time.next_month, end_time: time.next_month + 30.minutes, meeting_request_id: meeting_request.id})

    assert_equal 2, user.get_received_pending_meeting_requests_in_the_month(time + 2.days)
    meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_equal 1, user.get_received_pending_meeting_requests_in_the_month(time + 2.days)
  end

  def test_is_capacity_reached_for_current_and_next_month
    view_date = Time.now

    user = users(:f_mentor)
    student = users(:mkr_student)
    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date).returns(true)
    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date.next_month).returns(true)
    assert user.is_capacity_reached_for_current_and_next_month?(view_date, student)
    assert_equal [true, "Good unique name has already reached the limit for the number of meetings and is not available for meetings"], user.is_capacity_reached_for_current_and_next_month?(view_date, student, {error_message: true})

    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date).returns(false)
    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date.next_month).returns(false)
    User.any_instance.expects(:is_student_meeting_limit_reached?).twice.with(view_date).returns(true)
    User.any_instance.expects(:is_student_meeting_limit_reached?).twice.with(view_date.next_month).returns(true)

    assert user.is_capacity_reached_for_current_and_next_month?(view_date, student)
    assert_equal [true, "You cannot send any more meeting requests as you have reached the limit for the number of meetings"], user.is_capacity_reached_for_current_and_next_month?(view_date, student, {error_message: true})

    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date).returns(true)
    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date.next_month).returns(false)
    User.any_instance.expects(:is_student_meeting_limit_reached?).twice.with(view_date).returns(false)
    User.any_instance.expects(:is_student_meeting_limit_reached?).twice.with(view_date.next_month).returns(true)
    assert user.is_capacity_reached_for_current_and_next_month?(view_date, student)
    assert_equal [true, "You cannot send any more meeting requests as you have reached the limit for the number of meetings"], user.is_capacity_reached_for_current_and_next_month?(view_date, student, {error_message: true})

    User.any_instance.expects(:is_max_capacity_user_reached?).once.with(view_date).returns(false)
    User.any_instance.expects(:is_max_capacity_user_reached?).once.with(view_date.next_month).returns(false)
    User.any_instance.expects(:is_student_meeting_limit_reached?).once.with(view_date).returns(false)
    User.any_instance.expects(:is_student_meeting_limit_reached?).once.with(view_date.next_month).returns(false)
    assert_false user.is_capacity_reached_for_current_and_next_month?(view_date, student)[0]

    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date).returns(false)
    User.any_instance.expects(:is_max_capacity_user_reached?).twice.with(view_date.next_month).returns(false)
    User.any_instance.expects(:is_student_meeting_limit_reached?).twice.with(view_date).returns(false)
    User.any_instance.expects(:is_student_meeting_limit_reached?).twice.with(view_date.next_month).returns(false)
    User.any_instance.expects(:is_student_meeting_request_limit_reached?).twice.returns(true)
    assert user.is_capacity_reached_for_current_and_next_month?(view_date, student)
    assert_equal [true, "You cannot send any more meeting requests as you have reached the limit for the number of concurrent pending requests. Please withdraw a pending request to send a new request."], user.is_capacity_reached_for_current_and_next_month?(view_date, student, {error_message: true})
  end


  def test_is_max_capacity_user_reached
    user = users(:f_mentor)
    program = user.program
    student = users(:mkr_student)
    st = "2025-03-05 18:15:00".to_time
    user.user_setting.update_attributes(max_meeting_slots: 2)
    period_start_time, period_end_time = st.utc.beginning_of_month.beginning_of_day, st.utc.end_of_month.end_of_day

    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    start_time = period_end_time  - (2.days + 5.hours + 30.minutes)
    end_time = period_end_time + 3.days + 5.hours
    update_recurring_meeting_start_end_date(daily_meeting, start_time, end_time)

    assert user.is_max_capacity_user_reached?(st)
    daily_meeting.update_attributes(:active => false)

    assert_false user.is_max_capacity_user_reached?(st)
    assert_equal 2, user.user_setting.max_meeting_slots

    time = st + 2.days
    proposed_slot = create_meeting_proposed_slot({start_time: time + 3.days, end_time: time + 3.days + 30.minutes})
    assert_false user.is_max_capacity_user_reached?(st)

    proposed_slot_1 = create_meeting_proposed_slot({start_time: time + 3.days, end_time: time + 3.days + 30.minutes})
    assert user.is_max_capacity_user_reached?(st)
  end

  def test_is_mentoring_slots_limit_reached
    user = users(:f_mentor)
    member = user.member
    program = user.program
    student = users(:mkr_student)
    st = "2025-03-05 18:15:00".to_time
    user.user_setting.update_attributes(max_meeting_slots: 2)
    slot = member.mentoring_slots.first
    slot.update_attributes!(start_time: st, end_time: st + 30.minutes)
    member.reload
    User.any_instance.stubs(:is_opted_for_slot_availability?).returns(true)
    assert_false user.is_mentoring_slots_limit_reached?(st)
    assert user.is_mentoring_slots_limit_reached?(st.next_month)
  end

  def test_is_max_capacity_program_reached
    view_date = Time.now
    user = users(:f_mentor)
    student = users(:mkr_student)
    User.any_instance.expects(:is_student_meeting_limit_reached?).returns(true)
    assert user.is_max_capacity_program_reached?(view_date, student)

    User.any_instance.expects(:is_student_meeting_limit_reached?).returns(false)
    User.any_instance.expects(:is_student_meeting_request_limit_reached?).returns(true)
    assert user.is_max_capacity_program_reached?(view_date, student)

    User.any_instance.expects(:is_student_meeting_limit_reached?).returns(false)
    User.any_instance.expects(:is_student_meeting_request_limit_reached?).returns(false)
    assert_false user.is_max_capacity_program_reached?(view_date, student)
  end

  def test_is_student_meeting_limit_reached
    user = users(:f_mentor)
    program = user.program
    student = users(:mkr_student)
    program.calendar_setting.update_attributes(max_meetings_for_mentee: 1)
    program.reload
    time = "2025-03-05 18:15:00".to_time
    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true,start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    view_date = time + 2.days
    assert_false student.is_student_meeting_limit_reached?(view_date)
    meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert student.is_student_meeting_limit_reached?(view_date)
    program.calendar_setting.update_attributes(max_meetings_for_mentee: nil)
    program.reload
    student.reload
    assert_false student.is_student_meeting_limit_reached?(view_date)
  end

  def test_is_student_meeting_request_limit_reached
    user = users(:f_mentor)
    program = user.program
    student = users(:mkr_student)
    program.calendar_setting.update_attributes(max_pending_meeting_requests_for_mentee: 1)
    program.reload
    time = "2025-03-05 18:15:00".to_time
    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true,start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert student.is_student_meeting_request_limit_reached?
    meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false student.is_student_meeting_request_limit_reached?
  end

  def test_is_student_meeting_limit_reached_with_recurring_meeting
    user = users(:f_mentor)
    program = user.program
    student1 = users(:mkr_student)
    student2 = users(:rahim)
    st = mentoring_slots(:f_mentor).start_time
    period_start_time, period_end_time = st.utc.beginning_of_month.beginning_of_day, st.utc.end_of_month.end_of_day

    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    start_time = period_end_time  - (2.days + 5.hours + 30.minutes)
    end_time = period_end_time + 3.days + 5.hours
    update_recurring_meeting_start_end_date(daily_meeting, start_time, end_time)

    program.calendar_setting.update_attributes!(max_meetings_for_mentee: 4)
    program.reload
    student1.reload
    student2.reload
    assert student1.is_student_meeting_limit_reached?(st)
    assert_false student2.is_student_meeting_limit_reached?(st)
    daily_meeting.add_exception_rule_at(daily_meeting.occurrences.first.start_time.to_s)
    invalidate_albers_calendar_meetings
    assert_false student1.is_student_meeting_limit_reached?(st)
  end

  def test_is_meeting_capacity_reached
    meetings(:f_mentor_mkr_student_daily_meeting).update_attributes(:active => false)
    invalidate_albers_calendar_meetings
    user = users(:f_mentor)
    program = user.program
    student = users(:mkr_student)
    st = mentoring_slots(:f_mentor).start_time
    period_start_time, period_end_time = st.utc.beginning_of_month.beginning_of_day, st.utc.end_of_month.end_of_day
    meetings(:f_mentor_mkr_student).update_meeting_time(Time.now.utc.beginning_of_month + 2.days, 1800.00)

    user.user_setting.update_attributes!(:max_meeting_slots => 2)
    assert_false user.is_max_capacity_user_reached?(st)
    assert_false student.is_student_meeting_limit_reached?(st)
    assert_false user.is_meeting_capacity_reached?(st, student)

    user.user_setting.update_attributes!(:max_meeting_slots => 1)
    program.calendar_setting.update_attributes!(:max_meetings_for_mentee => 1)
    student.reload
    assert user.is_max_capacity_user_reached?(st)
    assert student.is_student_meeting_limit_reached?(st)
    assert user.is_meeting_capacity_reached?(st, student)
  end

  def test_is_meeting_capacity_reached_with_recurring_meeting
    invalidate_albers_calendar_meetings
    user = users(:f_mentor)
    program = user.program
    student = users(:mkr_student)
    st = mentoring_slots(:f_mentor).start_time
    student2 = users(:rahim)
    period_start_time, period_end_time = st.utc.beginning_of_month.beginning_of_day, st.utc.end_of_month.end_of_day

    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    start_time = period_end_time  - (2.days + 5.hours + 30.minutes)
    end_time = period_end_time + 3.days + 5.hours
    update_recurring_meeting_start_end_date(daily_meeting, start_time, end_time)
    meetings(:f_mentor_mkr_student).update_meeting_time(Time.now.utc.beginning_of_month + 2.days, 1800.00)

    assert user.is_meeting_capacity_reached?(st, student)
    assert user.is_meeting_capacity_reached?(st, student2)
    user.user_setting.update_attributes!(:max_meeting_slots => 6)
    program.calendar_setting.update_attributes!(:max_meetings_for_mentee => 4)
    program.reload
    student.reload
    assert user.is_meeting_capacity_reached?(st, student)
    assert_false user.is_meeting_capacity_reached?(st, student2)

    program.calendar_setting.update_attributes!(:max_meetings_for_mentee => 6)
    student.reload
    assert_false user.is_meeting_capacity_reached?(st, student)
  end

  def test_is_max_capacity_setting_initialized
    user1 = users(:f_mentor)
    user2 = users(:robert)
    assert user1.is_max_capacity_setting_initialized?
    assert_false user2.is_max_capacity_setting_initialized?
  end

  def test_can_current_user_create_meeting
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user = users(:f_mentor)
    current_organization = programs(:org_primary)
    current_program = programs(:albers)
    assert_false current_user.can_create_meeting?(current_program)
    current_program.calendar_setting.update_attribute(:allow_create_meeting_for_mentor, true)
    current_program.reload
    assert current_user.can_create_meeting?(current_program)
    current_user = users(:f_student)
    assert_false current_user.can_create_meeting?(current_program)
    OrganizationFeature.last.destroy
    current_organization.reload
    current_program.reload
    current_user = users(:f_mentor)
    assert_false current_user.can_create_meeting?(current_program)
  end

  def test_has_non_admin_role
    user1 = users(:f_admin)
    assert_equal ['admin'], user1.role_names
    assert_false user1.has_non_admin_role?

    user2 = users(:f_student)
    assert_equal ['student'], user2.role_names
    assert user2.has_non_admin_role?

    user3 = users(:f_mentor_student)
    assert_equal ['mentor', 'student'], user3.role_names
    assert user3.has_non_admin_role?

    user4 = users(:f_user)
    assert_equal ['user'], user4.role_names
    assert user4.has_non_admin_role?
  end

  def test_create_ra_and_mail_for_promoting_to_role
    user = users(:f_student)
    admin = users(:f_admin)
    assert_emails 0 do
      assert_difference "RecentActivity.count", 0 do
        user.create_ra_and_mail_for_promoting_to_role([], admin, '', false)
      end
    end

    assert_emails 1 do
      assert_difference "RecentActivity.count", 1 do
        user.create_ra_and_mail_for_promoting_to_role(["mentor"], admin, '', false)
      end
    end
  end

  def test_resend_instructions_email
    users_array = [users(:f_mentor), users(:mkr_student)]
    assert_emails 2 do
      User.resend_instructions_email(programs(:albers), users_array.collect(&:id))
    end
    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal users_array.collect(&:email), emails.collect{|email| email.to.first}
  end

  def test_resend_instructions_mail_with_job_logs
    users_array = [users(:f_mentor), users(:mkr_student)]
    assert_emails 2 do
      User.resend_instructions_email(programs(:albers), users_array.collect(&:id), "15")
    end
    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal users_array.collect(&:email), emails.collect{|email| email.to.first}

    assert_no_emails do
      User.resend_instructions_email(programs(:albers), users_array.collect(&:id), "15")
    end

    users_array << users(:ram)
    assert_emails 1 do
      User.resend_instructions_email(programs(:albers), users_array.collect(&:id), "15")
    end

    assert_no_emails do
      User.resend_instructions_email(programs(:albers), users_array.collect(&:id), "15")
    end
  end

  def test_requires_signup
    user = users(:f_mentor)
    assert_false user.requires_signup?

    user.update_attribute(:last_seen_at, Time.now)
    assert_false user.requires_signup?

    user.update_attribute(:last_seen_at, nil)
    user.member.stubs(:can_signin?).returns(false)
    assert user.requires_signup?
  end

  def test_ask_to_set_availability
    user_1 = users(:f_mentor)
    user_2 = users(:f_student)
    member_1 = user_1.member
    member_2 = user_2.member

    member_1.update_attributes!(will_set_availability_slots: true)
    member_2.update_attributes!(will_set_availability_slots: true)

    calendar_setting = user_1.program.calendar_setting
    calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)

    assert_equal true, user_1.ask_to_set_availability?
    assert_equal false, user_2.ask_to_set_availability?

    member_1.update_attributes!(will_set_availability_slots: false)
    member_2.update_attributes!(will_set_availability_slots: false)
    assert_equal false, user_1.ask_to_set_availability?
    assert_equal false, user_2.ask_to_set_availability?

    calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: false)
    assert_equal false, user_1.ask_to_set_availability?
    assert_equal false, user_2.ask_to_set_availability?

    member_1.update_attributes!(will_set_availability_slots: false)
    member_2.update_attributes!(will_set_availability_slots: false)
    assert_equal false, user_1.ask_to_set_availability?
    assert_equal false, user_2.ask_to_set_availability?
  end

  def test_withdraw_active_requests_should_success
    program = programs(:albers)
    student = users(:f_student)
    mentors = [users(:f_mentor_student), users(:f_mentor)]

    # set limits attributes
    program_attributes = {
      max_pending_requests_for_mentee: 2,
      max_connections_for_mentee:      1,
    }
    program.update_attributes!(program_attributes)

    requests = mentors.map do |mentor|
      MentorRequest.create!(program: program, student: student, mentor: mentor, message: "Hi")
    end
    group = create_group(:mentors => [users(:f_mentor_pbe)], :students => [], :program => programs(:pbe), :status => Group::Status::PENDING )
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MentorRequest, requests.collect(&:id)).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MentorRequest, []).times(3)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(ProjectRequest, []).at_least(0)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, any_parameters).at_least(0)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Group, any_parameters).at_least(0)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [2])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [5])

    ChronusElasticsearch.skip_es_index = false

    ActiveRecord::Base.observers.disable :mentor_request_observer do
      requests[0].mark_accepted!
    end

    student.withdraw_active_requests!
    requests.each(&:reload)
    assert_equal AbstractRequest::Status::ACCEPTED, requests[0].status
    assert_equal AbstractRequest::Status::WITHDRAWN, requests[1].status
    ChronusElasticsearch.skip_es_index = true
  end

  def test_withdraw_active_meeting_requests
    user = users(:mkr_student)
    feb_time = Time.parse("Feb 1, 2050 12:00:00")
    march_time = Time.parse("Mar 1, 2050 12:00:00")
    meeting_request = create_meeting(force_non_time_meeting: true).meeting_request
    meeting_request1 = create_meeting(force_non_time_meeting: true).meeting_request
    meeting_request2 = create_meeting(force_non_time_meeting: true).meeting_request
    meeting_requests = [meeting_request, meeting_request1, meeting_request2]

    create_meeting_proposed_slot(meeting_request_id: meeting_request1.id, start_time: march_time, end_time: march_time + 30.minutes)
    create_meeting_proposed_slot(meeting_request_id: meeting_request1.id, start_time: feb_time, end_time: feb_time + 30.minutes)

    create_meeting_proposed_slot(meeting_request_id: meeting_request2.id, start_time: march_time, end_time: march_time + 30.minutes)
    create_meeting_proposed_slot(meeting_request_id: meeting_request2.id, start_time: march_time, end_time: march_time + 30.minutes)

    User.any_instance.expects(:is_student_meeting_limit_reached?).returns(false)
    User.any_instance.expects(:pending_sent_meeting_requests).never
    user.withdraw_active_meeting_requests!(feb_time)

    User.any_instance.stubs(:is_student_meeting_limit_reached?).returns(true)
    User.any_instance.stubs(:pending_sent_meeting_requests).returns(MeetingRequest.where(id: meeting_requests.collect(&:id)))
    [meeting_request, meeting_request1, meeting_request2].all?(&:active?)
    user.withdraw_active_meeting_requests!(feb_time)

    assert meeting_request.reload.withdrawn?
    assert meeting_request1.reload.withdrawn?
    assert meeting_request2.reload.active?
  end

  def test_remove_drafted_connections_for_role_names
    user = users(:f_mentor_student)
    user.groups.destroy_all
    g0 = create_group(:program => programs(:albers),
     :mentors => [user],
     :students => [users(:f_student)],
     :status => Group::Status::ACTIVE,
     :creator_id => users(:f_admin).id)
    g1 = create_group(:program => programs(:albers),
     :mentors => [user],
     :students => [users(:student_1)],
     :status => Group::Status::DRAFTED,
     :creator_id => users(:f_admin).id)
    g2 = create_group(:program => programs(:albers),
     :mentors => [users(:f_mentor)],
     :students => [user],
     :status => Group::Status::DRAFTED,
     :creator_id => users(:f_admin).id)
    assert_no_difference 'Group.count' do
      user.remove_drafted_connections_for_role_names([])
    end
    assert_difference 'Group.count', -1 do
      user.remove_drafted_connections_for_role_names([RoleConstants::MENTOR_NAME])
    end
    assert g2.reload.present?
    assert_difference 'Group.count', -1 do
      user.remove_drafted_connections_for_role_names([RoleConstants::STUDENT_NAME])
    end
    g3 = create_group(:program => programs(:albers),
     :mentors => [user],
     :students => [users(:student_1)],
     :status => Group::Status::DRAFTED,
     :creator_id => users(:f_admin).id)
    g4 = create_group(:program => programs(:albers),
     :mentors => [users(:f_mentor)],
     :students => [user],
     :status => Group::Status::DRAFTED,
     :creator_id => users(:f_admin).id)
    assert_difference 'Group.count', -2 do
      user.remove_drafted_connections_for_role_names([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    end
    assert g0.reload.present?
  end

  def test_remove_events_rsvp
    user = users(:f_mentor_student)
    assert_difference "EventInvite.count", 2 do
      assert_difference "RecentActivity.count", 2 do
        program_events(:birthday_party).event_invites.create!(user: user, status: EventInvite::Status::YES)
        @ror_mentor_invite = program_events(:ror_meetup).event_invites.create!(user: user, status: EventInvite::Status::NO)
      end
    end
    assert_difference "EventInvite.count", -1 do
      assert_difference "RecentActivity.count", -1 do
        user.remove_events_rsvp([program_events(:birthday_party)])
      end
    end
    assert @ror_mentor_invite.reload.present?
    assert_difference "EventInvite.count", 1 do
      assert_difference "RecentActivity.count", 1 do
        program_events(:birthday_party).event_invites.create!(user: user, status: EventInvite::Status::YES)
      end
    end
    assert_difference "EventInvite.count", -2 do
      assert_difference "RecentActivity.count", -2 do
        user.remove_events_rsvp([program_events(:birthday_party), program_events(:ror_meetup)])
      end
    end
  end

  def test_create_user_demotion_ra
    user = users(:f_mentor)
    some_text = "some text"
    user.state_changer = users(:f_admin)
    user.save!
    assert_difference "RecentActivity.count", 1 do
      user.create_user_demotion_ra(some_text)
    end
    ra = RecentActivity.last
    assert_equal [programs(:albers)], ra.programs
    assert_equal users(:f_admin).member, ra.member
    assert_equal user, ra.ref_obj
    assert_equal some_text, ra.message
    assert_equal RecentActivityConstants::Type::USER_DEMOTION, ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, ra.target
  end

  def test_unsubscribe_from_forums
    user = users(:f_mentor_student)
    assert_difference 'Subscription.count', 3 do
      Subscription.create!(ref_obj: forums(:forums_1), user: user)
      Subscription.create!(ref_obj: forums(:forums_2), user: user)
      Subscription.create!(ref_obj: forums(:forums_3), user: user)
    end
    assert_equal 3, user.subscriptions.size
    assert_difference 'Subscription.count', -2 do
      user.unsubscribe_from_forums([forums(:forums_1).id, forums(:forums_2).id])
    end
    assert_equal 1, user.subscriptions.size
    assert_false user.subscriptions.collect(&:ref_obj).include?(forums(:forums_1).id)
    assert_false user.subscriptions.collect(&:ref_obj).include?(forums(:forums_2).id)
  end

  def test_unsubscribe_from_topics
    topic1 = create_topic(:title => "title1", :forum => forums(:forums_1), :user => users(:f_admin))
    topic2 = create_topic(:title => "title2", :forum => forums(:forums_1), :user => users(:f_admin))
    topic3 = create_topic(:title => "title3", :forum => forums(:forums_1), :user => users(:f_admin))
    user = users(:f_mentor_student)
    assert_difference 'Subscription.count', 3 do
      Subscription.create!(ref_obj: topic1, user: user)
      Subscription.create!(ref_obj: topic2, user: user)
      Subscription.create!(ref_obj: topic3, user: user)
    end
    assert_equal 3, user.subscriptions.size
    assert_difference 'Subscription.count', -2 do
      user.unsubscribe_from_topics([topic1.id, topic2.id])
    end
    assert_equal 1, user.subscriptions.size
    assert_false user.subscriptions.collect(&:ref_obj).include?(topic1.id)
    assert_false user.subscriptions.collect(&:ref_obj).include?(topic2.id)
  end

  def test_state_changer_admin_role_removed
    user = users(:f_mentor)
    original_admin = users(:f_admin)
    admin = users(:ram)

    assert_nothing_raised do
      user.state_changer = original_admin
      user.save!
    end

    # Add mentor role and Remove admin's role
    original_admin.promote_to_role!(RoleConstants::MENTOR_NAME, admin)
    original_admin.demote_from_role!(RoleConstants::ADMIN_NAME, admin)

    assert_nothing_raised do
      user.max_connections_limit = 50
      user.save!
    end

    # Add some other admin as state changer
    assert_nothing_raised do
      user.state_changer = admin
      user.save!
    end

    original_admin.reload
    assert_raise ActiveRecord::RecordInvalid, "Validation failed: State changer does not have the privilege to perform the action" do
      user.state_changer = original_admin
      user.save!
    end
  end

  def test_meeting_request_associations
    MeetingRequest.destroy_all
    student = users(:mkr_student)
    mentor = users(:f_mentor)

    assert_equal 0, student.sent_meeting_requests.size
    assert_equal 0, student.received_meeting_requests.size
    assert_equal 0, mentor.sent_meeting_requests.size
    assert_equal 0, mentor.received_meeting_requests.size

    create_meeting(force_non_time_meeting: true)
    assert_equal 1, student.reload.sent_meeting_requests.size
    assert_equal 0, student.received_meeting_requests.size
    assert_equal 0, mentor.reload.sent_meeting_requests.size
    assert_equal 1, mentor.received_meeting_requests.size
  end

  def test_user_search_activity_association
    user = users(:mkr_student)
    user_search_activities = [user_search_activities(:user_search_activity_1), user_search_activities(:user_search_activity_3)]
    assert_equal_unordered user_search_activities, user.user_search_activities
    user = create_user
    user_search_activity = create_user_search_activity(user: user, program: user.program)
    assert_equal [user_search_activity], user.user_search_activities
    assert_difference "UserSearchActivity.count", -1 do
      assert_difference "User.count", -1 do
        user.destroy
      end
    end
  end

  def test_active_groups
    student = users(:mkr_student)
    assert_equal student.active_groups.size, student.groups.active.size
    group = student.active_groups.first
    group.update_attribute :status, Group::Status::DRAFTED
    assert_equal student.active_groups.size, student.groups.active.size
  end

  def test_pending
    pending_users = groups(:mygroup).members.where(state: User::Status::PENDING).size
    assert_equal 0, pending_users

    users(:mkr_student).update_attribute :state, User::Status::PENDING
    pending_users = groups(:mygroup).members.where(state: User::Status::PENDING).size
    assert_equal 1, pending_users

    size = User.where(state: User::Status::PENDING).size
    User.where(state: User::Status::PENDING).first.update_attribute :state, User::Status::ACTIVE
    assert_equal size-1, User.where(state: User::Status::PENDING).size
  end

  def test_sorted_by_answer_for_file_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = profile_questions(:mentor_file_upload_q)

    f_admin.save_answer!(question, fixture_file_upload(File.join('files', 'test_file.css')))
    f_mentor.save_answer!(question, fixture_file_upload(File.join('files', 'test_file.csv')))
    f_student.save_answer!(question, fixture_file_upload(File.join('files', 'test_email_source.eml')))

    scope = program.users.where(id: [f_admin.id, f_mentor.id, f_student.id])

    assert_equal [f_student.id, f_admin.id, f_mentor.id], User.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor.id, f_admin.id, f_student.id], User.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_date_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_mentor_student = users(:f_mentor_student)

    question = profile_questions(:date_question)

    f_admin.save_answer!(question, '12 July, 2018')
    f_mentor.save_answer!(question, '12 June, 2019')
    f_student.save_answer!(question, '13 December, 1956')
    f_mentor_student.save_answer!(question, '')

    scope = program.users.where(id: [f_admin.id, f_mentor.id, f_student.id, f_mentor_student.id])

    assert_equal [f_mentor_student.id, f_student.id, f_admin.id, f_mentor.id], User.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor.id, f_admin.id, f_student.id, f_mentor_student.id], User.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_work_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = profile_questions(:profile_questions_7)

    default_education_options = {
      job_title: 'A',
      start_year: 1990,
      end_year: 1995,
      company: 'B'
    }

    create_experience_answers(f_admin, question, [
      default_education_options.merge(job_title: 'Bu', end_year:2001)
    ])
    create_experience_answers(f_mentor, question, [
      default_education_options.merge(job_title: 'A', end_year:2001),
      default_education_options.merge(job_title: 'Bz', end_year:2002)
    ])
    create_experience_answers(f_student, question, [
      default_education_options.merge(job_title: 'ba', end_year:2001)
    ])

    scope = program.users.where(id: [f_admin.id, f_mentor.id, f_student.id])

    assert_equal [f_student.id, f_admin.id, f_mentor.id], User.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor.id, f_admin.id, f_student.id], User.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_education_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = profile_questions(:profile_questions_6)

    default_education_options = {
      school_name: 'A',
      degree: 'A',
      major: 'Mech',
      graduation_year: 2010
    }

    create_education_answers(f_admin, question, [
      default_education_options.merge(school_name: 'bu', degree: 'A')
    ])
    create_education_answers(f_mentor, question, [
      default_education_options.merge(school_name: 'A', degree: 'A', graduation_year: 2005),
      default_education_options.merge(school_name: 'bz', degree: 'B')
    ])
    create_education_answers(f_student, question, [
      default_education_options.merge(school_name: 'Ba', degree: 'B')
    ])

    scope = program.users.where(id: [f_admin.id, f_mentor.id, f_student.id])

    assert_equal [f_student.id, f_admin.id, f_mentor.id], User.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor.id, f_admin.id, f_student.id], User.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_publication_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = create_question(:question_type => ProfileQuestion::Type::PUBLICATION, :question_text => "Publication", :organization => programs(:org_primary))

    default_publication_options = {
      title: 'A',
      authors: 'A',
      publisher: 'Mech',
      year: 2010,
      month: 1,
      day: 1
    }

    create_publication_answers(f_admin, question, [
      default_publication_options.merge(title: 'bu', authors: 'A')
    ])
    create_publication_answers(f_mentor, question, [
      default_publication_options.merge(title: 'A', authors: 'A', year: 2005),
      default_publication_options.merge(title: 'bz', authors: 'B')
    ])
    create_publication_answers(f_student, question, [
      default_publication_options.merge(title: 'Ba', authors: 'B')
    ])

    scope = program.users.where(id: [f_admin.id, f_mentor.id, f_student.id])

    assert_equal [f_student.id, f_admin.id, f_mentor.id], User.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor.id, f_admin.id, f_student.id], User.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_manager_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    f_mentor.member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    question = programs(:org_primary).profile_questions.manager_questions.first

    default_manager_options = {
      first_name: 'A',
      last_name: 'B',
      email: 'cemail@example.com'
    }

    create_manager(f_admin, question, default_manager_options)
    create_manager(f_mentor, question, default_manager_options.merge(:first_name => 'A', :last_name => 'b', :email => 'aemail@example.com'))
    create_manager(f_student, question, default_manager_options.merge(:first_name => 'b', :last_name => 'a'))

    scope = program.users.where(id: [f_admin.id, f_mentor.id, f_student.id])

    assert_equal [f_mentor.id, f_admin.id, f_student.id], User.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_student.id, f_admin.id, f_mentor.id], User.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_text_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = profile_questions(:profile_questions_4)

    f_admin.save_answer!(question, 'Bu')
    f_mentor.save_answer!(question, 'Bz')
    f_student.save_answer!(question, 'ba')

    scope = program.users.where(id: [f_admin.id, f_mentor.id, f_student.id])

    assert_equal [f_student.id, f_admin.id, f_mentor.id], User.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor.id, f_admin.id, f_student.id], User.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_has_many_job_logs
    user = users(:f_mentor)
    assert_difference "Announcement.count" do
      create_job_log(user: user)
    end

    assert_difference "JobLog.count", -(user.job_logs.count) do
      assert_difference "User.count", -1 do
        user.destroy
      end
    end
  end

  def test_student_document_available
    assert_false users(:f_mentor).student_document_available?
    assert users(:f_student).student_document_available?
    assert_false users(:f_admin).student_document_available?
    assert users(:f_mentor_student).student_document_available?
  end

  def test_can_manage_admin_role_for
    current_user = users(:f_mentor)
    user = users(:f_student)
    program = programs(:albers)
    #current_user can not manage admins
    assert_equal false, current_user.can_manage_admins?
    assert_equal false, current_user.can_manage_admin_role_for(user, program)

    #current_user can manage admins and user is not an org_admin or program_owner
    current_user = users(:f_admin)
    assert current_user.can_manage_admin_role_for(user, program)

    #Lets make user to be the owner of the program
    program.owner = user
    program.save
    assert_equal false, current_user.can_manage_admin_role_for(user, program)
    #current_user can manage admins and user is an org_admin
    user = users(:f_admin)
    assert_equal false, current_user.can_manage_admin_role_for(user, program)

    # Should allow remove admins for standalone program
    assert current_user.can_manage_admin_role_for(user, programs(:foster))
  end

  def test_student_cache_normalized
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    reset_cache(users(:f_student))
    reset_cache(users(:f_mentor_student))
    active_or_pending_mentor_ids = programs(:albers).mentor_users.pluck(:id)
    assert_equal_unordered [], users(:f_admin).student_cache_normalized.keys
    assert_equal_unordered [], users(:f_mentor).student_cache_normalized.keys

    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.8)
    student_cache = users(:f_student).student_cache_normalized
    assert_equal_unordered active_or_pending_mentor_ids, student_cache.keys
    scores = student_cache.values
    assert_equal 10, scores.min
    assert_equal 90, scores.max
    reset_cache(users(:f_student))

    student_cache = users(:f_mentor_student).student_cache_normalized
    assert_equal_unordered active_or_pending_mentor_ids, student_cache.keys
    scores = student_cache.values
    assert_equal 0, scores.min
    assert_equal 90, scores.max
  end

  def test_student_cache_normalized_for_admin
    reset_cache(users(:f_student))
    reset_cache(users(:f_mentor_student))
    active_or_pending_mentor_ids = programs(:albers).mentor_users.pluck(:id)
    assert_equal_unordered [], users(:f_admin).student_cache_normalized(true).keys
    assert_equal_unordered [], users(:f_mentor).student_cache_normalized(true).keys

    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.8)
    student_cache = users(:f_student).student_cache_normalized(true)
    assert_equal_unordered active_or_pending_mentor_ids, student_cache.keys
    scores = student_cache.values
    assert_equal 90, scores.min
    assert_equal 90, scores.max
    reset_cache(users(:f_student))

    student_cache = users(:f_mentor_student).student_cache_normalized(true)
    assert_equal_unordered active_or_pending_mentor_ids, student_cache.keys
    scores = student_cache.values
    assert_equal 0, scores.min
    assert_equal 90, scores.max
  end

  def test_student_cache_normalized_for_ignored_users
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    student_cache = users(:f_student).student_cache_normalized
    active_or_pending_mentor_ids = programs(:albers).mentor_users.pluck(:id)
    assert_equal_unordered active_or_pending_mentor_ids, student_cache.keys
    assert_equal 0, student_cache[users(:f_mentor).id]
    assert_equal 0, student_cache[users(:ram).id]

    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(false)
    student_cache = users(:f_student).student_cache_normalized
    active_or_pending_mentor_ids = programs(:albers).mentor_users.pluck(:id)
    assert_equal_unordered active_or_pending_mentor_ids, student_cache.keys
    assert_not_equal 0, student_cache[users(:f_mentor).id]
    assert_not_equal 0, student_cache[users(:ram).id]
  end

  def test_mark_zero_for_ignored_mentors
    user = users(:f_student)
    results = {6=>2, 3=>1, 5=>2}
    for_admin = true
    assert_equal_hash(results, user.mark_zero_for_ignored_mentors(results, for_admin))

    results = {6=>2, 3=>1, 5=>2}
    for_admin = false
    assert_equal_hash({6=>0, 3=>0, 5=>2}, user.mark_zero_for_ignored_mentors(results, for_admin))
  end

  def test_send_promotion_notification_mail
    user = users(:f_mentor)
    assert_no_emails do
      user.send_promotion_notification_mail(["student"], users(:f_admin), "Just Like That", true)
    end

    assert_emails do
      user.send_promotion_notification_mail(["student"], users(:f_admin), "Just Like That", false)
    end

    assert_no_emails do
      users(:f_admin).send_promotion_notification_mail(["student"], users(:f_admin), "Just Like That", false)
    end
  end

  def test_send_promotion_notification_mail_with_job_uuid
    user = users(:f_mentor)
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        user.send_promotion_notification_mail(["student"], users(:f_admin), "Just Like That", true, "15")
      end
    end

    assert_emails do
      assert_difference "JobLog.count" do
        user.send_promotion_notification_mail(["student"], users(:f_admin), "Just Like That", false, "15")
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        user.send_promotion_notification_mail(["student"], users(:f_admin), "Just Like That", false, "15")
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        users(:f_admin).send_promotion_notification_mail(["student"], users(:f_admin), "Just Like That", false, "15")
      end
    end
  end

  def test_get_priority_role
    program = programs(:albers)
    user = users(:f_admin)
    assert_equal user.get_priority_role, "admin"
    user = users(:f_student)
    assert_equal user.get_priority_role, "student"
    user = users(:f_mentor)
    assert_equal user.get_priority_role, "mentor"
    user = users(:f_user)
    assert_equal user.get_priority_role, "user"
  end

  def test_get_profile_questions_ratio_for_user_hash
    program = programs(:albers)
    opts = {default: false, skype: program.organization.skype_enabled?, dont_include_section: true}
    mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME, opts)
    student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME, opts)
    user = users(:f_mentor)
    max_score = ProfileCompletion::Score::PROFILE
    user_hash = {
      'id' => user.id,
      'member_id' => user.member_id,
    }
    profile_answers_hash = {
      :editable_by_user_answers => {user.member_id => user.member.profile_answers.group_by(&:profile_question_id)},
      :all_answers => {}
    }
    options = {
      :user => user,
      :edit => true,
      :users_pictures => {},
      :users_role_names => {
        user.id => user.role_names
      }
    }
    with_wrong_questions = User.get_profile_questions_ratio_for_user_hash(user_hash, false,
      options.merge(:questions => {:editable_by_user => { RoleConstants::MENTOR_NAME => student_questions, RoleConstants::STUDENT_NAME => mentor_questions }}),
      profile_answers_hash).first
    with_correct_questtions = User.get_profile_questions_ratio_for_user_hash(user_hash, false,
      options.merge(:questions => {:editable_by_user => { RoleConstants::MENTOR_NAME => mentor_questions, RoleConstants::STUDENT_NAME => student_questions }}),
      profile_answers_hash).first
    without_questions = User.get_profile_questions_ratio_for_user_hash(user_hash, false,
      options.merge(:questions => {}), profile_answers_hash).first

    assert_equal 5, (max_score * with_wrong_questions).round
    assert_equal 44, (max_score * with_correct_questtions).round
    assert_equal 0, (max_score * without_questions).round

    admin = users(:f_admin) #doesnt matter what questions i send it will re calculate them
    admin_hash = {
      'id' => admin.id,
      'member_id' => admin.member_id
    }
    profile_answers_hash = {
      :all_answers => { admin.member_id => admin.member.profile_answers.group_by(&:profile_question_id)},
      :editable_by_user_answers => {}
    }
    options = {
      :user => admin,
      :edit => true,
      :users_pictures => {},
      :users_role_names => {
        admin.id => admin.role_names
      }
    }
    admin_score_with_wrong_questions = User.get_profile_questions_ratio_for_user_hash(admin_hash, false,
      options.merge(:questions => { :all => { RoleConstants::MENTOR_NAME => student_questions, RoleConstants::STUDENT_NAME => mentor_questions }}),
      profile_answers_hash).first
    admin_score_with_correct_questions = User.get_profile_questions_ratio_for_user_hash(admin_hash, false,
      options.merge(:questions => { :all => { RoleConstants::MENTOR_NAME => mentor_questions, RoleConstants::STUDENT_NAME => student_questions }}),
      profile_answers_hash).first
    admin_score_without_questions = User.get_profile_questions_ratio_for_user_hash(admin_hash, false,
      options.merge(:questions => {}), profile_answers_hash).first

    assert_equal admin_score_with_wrong_questions, admin_score_with_correct_questions
    assert_equal admin_score_with_wrong_questions, admin_score_without_questions
    assert_equal 0, (max_score*admin_score_with_wrong_questions).round
  end

  def test_get_profile_questions_ratio_for_user_and_admin
    program = programs(:albers)
    opts = {:default => false, :skype => program.organization.skype_enabled?, :dont_include_section => true}
    mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME, opts)
    student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME, opts)
    user = users(:f_mentor)
    max_score = ProfileCompletion::Score::PROFILE
    with_wrong_questions = user.get_profile_questions_ratio_for_user(false, {:user => user, :edit => true, :questions => {RoleConstants::MENTOR_NAME => student_questions,
                                                                                                    RoleConstants::STUDENT_NAME => mentor_questions}}).first
    with_correct_questtions = user.get_profile_questions_ratio_for_user(false, {:user => user, :edit => true, :questions => {RoleConstants::MENTOR_NAME => mentor_questions,
                                                                                                    RoleConstants::STUDENT_NAME => student_questions}}).first
    without_questions = user.get_profile_questions_ratio_for_user(false, {:user => user, :edit => true}).first

    assert_equal 5, (max_score*with_wrong_questions).round
    assert_equal 44, (max_score*with_correct_questtions).round
    assert_equal 44, (max_score*without_questions).round

    admin = users(:f_admin) #doesnt matter what questions i send it will re calculate them
    admin_score_with_wrong_questions = admin.get_profile_questions_ratio_for_user(false, {:user => user, :edit => true, :questions => {RoleConstants::MENTOR_NAME => student_questions,
                                                                                                    RoleConstants::STUDENT_NAME => mentor_questions}}).first
    admin_score_with_correct_questions = admin.get_profile_questions_ratio_for_user(false, {:user => user, :edit => true, :questions => {RoleConstants::MENTOR_NAME => mentor_questions,
                                                                                                    RoleConstants::STUDENT_NAME => student_questions}}).first
    admin_score_without_questions = admin.get_profile_questions_ratio_for_user(false, {:user => user, :edit => true}).first

    assert_equal admin_score_with_wrong_questions, admin_score_with_correct_questions
    assert_equal admin_score_with_wrong_questions, admin_score_without_questions
    assert_equal 0, (max_score*admin_score_with_wrong_questions).round
  end

  def test_profile_score_with_wrong_options
    program = programs(:albers)
    opts = {:default => false, :skype => program.organization.skype_enabled?, :dont_include_section => true}
    mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME, opts)
    student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME, opts)

    assert_equal 20, users(:f_mentor).profile_score(:questions => {RoleConstants::MENTOR_NAME => student_questions, RoleConstants::STUDENT_NAME => mentor_questions}).sum
    assert_equal 15, users(:f_student).profile_score(:questions => {RoleConstants::MENTOR_NAME => student_questions, RoleConstants::STUDENT_NAME => mentor_questions}).sum
  end

  def test_profile_score_with_correct_options
    program = programs(:albers)
    opts = {:default => false, :skype => program.organization.skype_enabled?, :dont_include_section => true}
    mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME, opts)
    student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME, opts)

    assert_equal 59, users(:f_mentor).profile_score(:questions => {RoleConstants::MENTOR_NAME => mentor_questions, RoleConstants::STUDENT_NAME => student_questions}).sum
    assert_equal 15, users(:f_student).profile_score(:questions => {RoleConstants::MENTOR_NAME => mentor_questions, RoleConstants::STUDENT_NAME => student_questions}).sum
  end

  def test_profile_score_without_options
    assert_equal 59, users(:f_mentor).profile_score().sum
    assert_equal 15, users(:f_student).profile_score().sum
  end

  def test_get_visible_favorites
    student = users(:f_student)
    assert_equal 0,student.get_visible_favorites.count

    options = {:favorite => users(:f_mentor)}
    create_favorite(options)
    options = {:favorite => users(:moderated_mentor)}
    create_favorite(options)

    users(:f_mentor).update_attribute(:state, User::Status::PENDING)

    fav_mentors = student.reload.get_visible_favorites
    assert_equal 1, fav_mentors.count
    assert_equal users(:moderated_mentor), fav_mentors.first.favorite

    student.add_role(RoleConstants::ADMIN_NAME)
    fav_mentors = student.reload.get_visible_favorites
    assert_equal 2, fav_mentors.count
  end

  def test_new_user_for_notif_setting
    prog = programs(:albers)
    member_1 = create_member(:first_name => "student", :last_name => "Test", :email => "student_1@email.com")
    member_2 = create_member(:first_name => "student", :last_name => "Test", :email => "student_2@email.com")

    uobj = User.new_from_params(:member => member_1, :program => prog, :created_by => users(:f_admin), :role_names => [RoleConstants::STUDENT_NAME])
    uobj.save!
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, uobj.program_notification_setting)

    prog.notification_setting.messages_notification = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    prog.notification_setting.save!
    uobj_2 = User.new_from_params(:member => member_2, :program => prog, :created_by => users(:f_admin), :role_names => [RoleConstants::STUDENT_NAME])
    uobj_2.save!
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, uobj_2.program_notification_setting)
  end

  def test_can_apply_for_join_group
    group_user = users(:pbe_student_0)
    new_user = users(:pbe_student_1)
    group = groups(:group_pbe_0)

    assert_false group_user.can_apply_for_join?(group)
    assert new_user.can_apply_for_join?(group)

    group.update_column(:status, Group::Status::ACTIVE)
    assert new_user.can_apply_for_join?(group)

    group.update_column(:status, Group::Status::INACTIVE)
    assert new_user.can_apply_for_join?(group)

    group.update_column(:status, Group::Status::CLOSED)
    assert_false new_user.can_apply_for_join?(group)
    group.update_column(:status, Group::Status::ACTIVE)
    new_user.roles.update_all(max_connections_limit: 0)
    assert_false new_user.can_apply_for_join?(group)
  end

  def test_has_pending_request
    user_1 = users(:pbe_student_0)
    user_2 = users(:pbe_student_1)
    group = groups(:group_pbe_0)
    assert_false user_1.has_pending_request?(group)
    assert_false user_2.has_pending_request?(group)
    ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: user_2.id, group_id: group.id)
    assert user_2.has_pending_request?(group)
  end

  def test_can_change_connection_limit
    program = programs(:albers)
    user = program.users.first
    program.update_attributes(:default_max_connections_limit => 10)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::NONE)
    assert_false user.can_change_connection_limit?(9)
    assert_false user.can_change_connection_limit?(10)
    assert_false user.can_change_connection_limit?(11)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::ONLY_DECREASE)
    assert user.reload.can_change_connection_limit?(9)
    assert user.can_change_connection_limit?(10)
    assert_false user.can_change_connection_limit?(11)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::ONLY_INCREASE)
    assert_false user.reload.can_change_connection_limit?(9)
    assert user.can_change_connection_limit?(10)
    assert user.can_change_connection_limit?(11)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::BOTH)
    assert user.reload.can_change_connection_limit?(9)
    assert user.can_change_connection_limit?(10)
    assert user.can_change_connection_limit?(11)
  end

  def test_suspend_users_by_ids
    admin = users(:f_admin)
    student = users(:f_student)
    mentor = users(:robert)
    user_ids = [student.id, mentor.id]

    Matching.expects(:perform_users_delta_index_and_refresh).with(user_ids, student.program_id, {}).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, user_ids).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [student.id]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [mentor.id]).times(get_pending_requests_and_offers_count(mentor) + 3)
    UserObserver.expects(:send_user_suspension_emails).twice
    assert_difference "RecommendationPreference.count", -1 do
      assert_difference "RecentActivity.count", 2 do
        assert_difference "UserStateChange.count", 2 do
          assert_difference "ConnectionMembershipStateChange.count", (mentor.connection_memberships.count + student.connection_memberships.count) do
            assert_equal true, User.suspend_users_by_ids(user_ids, admin, "jus' for test")
          end
        end
      end
    end

    u1_state_change = mentor.state_transitions.last.info_hash
    u2_state_change = student.state_transitions.last.info_hash
    state_change_1 = { "from" => User::Status::ACTIVE, "to" => User::Status::SUSPENDED }
    state_change_2 = { "from" => User::Status::ACTIVE, "to" => User::Status::SUSPENDED }
    assert_equal state_change_1, u1_state_change["state"]
    assert_equal state_change_2, u2_state_change["state"]
    assert_equal u2_state_change["role"]["to"], u2_state_change["role"]["from"]
    assert_equal u1_state_change["role"]["to"], u1_state_change["role"]["from"]

    c1_state_change = ConnectionMembershipStateChange.where(user_id: mentor.id).last.info_hash
    state_change_1 = { "from_state" => User::Status::ACTIVE, "to_state" => User::Status::SUSPENDED }
    assert_equal state_change_1, c1_state_change["user"]
    assert_equal c1_state_change["group"]["from_state"], c1_state_change["group"]["to_state"]

    assert student.reload.suspended?
    assert mentor.reload.suspended?
    assert_equal User::Status::ACTIVE, student.track_reactivation_state
    assert_equal User::Status::ACTIVE, mentor.track_reactivation_state
    assert_equal "jus' for test", student.state_change_reason
    assert_equal "jus' for test", mentor.state_change_reason
    assert_equal admin, student.state_changer
    assert_equal admin, mentor.state_changer
    assert_nil student.global_reactivation_state || mentor.global_reactivation_state
  end

  def test_activate_users_by_ids
    admin = users(:f_admin)
    student = users(:f_student)
    mentor = users(:f_mentor)
    suspend_user(student)
    suspend_user(mentor, track: User::Status::PENDING)
    user_ids = [student.id, mentor.id]
    Matching.expects(:perform_users_delta_index_and_refresh).with(user_ids, admin.program_id, {}).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, user_ids).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [student.id]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [mentor.id]).times(2)

    User.any_instance.stubs(:profile_incomplete_roles).returns([])
    assert_difference "JobLog.count", 2 do
      assert_difference "RecentActivity.count", 2 do
        assert_difference "UserStateChange.count", 2 do
          assert_emails 2 do
            assert_equal true, User.activate_users_by_ids(user_ids, admin)
          end
        end
      end
    end
    emails = ActionMailer::Base.deliveries.last(2)
    assert student.reload.active?
    assert mentor.reload.active?
    assert_nil student.track_reactivation_state || mentor.track_reactivation_state
    assert_not_nil student.activated_at && mentor.activated_at
    assert_equal admin, student.state_changer
    assert_equal admin, mentor.state_changer
    assert_equal_unordered [mentor.email, student.email], emails.collect(&:to).flatten
    assert_equal ["Your account is now reactivated!"], emails.collect(&:subject).uniq
  end

  def test_activate_users_by_ids_with_options
    admin = users(:f_admin)
    student = users(:f_student)
    mentor = users(:f_mentor)
    suspend_user(student)
    suspend_user(mentor, track: User::Status::PENDING)
    user_ids = [student.id, mentor.id]

    Matching.expects(:perform_users_delta_index_and_refresh).never
    User.any_instance.stubs(:can_be_published?).returns(false)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [student.id, mentor.id]).times(1)
    assert_no_difference "JobLog.count" do
      assert_difference "RecentActivity.count", 2 do
        assert_no_difference "UserStateChange.count" do
          assert_no_emails do
            assert_equal true, User.activate_users_by_ids(user_ids, admin, { send_email: false, track_changes: false, skip_matching_index: true })
          end
        end
      end
    end
    assert student.reload.active?
    assert mentor.reload.pending?
    assert_nil student.track_reactivation_state || mentor.track_reactivation_state
    assert_not_nil student.activated_at && mentor.activated_at
    assert_equal admin, student.state_changer
    assert_equal admin, mentor.state_changer
  end

  def test_activate_users_by_ids_ignores_suspended_members
    mentor = users(:f_mentor)
    student = users(:f_student)
    suspend_user(mentor)
    suspend_user(student)
    mentor.member.update_attribute(:state, Member::Status::SUSPENDED)
    user_ids = [mentor.id, student.id]
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [student.id]).times(2)
    Matching.expects(:perform_users_delta_index_and_refresh).with([student.id], student.program_id, {}).once
    assert_difference "JobLog.count", 1 do
      assert_difference "RecentActivity.count", 1 do
        assert_difference "UserStateChange.count", 1 do
          assert_emails 1 do
            assert_equal true, User.activate_users_by_ids(user_ids, users(:f_admin))
          end
        end
      end
    end
    assert mentor.reload.suspended?
    assert student.reload.active?
  end

  def test_match_score_when_match_results_passed
    student = users(:f_student)
    assert_equal 0.0, student.match_score('1', { '1' => 0.0 } )
    assert_nil student.match_score('1', { '2' => 0.0 } )
    assert_nil student.match_score('1', false)
  end

  def test_match_score_when_student_document_available_is_true_and_cache_present
    student = users(:f_student)
    student.expects(:student_document_available?).returns(true)
    student.expects(:student_cache_normalized).returns( { '1' => 0.0 } )
    assert_equal 0.0, student.match_score('1')
  end

  def test_match_score_when_student_document_available_is_true_and_cache_is_not_present
    student = users(:f_student)
    student.expects(:student_document_available?).returns(true)
    student.expects(:student_cache_normalized).returns( { '2' => 0.0 } )
    assert_nil student.match_score('1')
  end

  def test_match_score_when_student_document_available_is_false
    student = users(:f_student)
    student.expects(:student_document_available?).returns(false)
    assert_nil student.match_score('1')
  end

  def test_create_user_withour_connection_limit_permission
    prog = programs(:albers)
    prog.update_attributes(:connection_limit_permission => Program::ConnectionLimit::NONE)
    me = create_member(:first_name => "Sample", :last_name => "Test", :email => "sample@email.com")
    uobj = User.new_from_params(
      :member => me,
      :program => prog.reload,
      :created_by => users(:f_admin),
      :role_names => [RoleConstants::STUDENT_NAME]
    )
    assert uobj.valid?
    uobj.save!
    uobj.add_role(RoleConstants::MENTOR_NAME)
    uobj.max_connections_limit = 5
    assert uobj.valid?
  end

  def test_can_get_mentor_recommendations
    program = programs(:albers)
    mentee = users(:f_student)

    assert users(:f_student).can_get_mentor_recommendations?
    assert_false users(:f_mentor).can_get_mentor_recommendations?

    program.update_attribute(:allow_mentoring_requests, false)
    assert_false mentee.reload.can_get_mentor_recommendations?
    program.update_attribute(:allow_mentoring_requests, true)
    assert mentee.reload.can_get_mentor_recommendations?

    program.update_column(:mentor_request_style, Program::MentorRequestStyle::NONE)
    assert_false mentee.reload.can_get_mentor_recommendations?
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_ADMIN)
    assert_false mentee.reload.can_get_mentor_recommendations?
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    assert mentee.reload.can_get_mentor_recommendations?

    program.update_attribute(:max_connections_for_mentee, mentee.studying_groups.active.count)
    assert_false mentee.reload.can_get_mentor_recommendations?
    program.update_attribute(:max_connections_for_mentee, nil)
    assert mentee.reload.can_get_mentor_recommendations?

    program.update_attribute(:max_pending_requests_for_mentee, mentee.sent_mentor_requests.active.count)
    assert_false mentee.reload.can_get_mentor_recommendations?
    program.update_attribute(:max_pending_requests_for_mentee, nil)
    assert mentee.reload.can_get_mentor_recommendations?

    assert_false program.student_users.select{|u| u.studying_groups.count > 0}[0].can_get_mentor_recommendations?
    assert program.student_users.select{|u| u.studying_groups.count == 0}[0].can_get_mentor_recommendations?

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false mentee.reload.can_get_mentor_recommendations?
  end

  def test_recommended_mentors
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    assert_nil users(:f_mentor).recommended_mentors
    program = programs(:albers)
    mentee = users(:f_student)
    program.mentor_users[5..-1].each{|u| u.destroy}
    program.reload
    mentors = program.mentor_users
    mentor_users_ids = program.mentor_users.map(&:id)
    Matching::Cache::Refresh.perform_users_delta_refresh([mentee.id], program.id)
    mentor_users_ids = program.mentor_users.pluck("users.id") - [users(:robert).id, users(:f_mentor).id]
    assert_equal_unordered mentor_users_ids, mentee.recommended_mentors.map(&:id)
    assert_equal 2, mentee.recommended_mentors(count: 2).size
    assert_equal 0, mentee.recommended_mentors(match_score_cutoff: 95).size

    group_mentor = mentors[0]
    grp = create_group(student: mentee, mentor: group_mentor)
    assert_equal_unordered mentor_users_ids - [group_mentor.id], mentee.reload.recommended_mentors.map(&:id)

    mentor_offered = mentors[1]
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    mentor_offered.sent_mentor_offers.pending.create!(student: mentee, program: program)
    assert_equal_unordered mentor_users_ids - [group_mentor.id, mentor_offered.id], mentee.reload.recommended_mentors.map(&:id)

    mentor_requested = mentors[2]
    mentee.sent_mentor_requests.active.create!(program: program, message: "msg", mentor: mentor_requested)
    assert_equal_unordered mentor_users_ids - [group_mentor.id, mentor_offered.id, mentor_requested.id], mentee.reload.recommended_mentors.map(&:id)
    @reindex_mongodb = true
  end

  def test_get_unconnected_user_widget_content_list
    user = users(:f_mentor)
    User.any_instance.stubs(:unconnected_user_widget_content).returns(["1", "2", "2"])
    User.any_instance.stubs(:append_unconnected_user_widget_new_content_list).with([{object: "1"}, {object: "2"}]).returns(["c"])
    assert_equal ["c"], user.get_unconnected_user_widget_content_list
  end

  def test_unconnected_user_widget_content
    student_user = users(:f_student)
    mentor_user = users(:f_mentor)

    student_role_ids = student_user.role_ids
    mentor_role_ids = mentor_user.role_ids

    Program.any_instance.stubs(:unconnected_user_widget_content).returns([{role_id: student_role_ids.first, object: "a"}, {role_id: nil, object: "b"}, {role_id: mentor_role_ids.first, object: "c"}])

    assert_equal ["a", "b"], student_user.unconnected_user_widget_content
    assert_equal ["b", "c"], mentor_user.unconnected_user_widget_content
  end

  def test_recommended_mentors_for_recommending_only_mentors_opting_for_ongoing_mentoring
    mentee = users(:moderated_student)
    mentee.program.enable_feature("calendar", true)

    #program not considering mentoring mode change
    recommended_mentors = mentee.recommended_mentors
    assert recommended_mentors.include?(users(:f_onetime_mode_mentor))
    assert recommended_mentors.include?(users(:moderated_mentor))

    # program considering mentoring mode change by mentors
    mentee.program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    mentee.program.reload
    recommended_mentors = mentee.recommended_mentors
    assert_false recommended_mentors.include?(users(:f_onetime_mode_mentor))
    assert recommended_mentors.include?(users(:moderated_mentor))
  end

  def test_hide_profile_completion_bar
    mentee = users(:f_student)
    assert_false mentee.hide_profile_completion_bar?
    mentee.hide_profile_completion_bar!
    assert mentee.hide_profile_completion_bar?
  end

  def test_unanswered_questions
    user = users(:f_mentor)
    all_answers = user.member.profile_answers.map(&:profile_question_id)
    all_questions = programs(:albers).profile_questions_for(user.role_names, {:default => false, :skype => programs(:org_primary).skype_enabled?, user: user}).map(&:id)
    assert_equal_unordered all_questions - all_answers, user.unanswered_questions.map(&:id)
  end

  def test_owned_groups
    proposer = users(:f_mentor_pbe)
    assert_equal [], proposer.owned_groups
    program = programs(:pbe)
    group = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    assert_false proposer.is_owner_of?(group)
    group.make_proposer_owner!
    group.reload
    assert_equal [group], proposer.reload.owned_groups
  end

  def test_has_multiple_default_roles_mentor
    mentor = users(:f_mentor)
    assert_false mentor.has_multiple_default_roles?
  end

  def test_has_multiple_default_roles_mentee
    mentee = users(:f_student)
    assert_false mentee.has_multiple_default_roles?
  end

  def test_has_multiple_default_roles_admin
    admin = users(:f_admin)
    assert_false admin.has_multiple_default_roles?
  end

  def test_has_multiple_default_roles_mentor_mentee
    users(:f_mentor).promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    mentor_mentee = users(:f_mentor)
    assert mentor_mentee.has_multiple_default_roles?
  end

  def test_has_multiple_default_roles_admin_mentee
    users(:f_admin).promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    admin_mentee = users(:f_admin)
    assert admin_mentee.has_multiple_default_roles?
  end

  def test_has_multiple_default_roles_admin_mentor
    users(:f_admin).promote_to_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
    admin_mentor = users(:f_admin)
    assert admin_mentor.has_multiple_default_roles?
  end

  def test_last_connection_association
    assert_equal [], users(:f_admin).last_closed_group
    assert_equal [], users(:f_mentor).last_closed_group
    assert_equal [], users(:f_student).last_closed_group
    g1 = users(:f_mentor).groups.first
    g1.terminate!(users(:f_admin), "checking", g1.program.permitted_closure_reasons.first.id)
    g1.members.each do |user|
      assert_equal [g1], user.reload.last_closed_group
    end

    g2 = create_group(:students => [users(:f_student)], :mentors => [users(:f_mentor)], :program => programs(:albers))
    g2.terminate!(users(:f_admin), "checking", g2.program.permitted_closure_reasons.first.id)
    g2.closed_at = 3.days.from_now
    g2.save!
    assert_equal [g2], users(:f_mentor).reload.last_closed_group

    g1.update_attributes(closed_at: 1.week.from_now)
    assert_equal [g1], users(:f_mentor).reload.last_closed_group
  end

  def test_meeting_request_average_reponse_time
    user = MeetingRequest.first.mentor
    responded_meeting_requests = user.received_meeting_requests.accepted + user.received_meeting_requests.rejected
    responded_meeting_requests.each do |request|
      request.update_attributes!(:updated_at => request.created_at + 10.hours)
    end
    assert_equal "10.0", user.meeting_request_average_reponse_time.to_s
  end

  def test_mentor_request_average_reponse_time
    mentor_request = mentor_requests(:mentor_request_0)
    user = mentor_request.mentor
    responded_mentor_request = user.received_mentor_requests.accepted + user.received_mentor_requests.rejected
    responded_mentor_request.each do |request|
      request.update_attributes!(:updated_at => request.created_at + 10.hours)
    end
    assert_equal "10.0", user.mentor_request_average_reponse_time.to_s
  end

  def test_meeting_request_acceptance_rate
    user = MeetingRequest.first.mentor
    user1 = MeetingRequest.last.mentor
    meeting_requests = user.received_meeting_requests
    assert_equal 0, meeting_requests.rejected.count
    assert_equal 4, meeting_requests.accepted.count
    assert_equal "100.0", user.meeting_request_acceptance_rate.to_s
    meeting_requests = user1.received_meeting_requests
    assert_equal 4, meeting_requests.accepted.count
    assert_equal "100.0", user1.meeting_request_acceptance_rate.to_s
  end

  def test_mentor_request_acceptance_rate
    user = mentor_requests(:mentor_request_0).mentor
    mentor_requests = user.received_mentor_requests
    assert_equal 0, mentor_requests.accepted.count
    assert_equal "0.0", user.mentor_request_acceptance_rate.to_s
    mentor_requests.first.mark_accepted!
    assert_equal 4, mentor_requests.rejected.count
    assert_equal "20.0", user.mentor_request_acceptance_rate.to_s
  end

  def test_create_user_and_membership_state_changes
    group = groups(:mygroup)
    user = group.memberships.first.user
    info = {state: {}, role: {}}
    info[:state][:from] = user.state
    info[:state][:to] = User::Status::SUSPENDED
    info[:role][:from] = user.role_ids
    info[:role][:to] = user.role_ids
    membership_role_id = group.memberships.first.role_id
    user_active_role_and_memberships_info = User.get_active_roles_and_membership_info([user.id])[user.id]
    assert_difference 'UserStateChange.count', 1 do
      assert_difference 'ConnectionMembershipStateChange.count', user.connection_memberships.count do
        User.create_user_and_membership_state_changes(user.id, 123456, info, user_active_role_and_memberships_info)
      end
    end
    assert_equal ActiveSupport::HashWithIndifferentAccess.new(info), UserStateChange.last.info_hash

    membership_state_change = user.connection_membership_state_changes.last
    info_hash = membership_state_change.info_hash
    user_state_change = user.state_transitions.last
    user_membership_info_hash = user_state_change.connection_membership_info_hash
    assert user_membership_info_hash[:role][:from_role].include?(membership_role_id)
    assert user_membership_info_hash[:role][:to_role].include?(membership_role_id)
    assert_equal group.status, info_hash[:group][:from_state]
    assert_equal group.status, info_hash[:group][:to_state]
    assert_equal Connection::Membership::Status::ACTIVE, info_hash[:connection_membership][:from_state]
    assert_equal Connection::Membership::Status::ACTIVE, info_hash[:connection_membership][:to_state]
    assert_equal user.state, info_hash[:user][:from_state]
    assert_equal User::Status::SUSPENDED, info_hash[:user][:to_state]
  end

  def test_role_ids_in_active_groups
    user = users(:student_2)
    assert_equal_unordered Group.where("groups.status IN (?)", Group::Status::ACTIVE_CRITERIA).collect(&:memberships).flatten.select{|m| m.user_id == user.id}.collect(&:role_id), user.role_ids_in_active_groups
  end

  def test_destroying_user_destroy_connection_membership_state_change
    g1 = create_group(:mentors => [users(:mentor_4), users(:mentor_3)], :students => [users(:student_4)])
    user = users(:mentor_3)
    user_id = user.id
    assert_not_equal [], ConnectionMembershipStateChange.where(user_id: user_id)
    user.destroy
    assert_equal [], ConnectionMembershipStateChange.where(user_id: user_id)
  end

  def test_track_state_changes
    program = programs(:albers)
    u1 = users(:f_mentor)
    u2 = users(:f_student)
    suspend_user(u1)
    suspend_user(u2)
    mentor_role = program.find_role RoleConstants::MENTOR_NAME
    student_role = program.find_role RoleConstants::STUDENT_NAME

    assert_difference "UserStateChange.count", 2 do
      assert_difference "ConnectionMembershipStateChange.count", (u1.connection_memberships.count + u2.connection_memberships.count) do
        users_groups_info = User.get_active_roles_and_membership_info([u1.id, u2.id])
        User.track_state_changes(Time.now.utc.to_i, [ { "user_id" => u1.id, "role_ids" => "#{mentor_role.id}", "to_state" => User::Status::ACTIVE } ], users_groups_info, { from: User::Status::SUSPENDED } )
        User.track_state_changes(Time.now.utc.to_i, [ { "user_id" => u2.id, "role_ids" => "#{student_role.id}", "to_state" => User::Status::PENDING } ], users_groups_info, { from: User::Status::SUSPENDED } )
      end
    end
    u1_state_change = u1.state_transitions.last.info_hash
    u2_state_change = u2.state_transitions.last.info_hash

    state_change_1 = { "from" => User::Status::SUSPENDED, "to" => User::Status::ACTIVE }
    state_change_2 = { "from" => User::Status::SUSPENDED, "to" => User::Status::PENDING }
    assert_equal state_change_1, u1_state_change["state"]
    assert_equal state_change_2, u2_state_change["state"]

    c1_state_change = ConnectionMembershipStateChange.where(user_id: u1.id).last.info_hash
    state_change_1 = { "from_state" => User::Status::SUSPENDED, "to_state" => User::Status::ACTIVE }
    assert_equal state_change_1, c1_state_change["user"]
    assert_equal c1_state_change["group"]["from_state"], c1_state_change["group"]["to_state"]
  end

  def test_track_state_changes_for_bulk_role_addition
    u1 = users(:f_mentor)
    u2 = users(:f_student)
    u1.promote_to_role!([RoleConstants::STUDENT_NAME], users(:f_admin))
    suspend_user(u2)
    old_state_role_mappings = [ { "user_id"=> u1.id, "state"=> u1.state, "role_ids"=> u1.role_ids.join(",") }, { "user_id"=> u2.id, "state"=> u2.reload.state, "role_ids"=> u2.role_ids.join(",") } ]

    u1.promote_to_role!([RoleConstants::InviteRolePermission::RoleName::USER_NAME], users(:f_admin))
    u2.promote_to_role!([RoleConstants::InviteRolePermission::RoleName::USER_NAME], users(:f_admin))
    u2.update_attribute(:state, User::Status::ACTIVE)
    new_state_role_mappings = [ { "user_id"=> u1.id, "state"=> u1.state, "role_ids"=> u1.role_ids.join(",") }, { "user_id"=> u2.id, "state"=> u2.reload.state, "role_ids"=> u2.role_ids.join(",") } ]

    assert_difference 'UserStateChange.count', 2 do
      assert_difference 'ConnectionMembershipStateChange.count', (u1.connection_memberships.count + u2.connection_memberships.count) do
        User.track_state_changes_for_bulk_role_addition(Time.now.utc.to_i, old_state_role_mappings, new_state_role_mappings, User.get_active_roles_and_membership_info([u1.id, u2.id]))
      end
    end

    u1_state_change = u1.state_transitions.last.info_hash
    u2_state_change = u2.state_transitions.last.info_hash

    mentor_role = u1.program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = u1.program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    user_role = u1.program.roles.find_by(name: RoleConstants::InviteRolePermission::RoleName::USER_NAME)

    state_change_1 = {"from"=>User::Status::ACTIVE, "to"=>User::Status::ACTIVE}
    state_change_2 = {"from"=>User::Status::SUSPENDED, "to"=>User::Status::ACTIVE}

    u1_state_change = u1.state_transitions.last.info_hash
    u2_state_change = u2.state_transitions.last.info_hash

    assert_equal state_change_1, u1_state_change["state"]
    assert_equal_unordered [mentee_role.id, mentor_role.id], u1_state_change["role"]["from"]
    assert_equal_unordered [mentee_role.id, mentor_role.id, user_role.id], u1_state_change["role"]["to"]

    assert_equal_unordered [mentee_role.id], u2_state_change["role"]["from"]
    assert_equal_unordered [mentee_role.id, user_role.id], u2_state_change["role"]["to"]

    c1_state_change = ConnectionMembershipStateChange.where(user_id: u1.id).last.info_hash

    state_change_1 = {"from_state"=>User::Status::ACTIVE, "to_state"=>User::Status::ACTIVE}

    assert_equal state_change_1, c1_state_change["user"]
    assert_equal c1_state_change["group"]["from_state"], c1_state_change["group"]["to_state"]
  end

  def test_opting_for_ongoing_mentoring
    program = programs(:albers)
    mentor = users(:f_mentor)

    #enabling one time mentoring
    program.enable_feature("calendar", true)

    #making program allow mentors to choose mentoring mode
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    mentor.program.reload
    assert mentor.opting_for_ongoing_mentoring?

    #changing mentoring mode of mentor to onetime
    mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)

    assert_false mentor.opting_for_ongoing_mentoring?

    #making program disallow mentors to choose mentoring mode
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::NON_EDITABLE)
    mentor.program.reload
    assert_false program.consider_mentoring_mode?
    assert mentor.opting_for_ongoing_mentoring?

    program2 = programs(:ceg)
    program2.stubs(:consider_mentoring_mode?).returns(true)
    assert_false mentor.opting_for_ongoing_mentoring?(program2)
  end

  def test_opting_for_one_time_mentoring
    program = programs(:albers)
    mentor = users(:f_mentor)

    #enabling one time mentoring
    program.enable_feature("calendar", true)

    #making program allow mentors to choose mentoring mode
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    mentor.program.reload

    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, mentor.mentoring_mode
    assert mentor.opting_for_one_time_mentoring?

    #changing mentoring mode of mentor to onetime
    mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    assert mentor.opting_for_one_time_mentoring?

    mentor.update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    assert_false mentor.opting_for_one_time_mentoring?

    #making program disallow mentors to choose mentoring mode
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::NON_EDITABLE)
    mentor.program.reload
    assert_false program.consider_mentoring_mode?
    assert mentor.opting_for_one_time_mentoring?

    program2 = programs(:ceg)
    program2.stubs(:consider_mentoring_mode?).returns(true)
    assert_false mentor.opting_for_one_time_mentoring?(program2)
  end

  def test_can_offer_mentoring_to
    #setup
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    #When receiver can't receive request
    assert_false users(:f_mentor).can_offer_mentoring_to?(users(:robert))

    #When sender can't offer mentoring
    assert_false users(:rahim).can_offer_mentoring_to?(users(:robert))

    #When sender can't mentor
    users(:f_mentor).update_attribute(:max_connections_limit, 1)
    assert_false users(:f_mentor).can_offer_mentoring_to?(users(:f_student))

    #When sender and receiver already connected
    assert_false users(:f_mentor).can_offer_mentoring_to?(users(:mkr_student))

    #When receiver has reached limit as mentee
    programs(:albers).update_attribute(:max_connections_for_mentee, 1)
    assert_false users(:robert).can_offer_mentoring_to?(users(:mkr_student))

    #Everything Fine
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    programs(:albers).update_attribute(:max_connections_for_mentee, nil)
    assert users(:f_mentor).can_offer_mentoring_to?(users(:f_student))
  end

  def test_feedback_responses_given_association
    program = programs(:albers)
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first
    feedback_form = program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first

    response = Feedback::Response.create_from_answers(mentee, mentor, 4, group, feedback_form, {})

    assert mentee.feedback_responses_given.include?(response)

    #destroy mentee
    assert_equal response.rating_giver, mentee
    mentee.destroy
    response.reload
    assert_false response.rating_giver.present?
  end

  def test_feedback_responses_received_association
    program = programs(:albers)
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first
    feedback_form = program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first

    response = Feedback::Response.create_from_answers(mentee, mentor, 4, group, feedback_form, {})

    assert mentor.feedback_responses_received.include?(response)

    #destroy mentee
    assert_equal response.rating_receiver, mentor
    assert feedback_form.responses.include?(response)
    mentor.destroy

    # testing for dependent destroy
    feedback_form.reload
    assert_false feedback_form.responses.include?(response)
  end

  def test_user_stat_association
    user = users(:f_mentor)
    user_stat = UserStat.create!(:user => user, :rating_count => 10, :average_rating => 4)
    assert_equal 1, UserStat.count
    assert_equal user.user_stat, user_stat

    user.destroy
    assert_equal 0, UserStat.count
  end

  def test_can_update_goal_progress
    user = users(:f_mentor_student)
    mentor_user = users(:f_mentor)
    user.can_update_goal_progress?(Group.first)
    group = create_group(:mentors => [mentor_user], :students => [user], :program => programs(:albers))
    user.can_update_goal_progress?(group)
    mentor_user.can_update_goal_progress?(group)
  end

  def test_can_view_role
    user = users(:f_mentor_student)
    assert user.can_view_role?(RoleConstants::STUDENT_NAME)
    assert user.can_view_role?(RoleConstants::MENTOR_NAME)

    assert_false Permission.exists_with_name?("view_actors")
    assert_raise AuthorizationManager::NoSuchPermissionException do
      user.can_view_role?("actor")
    end
  end

  def test_can_view_role_for_admin
    user = users(:f_admin)
    assert user.can_view_role?(RoleConstants::STUDENT_NAME)
    assert user.can_view_role?(RoleConstants::MENTOR_NAME)

    moderator_role = create_role(:name => 'moderator')
    assert_false user.send("can_view_#{moderator_role.name.pluralize}?")
    assert user.can_view_role?(moderator_role.name)
  end

  def test_visible_non_admin_roles
    program = programs(:albers)
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)
    admin_role = program.find_role RoleConstants::ADMIN_NAME
    mentor_role = program.find_role RoleConstants::MENTOR_NAME
    program.find_role("user").update_attribute(:administrative, true)

    admin_role.remove_permission "view_mentors"
    mentor_role.remove_permission "view_mentors"
    assert_equal_unordered ["mentor", "student"], admin_user.visible_non_admin_roles
    assert_equal ["student"], mentor_user.visible_non_admin_roles

    admin_role.remove_permission "view_students"
    mentor_role.remove_permission "view_students"
    assert_equal_unordered ["mentor", "student"], admin_user.reload.visible_non_admin_roles
    assert_equal [], mentor_user.reload.visible_non_admin_roles
  end

  def test_user_checkins
    user = users(:f_mentor)
    task = create_mentoring_model_task
    group_checkins_last_duration = user.group_checkins_duration
    group_checkins_last_size = user.group_checkins.count
    task_checkin1 = create_task_checkin(task, :duration => 60)
    task_checkin2 = create_task_checkin(task, :duration => 45)
    assert_equal user.group_checkins.last(2), [task_checkin1, task_checkin2]
    assert_equal user.group_checkins_duration, group_checkins_last_duration + 1.75

    member_meeting = member_meetings(:member_meetings_1)
    meeting_checkin1 = create_meeting_checkin(member_meeting, :duration => 30)
    meeting_checkin2 = create_meeting_checkin(member_meeting, :duration => 15)
    group_checkins_new_size = 4 + group_checkins_last_size
    assert_equal user.group_checkins.count, group_checkins_new_size
    user.group_checkins.reload
    assert_equal user.group_checkins.last(4), [task_checkin1, task_checkin2, meeting_checkin1, meeting_checkin2]
    assert_equal user.group_checkins_duration, group_checkins_last_duration + 2.5

    assert_difference 'GroupCheckin.count', -(group_checkins_new_size) do
      assert_difference 'User.count', -1 do
        assert_nothing_raised do
          user.destroy
        end
      end
    end
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_basic_failure_case
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    assert_false mentor.can_send_mentor_request?
    can_send_request, flash_msg = mentor.can_send_mentor_request_to_mentor_with_error_flash?(student, {})
    assert_false can_send_request

    program.engagement_type = Program::EngagementType::PROJECT_BASED
    program.save!
    student.program.reload

    assert_false program.only_career_based_ongoing_mentoring_enabled?
    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_false can_send_request

    program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    program.save!
    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.matching_by_mentee_alone?

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_success_case
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    mentor.stubs(:slots_available_for_mentor_request).returns(2)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_equal "", flash_msg
    assert can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_mentor_opting_for_onetime
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    mentor.stubs(:slots_available_for_mentor_request).returns(2)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_equal "", flash_msg
    assert can_send_request

    mentor.stubs(:opting_for_ongoing_mentoring?).returns(false)
    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "#{mentor.name} is not available for a mentoring connection at this time and is not accepting any requests. However, #{mentor.name} is accepting only meetings. <a href=\"/p/albers/members/#{mentor.id}\">Click here</a> to view #{mentor.name}'s profile.", flash_msg
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_already_connected
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    mentor.stubs(:slots_available_for_mentor_request).returns(2)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_equal "", flash_msg
    assert can_send_request

    group = create_group(:students => [student], :mentor => mentor, :program => program)
    assert_false program.groups.involving(student, mentor).count.zero?

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "You are already connected with #{mentor.name} for a mentoring connection. You can look for other mentors who are available and reach out to them from <a href=\"/p/albers/users\">here</a>.", flash_msg
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_with_pending_request
    mentor = users(:f_mentor)
    mr = mentor.received_mentor_requests.active.first
    student = mr.student
    program = mentor.program

    assert mentor.received_mentor_requests.from_student(student).active.count > 0

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "You have already sent a request for mentoring connection to #{mentor.name}. You can look for other mentors who are available and reach out to them from <a href=\"/p/albers/users\">here</a>.", flash_msg
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_program_disallow_mentoring_requests
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    mentor.stubs(:slots_available_for_mentor_request).returns(2)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_equal "", flash_msg
    assert can_send_request

    program.allow_mentoring_requests = false
    program.save!
    student.program.reload

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "The mentors in this program are not accepting any mentoring connection requests. Please contact your admin if you have any queries.", flash_msg
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_mentee_connection_limit_reached
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    mentor.stubs(:slots_available_for_mentor_request).returns(2)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_equal "", flash_msg
    assert can_send_request

    student.stubs(:connection_limit_as_mentee_reached?).returns(true)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "You cannot send any more mentoring connection requests as you have reached the limit for the number of concurrent mentoring connections.", flash_msg
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_pending_request_limit_reached_for_mentee
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    mentor.stubs(:slots_available_for_mentor_request).returns(2)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_equal "", flash_msg
    assert can_send_request

    student.stubs(:pending_request_limit_reached_for_mentee?).returns(true)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "You cannot send any more mentoring connection requests as you have reached the limit for the number of concurrent pending requests. <a href=\"/p/albers/mentor_requests\">Click here</a> to view your pending requests.", flash_msg
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_mentor_is_suspended
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    mentor.stubs(:slots_available_for_mentor_request).returns(2)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {})
    assert_equal "", flash_msg
    assert can_send_request

    mentor.update_attribute(:state, User::Status::SUSPENDED)

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor.reload, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "#{mentor.name} is not available for a mentoring connection at this time and is not accepting any requests. You can look for other mentors who are available and reach out to them from <a href=\"/p/albers/users\">here</a>.", flash_msg
    assert_false can_send_request
  end

  def test_can_send_mentor_request_to_mentor_with_error_flash_no_mentor_slots
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_mentor_student)

    assert mentor.slots_available_for_mentor_request <= 0

    can_send_request, flash_msg = student.can_send_mentor_request_to_mentor_with_error_flash?(mentor, {:Mentor => "Mentor", :mentoring => "mentoring", :meetings => "meetings", :mentor => "mentor", :mentoring_connection => "mentoring connection", :mentors => "mentors", :program => "program", :admin => "admin", :mentoring_connections => "mentoring connections"})
    assert_equal "#{mentor.name} is not available for a mentoring connection at this time and is not accepting any requests. You can look for other mentors who are available and reach out to them from <a href=\"/p/albers/users\">here</a>.", flash_msg
    assert_false can_send_request
  end

  def test_has_many_dismissed_rollout_emails
    u = users(:student_8)
    re = u.dismissed_rollout_emails.create!
    assert_equal [re], u.dismissed_rollout_emails
    assert_difference 'RolloutEmail.count', -1 do
      u.destroy
    end
  end

  def test_has_many_user_activities
    assert 0, users(:f_admin).user_activities.count
    UserActivity.create!(user_id: users(:f_admin))
    assert 1, users(:f_admin).user_activities.count
  end

  def test_has_many_favorite_preferences
    assert_equal 0, users(:f_admin).favorite_preferences.count
    assert_equal 1, users(:rahim).favorite_preferences.count
    assert_equal 2, users(:f_student).favorite_preferences.count

    assert_equal 2, users(:f_student).favorite_users.count
    assert_equal 1, users(:rahim).favorite_users.count
    assert_equal [users(:ram).id], users(:rahim).favorite_users.pluck(:id)

    assert_equal 1, users(:f_mentor).mentee_marked_favorite_preferences.count
    assert_equal [abstract_preferences(:favorite_1).id], users(:f_mentor).mentee_marked_favorite_preferences.pluck(:id)
    assert_equal 1, users(:robert).mentee_marked_favorite_preferences.count
    assert_equal [abstract_preferences(:favorite_3).id], users(:robert).mentee_marked_favorite_preferences.pluck(:id)
  end

  def test_has_many_ignore_preferences
    assert_equal 0, users(:f_admin).ignore_preferences.count
    assert_equal 1, users(:rahim).ignore_preferences.count
    assert_equal 2, users(:f_student).ignore_preferences.count

    assert_equal 2, users(:f_student).ignored_users.count
    assert_equal 1, users(:rahim).ignored_users.count
    assert_equal [users(:robert).id], users(:rahim).ignored_users.pluck(:id)

    assert_equal 1, users(:f_mentor).mentee_marked_ignore_preferences.count
    assert_equal [abstract_preferences(:ignore_1).id], users(:f_mentor).mentee_marked_ignore_preferences.pluck(:id)
    assert_equal 1, users(:robert).mentee_marked_ignore_preferences.count
    assert_equal [abstract_preferences(:ignore_2).id], users(:robert).mentee_marked_ignore_preferences.pluck(:id)
  end

  def test_has_many_user_notification_settings
    user = users(:f_admin)
    uns = UserNotificationSetting.create!(notification_setting_name: UserNotificationSetting::SettingNames::END_USER_COMMUNICATION, user_id: user.id)
    assert_equal [uns], user.user_notification_settings
  end

  def test_preference_based_mentor_lists
    user = users(:no_subdomain_admin)
    assert_difference 'PreferenceBasedMentorList.count' do
      user.preference_based_mentor_lists.create!(ref_obj: Location.first, profile_question: ProfileQuestion.first, weight: 0.55)
    end

    assert_equal 0.55, user.preference_based_mentor_lists.last.weight

    assert_difference 'PreferenceBasedMentorList.count', -1 do
      user.destroy
    end    
  end

  def test_is_notification_disabled_for
    user = users(:f_admin)
    assert_false user.is_notification_disabled_for?(UserNotificationSetting::SettingNames::END_USER_COMMUNICATION)
    user.user_notification_settings.create!(notification_setting_name: UserNotificationSetting::SettingNames::END_USER_COMMUNICATION, disabled: true)
    assert user.is_notification_disabled_for?(UserNotificationSetting::SettingNames::END_USER_COMMUNICATION)

    setting = user.user_notification_settings.last
    setting.update_attributes!(disabled: false)
    assert_false user.is_notification_disabled_for?(UserNotificationSetting::SettingNames::END_USER_COMMUNICATION)
  end

  def test_get_state_based_message
    suspend_user(users(:student_1))
    members(:student_2).suspend!(members(:f_admin), "")
    users(:f_student).update_attribute(:state, User::Status::PENDING)

    custom_terms = { program: "track", programs: "tracks" }
    active_user = users(:f_mentor)
    pending_mentor_user = users(:pending_user)
    pending_mentee_user = users(:f_student)
    suspended_user = users(:student_1)
    suspended_member_user = users(:student_2)

    assert_nil active_user.get_state_based_message(custom_terms)
    assert_equal "The member has not yet published their profile", pending_mentor_user.get_state_based_message(custom_terms)
    assert_equal "#{pending_mentee_user.name} did not fill a few required fields in the profile during signup.", pending_mentee_user.get_state_based_message(custom_terms)
    assert_equal "#{suspended_user.name}'s membership has been deactivated from this track.", suspended_user.get_state_based_message(custom_terms)
    assert_equal "#{suspended_member_user.name}'s membership has been suspended and their access has been revoked from all the tracks they were part of.", suspended_member_user.get_state_based_message(custom_terms)
  end

  def test_public_groups_available_for_others_to_join
    user = users(:f_mentor_pbe)

    assert_equal user.groups.pluck(:id), [groups(:group_pbe).id, groups(:proposed_group_3).id, groups(:proposed_group_4).id, groups(:rejected_group_2).id, groups(:withdrawn_group_1).id]
    assert groups(:group_pbe).active?
    assert groups(:group_pbe).global?

    groups(:proposed_group_3).update_attribute(:global, false)
    groups(:proposed_group_3).update_attribute(:status, Group::Status::ACTIVE)

    groups(:proposed_group_4).update_attribute(:global, true)
    groups(:proposed_group_4).update_attribute(:status, Group::Status::PENDING)

    groups(:rejected_group_2).update_attribute(:global, true)
    groups(:rejected_group_2).update_attribute(:status, Group::Status::DRAFTED)

    assert_equal_unordered [groups(:group_pbe).id, groups(:proposed_group_4).id], user.public_groups_available_for_others_to_join.pluck(:id)
  end

  def test_can_render_calendar_ui_elements
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    assert program.calendar_enabled?
    assert users(:f_student).can_view_mentoring_calendar?
    assert users(:f_student).can_render_calendar_ui_elements?(RoleConstants::MENTOR_NAME)
  end

  def test_can_invite_other_roles
    u = users(:f_admin)
    program = programs(:albers)
    assert u.can_invite_roles?

    role = program.roles.find_by(name: RoleConstants::ADMIN_NAME)
    role.remove_permission("invite_mentors")
    role.remove_permission("invite_students")
    role.remove_permission("invite_admins")
    u.reload
    assert u.can_invite_roles?

    u = users(:f_mentor)
    assert u.can_invite_roles?
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.remove_permission("invite_mentors")
    u.reload
    assert_false u.can_invite_roles?

    u = users(:f_student)
    assert u.can_invite_roles?
    role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role.remove_permission("invite_students")
    u.reload
    assert_false u.can_invite_roles?


    program = programs(:primary_portal)

    u = users(:portal_admin)
    assert u.can_invite_roles?

    admin_role = u.roles.first
    admin_role.remove_permission("invite_employees")
    admin_role.remove_permission("invite_admins")
    u.reload
    assert u.can_invite_roles?

    u = users(:portal_employee)
    assert_false u.can_invite_roles?
    role = program.roles.find_by(name: RoleConstants::EMPLOYEE_NAME)
    role.add_permission("invite_employees")
    u.reload
    assert u.can_invite_roles?

  end

  def test_can_be_shown_meetings_listing
    user = users(:f_student)
    program = programs(:albers)

    assert_false user.member.meetings.of_program(program).present?
    assert_false user.is_available_only_for_ongoing_mentoring?
    program.enable_feature(FeatureName::CALENDAR, true)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)

    assert user.reload.can_be_shown_meetings_listing?

    User.any_instance.stubs(:is_available_only_for_ongoing_mentoring?).returns(true)
    assert_false user.can_be_shown_meetings_listing?

    user = users(:f_mentor)

    assert user.member.meetings.of_program(program).present?
    assert user.can_be_shown_meetings_listing?

    user = users(:f_student)

    User.any_instance.stubs(:is_available_only_for_ongoing_mentoring?).returns(false)
    program.enable_feature(FeatureName::CALENDAR, false)

    assert_false user.reload.can_be_shown_meetings_listing?

    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, true)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)

    user = users(:f_student)

    User.any_instance.stubs(:can_be_shown_mm_meetings?).returns(true)
    assert user.reload.can_be_shown_meetings_listing?

    User.any_instance.stubs(:can_be_shown_mm_meetings?).returns(false)
    assert_false user.can_be_shown_meetings_listing?

    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    assert user.reload.can_be_shown_meetings_listing?

    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    assert_false user.reload.can_be_shown_meetings_listing?
  end

  def test_can_be_shown_mm_meetings
    user = users(:f_mentor)

    assert user.groups.published.present?
    group = user.groups.published.first
    assert_false user.can_be_shown_mm_meetings?

    group.allow_manage_mm_meetings!(user.program.roles.for_mentoring)
    assert user.can_be_shown_mm_meetings?

    group.deny_manage_mm_meetings!(user.program.roles.for_mentoring)
    assert_false user.can_be_shown_mm_meetings?
  end

  def test_mentoring_requests_associations
    student = users(:f_student)
    mentor = users(:f_mentor)

    mr = create_mentor_request(:student => student, :mentor => mentor, :program => programs(:albers))

    assert_equal mr, student.pending_sent_mentor_requests.last
    assert_equal mr, mentor.pending_received_mentor_requests.last
  end

  def test_meeting_requests_associations
    student = users(:f_student)
    mentor = users(:f_mentor)

    mr = create_meeting_request(:student => student, :mentor => mentor, :program => programs(:albers))

    assert_equal mr, student.pending_sent_meeting_requests.last
    assert_equal mr, mentor.pending_received_meeting_requests.last

    mr.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)

    assert_false student.pending_sent_meeting_requests.include?(mr)
    assert_false mentor.pending_received_meeting_requests.include?(mr)

    assert_equal mr, student.accepted_sent_meeting_requests.last
    assert_equal mr, mentor.accepted_received_meeting_requests.last
  end

  def test_get_active_roles_and_membership_info
    program = programs(:albers)
    # Case 1: User with active and inactive groups
    user_with_active_group = users(:robert)
    membership_1 = connection_memberships(:connection_memberships_22)
    membership_2 = connection_memberships(:connection_memberships_24)
    users_groups_hash = User.get_active_roles_and_membership_info([user_with_active_group.id])
    assert_equal user_with_active_group.role_ids_in_active_groups, users_groups_hash[user_with_active_group.id][:role_ids_in_active_groups].collect(&:to_i)
    assert_equal user_with_active_group.connection_membership_ids, users_groups_hash[user_with_active_group.id].keys - [:role_ids_in_active_groups]
    assert_equal [Group::Status::ACTIVE], users_groups_hash[user_with_active_group.id][membership_1.id].values.uniq
    assert_equal [Group::Status::DRAFTED], users_groups_hash[user_with_active_group.id][membership_2.id].values.uniq

    # Case 2: User with only inactive groups
    groups(:drafted_group_1).publish(users(:f_admin))
    groups(:drafted_group_1).terminate!(users(:f_admin), "terminated", 1)
    groups(:group_5).publish(users(:f_admin))
    groups(:group_5).terminate!(users(:f_admin), "terminated", 1)
    user_with_inactive_groups = users(:student_1)
    membership_3 = connection_memberships(:connection_memberships_9)
    membership_4 = connection_memberships(:connection_memberships_23)
    users_groups_hash = User.get_active_roles_and_membership_info([user_with_inactive_groups.id])
    assert_empty users_groups_hash[user_with_inactive_groups.id][:role_ids_in_active_groups]
    assert_equal [Group::Status::CLOSED], users_groups_hash[user_with_inactive_groups.id][membership_3.id].values.uniq
    assert_equal [Group::Status::CLOSED], users_groups_hash[user_with_inactive_groups.id][membership_4.id].values.uniq

    # Case 3: User with no groups
    user_without_group = users(:f_mentor_student)
    users_groups_hash = User.get_active_roles_and_membership_info([user_without_group.id])
    assert_empty users_groups_hash[user_without_group.id][:role_ids_in_active_groups]
    assert_equal [:role_ids_in_active_groups], users_groups_hash[user_without_group.id].keys
  end

  def test_can_be_removed_or_suspended
    user = users(:f_mentor)
    assert user.can_be_removed_or_suspended?

    user.program.user_id = user.id
    assert_false user.can_be_removed_or_suspended?

    user.reload
    user.program.stubs(:standalone?).returns(true)
    assert user.can_be_removed_or_suspended?
    user.member.stubs(:is_chronus_admin?).returns(true)
    assert_false user.can_be_removed_or_suspended?

    user.program.stubs(:standalone?).returns(false)
    assert user.can_be_removed_or_suspended?
    user.member.admin = true
    assert_false user.can_be_removed_or_suspended?
  end

  def test_can_connect_with_a_mentee
    program = programs(:albers)
    user = users(:f_mentor)

    assert user.can_view_students?

    assert_false program.mentor_offer_enabled?
    assert user.is_mentor?
    assert_false user.is_student?
    assert_false user.can_connect_with_a_mentee?

    program.enable_feature(FeatureName::OFFER_MENTORING)
    user.program.reload
    assert program.mentor_offer_enabled?
    assert user.can_connect_with_a_mentee?

    fetch_role(:albers, :mentor).remove_permission('view_students')
    user.reload
    assert_false user.can_view_students?
    assert_false user.can_connect_with_a_mentee?
  end

  def test_can_connect_with_a_mentor
    program = programs(:albers)
    user = users(:f_student)

    assert user.can_view_mentors?

    assert_false user.is_mentor?
    assert user.is_student?
    assert_false program.calendar_enabled?
    assert program.matching_by_mentee_alone?
    assert user.can_connect_with_a_mentor?

    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false program.matching_by_mentee_alone?
    assert_false user.can_connect_with_a_mentor?

    program.enable_feature(FeatureName::CALENDAR)
    user.program.reload
    assert program.calendar_enabled?
    assert user.can_connect_with_a_mentor?
    program.enable_feature(FeatureName::CALENDAR, false)
    user.program.reload

    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    assert program.matching_by_mentee_and_admin?
    assert user.can_connect_with_a_mentor?

    fetch_role(:albers, :student).remove_permission('view_mentors')
    user.reload
    assert_false user.can_view_mentors?
    assert_false user.can_connect_with_a_mentor?

    user = users(:f_admin)
    assert_false user.can_connect_with_a_mentor?
  end

  def test_get_groups_to_display_in_publish_circle_widget
    user = users(:f_student_pbe)

    assert_equal [], user.owned_groups.pending
    assert_equal [], user.get_groups_to_display_in_publish_circle_widget

    group1 = groups(:proposed_group_1)
    group2 = groups(:proposed_group_2)

    group1.update_attributes!(:status => Group::Status::PENDING, :pending_at => 8.days.ago)
    group2.update_attributes!(:status => Group::Status::PENDING, :pending_at => 9.days.ago)

    group1.membership_of(user).update_attributes!(owner: true)
    group2.membership_of(user).update_attributes!(owner: true)

    assert_equal_unordered [group1, group2], user.owned_groups.pending

    assert group1.students.count > 0
    assert_false group1.mentors.count > 0

    assert group2.students.count > 0
    assert_false group2.mentors.count > 0

    assert_equal [], user.get_groups_to_display_in_publish_circle_widget

    group1.update_members([users(:f_mentor_pbe)], group1.students)
    assert_equal [group1], user.get_groups_to_display_in_publish_circle_widget

    group2.update_members([users(:pbe_mentor_2)], group2.students)
    assert_equal [group2, group1], user.get_groups_to_display_in_publish_circle_widget

    group2.update_attributes!(:status => Group::Status::PENDING, :pending_at => 8.days.ago)
    assert_equal [group1, group2], user.get_groups_to_display_in_publish_circle_widget

    group2.update_members([users(:pbe_mentor_2), users(:pbe_mentor_3)], group2.students)
    assert_equal [group2, group1], user.get_groups_to_display_in_publish_circle_widget

    group2.update_attributes!(:status => Group::Status::PENDING, :pending_at => 6.days.ago)
    assert_equal [group1], user.get_groups_to_display_in_publish_circle_widget
  end

  def test_can_be_shown_flash_meetings_widget
    user = users(:f_mentor)

    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(false)
    Program.any_instance.stubs(:calendar_enabled?).returns(false)
    User.any_instance.stubs(:can_be_shown_connection_widget?).returns(true)
    assert_false user.can_be_shown_flash_meetings_widget?

    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert user.can_be_shown_flash_meetings_widget?

    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(false)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    assert_false user.can_be_shown_flash_meetings_widget?

    User.any_instance.stubs(:can_be_shown_connection_widget?).returns(false)
    assert user.can_be_shown_flash_meetings_widget?

    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(false)
    assert user.can_be_shown_flash_meetings_widget?
  end

  def test_can_be_shown_connection_tab_or_widget
    user = users(:not_requestable_mentor)

    group1 = groups(:group_2)
    group2 = groups(:group_3)

    assert_equal Group::Status::ACTIVE, group1.status
    assert_equal Group::Status::ACTIVE, group2.status
    assert_false user.groups.closed.present?
    assert user.roles.for_mentoring.exists?

    User.any_instance.stubs(:opting_for_ongoing_mentoring?).returns(false)

    assert user.can_be_shown_connection_tab_or_widget?

    group1.update_column(:status, Group::Status::PENDING)
    group2.update_column(:status, Group::Status::PENDING)
    user.groups.reload

    User.any_instance.stubs(:opting_for_ongoing_mentoring?).returns(true)
    assert_false user.can_be_shown_connection_tab_or_widget?

    Program.any_instance.stubs(:project_based?).returns(true)
    assert user.can_be_shown_connection_tab_or_widget?

    Program.any_instance.stubs(:project_based?).returns(false)

    group2.update_column(:status, Group::Status::CLOSED)
    user.groups.reload

    assert user.can_be_shown_connection_tab_or_widget?

    group2.update_column(:status, Group::Status::PENDING)
    user.groups.reload

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_false user.can_be_shown_connection_tab_or_widget?

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(true)

    group2.update_column(:status, Group::Status::CLOSED)
    user.groups.reload

    user.remove_role(RoleConstants::MENTOR_NAME)
    user.add_role(RoleConstants::STUDENT_NAME)

    assert user.reload.roles.for_mentoring.exists?
    assert user.can_be_shown_connection_tab_or_widget?

    user.program.roles.create(name: RoleConstants::TEACHER_NAME, administrative: false)

    user.remove_role(RoleConstants::STUDENT_NAME)
    user.add_role(RoleConstants::TEACHER_NAME)

    assert_false user.reload.roles.for_mentoring.exists?
    assert_false user.can_be_shown_connection_tab_or_widget?
  end

  def test_can_view_match_report
    user = users(:f_mentor)

    Program.any_instance.stubs(:can_show_match_report?).returns(true)
    user.stubs(:can_view_reports?).returns(true)
    assert user.can_view_match_report?

    Program.any_instance.stubs(:can_show_match_report?).returns(false)
    user.stubs(:can_view_reports?).returns(true)
    assert_false user.can_view_match_report?

    Program.any_instance.stubs(:can_show_match_report?).returns(true)
    user.stubs(:can_view_reports?).returns(false)
    assert_false user.can_view_match_report?

    Program.any_instance.stubs(:can_show_match_report?).returns(false)
    user.stubs(:can_view_reports?).returns(false)
    assert_false user.can_view_match_report?
  end

  def test_can_remove_or_suspend
    admin = users(:f_admin)
    user = users(:f_student)

    assert admin.can_remove_or_suspend?(user)
    assert_false admin.can_remove_or_suspend?(admin)
    assert_false user.can_remove_or_suspend?(user)
    assert_false user.can_remove_or_suspend?(admin)

    user.stubs(:can_be_removed_or_suspended?).returns(false)
    assert_false admin.can_remove_or_suspend?(user)
  end

  def test_removal_or_suspension_scope
    program = programs(:albers)
    user_1 = users(:f_mentor)
    user_2 = users(:f_student)
    admin = users(:f_admin)
    member_2 = user_2.member
    users = [user_1, user_2, admin]

    users_scope = program.users.where(id: users.map(&:id))
    assert_equal_unordered [user_1, user_2], User.removal_or_suspension_scope(users_scope, program, admin.member_id).to_a

    program.update_attribute(:user_id, user_1.id)
    assert_equal [user_2], User.removal_or_suspension_scope(users_scope, program, admin.member_id).to_a

    program.stubs(:standalone?).returns(true)
    member_2.admin = true
    member_2.email = SUPERADMIN_EMAIL
    member_2.save!
    assert_empty User.removal_or_suspension_scope(users_scope, program, admin.member_id).to_a

    program.update_attribute(:user_id, nil)
    assert_equal [user_1], User.removal_or_suspension_scope(users_scope, program, admin.member_id).to_a
    member_2.admin = false
    member_2.save!
    assert_equal_unordered users, User.removal_or_suspension_scope(users_scope, program, 0).to_a
  end

  def test_get_mentor_limit_to_reset_no_effect
    p = programs(:albers)
    user = users(:mentor_1)

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_INCREASE)
    p.update_attribute(:default_max_connections_limit, 4)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).returns(array_of_size_5)
    user.update_attributes(max_connections_limit: 4)

    user.reload
    assert_nil user.get_mentor_limit_to_reset

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_DECREASE)
    user.reload
    assert_nil user.get_mentor_limit_to_reset

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::BOTH)
    user.reload
    assert_nil user.get_mentor_limit_to_reset
  end

  def test_allowed_to_ignore_and_mark_favorite
    user = users(:f_student)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(false)
    user.stubs(:can_ignore_and_mark_favorite).returns(true)
    assert_false user.allowed_to_ignore_and_mark_favorite?

    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    user.stubs(:can_ignore_and_mark_favorite?).returns(false)
    assert_false user.allowed_to_ignore_and_mark_favorite?

    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(false)
    user.stubs(:can_ignore_and_mark_favorite?).returns(false)
    assert_false user.allowed_to_ignore_and_mark_favorite?

    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    user.stubs(:can_ignore_and_mark_favorite?).returns(true)
    assert user.allowed_to_ignore_and_mark_favorite?
  end

  def test_get_mentor_limit_to_reset
    p = programs(:albers)
    user = users(:mentor_1)

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_INCREASE)

    p.update_attribute(:default_max_connections_limit, 4)
    array_of_size_3 = [1, 2, 3]
    User.any_instance.stubs(:students).returns(array_of_size_3)
    user.update_attributes(max_connections_limit: 6)

    user.reload
    assert_equal 4, user.get_mentor_limit_to_reset

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_DECREASE)
    user.reload
    assert_equal 3, user.get_mentor_limit_to_reset

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::BOTH)
    user.reload
    assert_equal 3, user.get_mentor_limit_to_reset
  end

  def test_get_mentor_limit_to_reset_ongoing_greater_than_program_limit
    p = programs(:albers)
    user = users(:mentor_1)

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_INCREASE)

    user.update_attributes(max_connections_limit: 7)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).returns(array_of_size_5)

    user.reload
    assert_equal 5, user.get_mentor_limit_to_reset

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_INCREASE)
    user.reload
    assert_equal 5, user.get_mentor_limit_to_reset

    p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_DECREASE)
    user.reload
    assert_equal 5, user.get_mentor_limit_to_reset
  end

  def test_get_meeting_limit_to_reset
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    user = users(:f_mentor)
    Timecop.freeze(time_now) do
      user.expects(:get_meeting_slots_booked_in_the_month).with(time_now).returns(3)
      user.expects(:get_meeting_slots_booked_in_the_month).with(time_now.next_month).returns(5)
      assert_equal 5, user.get_meeting_limit_to_reset
    end

    Timecop.freeze(time_now) do
      user.expects(:get_meeting_slots_booked_in_the_month).with(time_now).returns(4)
      user.expects(:get_meeting_slots_booked_in_the_month).with(time_now.next_month).returns(1)
      assert_equal 4, user.get_meeting_limit_to_reset
    end
  end

  def test_visible_to_with_meeting_request
    program = programs(:albers)
    mentor = users(:f_mentor)

    fetch_role(:albers, :mentor).remove_permission('view_students')
    student = users(:rahim)
    assert_false student.visible_to?(mentor)
    create_meeting_request(student: student, mentor: mentor, program: programs(:albers))
    assert student.visible_to?(mentor)
  end

  def test_visible_to_with_mentor_offer
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    mentor = users(:f_mentor)
    student = users(:f_student)

    fetch_role(:albers, :student).remove_permission('view_mentors')
    assert_false mentor.visible_to?(student)
    create_mentor_offer
    assert mentor.visible_to?(student)
  end

  def test_can_connect_with_mentor_and_has_slots
    program = programs(:albers)
    user = users(:f_student)

    assert user.is_student?

    assert_false program.calendar_enabled?
    assert program.allow_mentoring_requests?
    assert_false user.pending_request_limit_reached_for_mentee?
    assert_false user.connection_limit_as_mentee_reached?

    assert user.can_connect_with_mentor_and_has_slots?(true)
    assert_false user.can_connect_with_mentor_and_has_slots?(false)

    user.stubs(:connection_limit_as_mentee_reached?).returns(true)
    assert_false user.can_connect_with_mentor_and_has_slots?(true)
    user.unstub(:connection_limit_as_mentee_reached?)
    assert user.can_connect_with_mentor_and_has_slots?(true)

    user.stubs(:pending_request_limit_reached_for_mentee?).returns(true)
    assert_false user.can_connect_with_mentor_and_has_slots?(true)
    user.unstub(:pending_request_limit_reached_for_mentee?)
    assert user.can_connect_with_mentor_and_has_slots?(true)

    program.update_attribute(:allow_mentoring_requests, false)
    user.reload
    assert_false user.can_connect_with_mentor_and_has_slots?(true)

    program.enable_feature(FeatureName::CALENDAR, true)
    user.reload
    assert user.can_connect_with_mentor_and_has_slots?(true)
  end

  def test_can_be_shown_match_tab
    program = programs(:albers)
    user = users(:f_mentor)

    User.any_instance.expects(:can_connect_with_mentor_and_has_slots?).twice.returns(true)
    assert user.can_be_shown_match_tab?(true)
    assert user.can_be_shown_match_tab?(false)

    User.any_instance.stubs(:can_connect_with_mentor_and_has_slots?).returns(false)

    assert user.is_mentor?
    assert_false user.is_student?
    assert_false user.can_offer_mentoring?
    assert user.can_mentor?

    assert_false user.can_be_shown_match_tab?(false)

    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    assert user.reload.can_offer_mentoring?
    assert user.can_be_shown_match_tab?(false)
    assert_false user.can_be_shown_match_tab?(true)

    user.stubs(:can_mentor?).returns(false)
    assert_false user.can_be_shown_match_tab?(false)
    user.unstub(:can_mentor?)

    assert user.can_be_shown_match_tab?(false)
    fetch_role(:albers, :mentor).remove_permission('view_students')
    user.reload
    assert_false user.can_be_shown_match_tab?(false)
  end

  def test_is_unconnected
    program = programs(:albers)
    user = users(:f_mentor)
    assert_false user.is_unconnected?
    user.groups.active.update_all(status: Group::Status::PENDING)
    assert user.is_unconnected?
    program.enable_feature(FeatureName::CALENDAR, true)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    meeting = meetings(:upcoming_calendar_meeting)
    meeting.update_meeting_time(Time.now + 2.days, 1800.00)
    assert_false user.reload.is_unconnected?
  end

  def test_can_see_match_details
    program = programs(:albers)
    user = users(:f_mentor)
    assert_equal [], program.match_configs
    assert_false user.can_see_match_details?
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question)
    assert_equal [config], program.reload.match_configs
    assert_false user.reload.can_see_match_details?

    config.update_attribute(:show_match_label, true)
    assert user.reload.can_see_match_details?
  end

  def test_get_match_details_answer_pairs
    program = programs(:albers)
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    User.any_instance.stubs(:can_see_match_details?).returns(false)
    Matching::Service.any_instance.expects(:get_match_details).never
    details = user.get_match_details_answer_pairs(mentor_user)
    assert_equal [], details

    User.any_instance.stubs(:can_see_match_details?).returns(true)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_student))

    ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_mentor))

    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true)
    details = [[1, config.id, ["Choice 1"]]]
    Matching::Service.any_instance.expects(:get_match_details).once.returns(details)
    details_from_service = user.get_match_details_answer_pairs(mentor_user)

    assert_equal details, details_from_service

    Matching::Service.any_instance.expects(:get_match_details).never
    user.stubs(:is_student?).returns(false)
    details_from_service = user.get_match_details_answer_pairs(mentor_user)
    assert_equal [], details_from_service

    user.stubs(:is_student?).returns(true)

    Matching::Service.any_instance.expects(:get_match_details).never
    mentor_user.stubs(:is_mentor?).returns(false)
    details_from_service = user.get_match_details_answer_pairs(mentor_user)
    assert_equal [], details_from_service

    mentor_user.stubs(:is_mentor?).returns(true)
    details2 = []
    Matching::Service.any_instance.expects(:get_match_details).once.returns(details2)
    details_from_service = user.get_match_details_answer_pairs(mentor_user)
    assert_equal details2, details_from_service
  end

  def test_get_match_details_of_blank_cases
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    program = programs(:albers)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    pa1=ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_student))
    pa1.answer_value = ["Choice 1"]
    pa1.save!

    pa2=ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_mentor))
    pa2.answer_value = ["Choice 1"]
    pa2.save!

    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true)

    details = []
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q])
    assert_equal [], val

    details = [[0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q])
    assert_equal ["Choice 1"], val.first[:answers]
    assert_equal "Choice Field1", val.first[:question_text]

    details = [[0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [])
    assert_equal [], val
  end

  def test_get_match_details_of
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    program = programs(:albers)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    pa1=ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_student))
    pa1.answer_value = ["Choice 1"]
    pa1.save!

    pa2=ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_mentor))
    pa2.answer_value = ["Choice 1"]
    pa2.save!

    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true)

    prof_q2 = create_profile_question(question_type: ProfileQuestion::Type::MULTI_CHOICE, question_text: "Choice Field2", question_choices: ["Option 1", "Option 2", "Option 3"], organization: programs(:org_primary))
    prog_mentor_question2 = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q2)
    prog_student_question2 = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q2)

    pa1=ProfileAnswer.create!(
        :answer_text => "Option 2, Option 3",
        :profile_question => prof_q2, :ref_obj => members(:f_student))
    pa1.answer_value = ["Option 2", "Option 3"]
    pa1.save!

    pa2=ProfileAnswer.create!(
        :answer_text => "Option 2, Option 3",
        :profile_question => prof_q2, :ref_obj => members(:f_mentor))
    pa2.answer_value = ["Option 2", "Option 3"]
    pa2.save!

    config2 = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question2,
        student_question: prog_student_question2,
        show_match_label: true)

    details = [[0.5, config2.id, ["option 2", "option 3"]], [0.6, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])
    assert_equal ["Choice 1"], val.first[:answers]
    assert_equal "Choice Field1", val.first[:question_text]
    assert_equal ["Option 2", "Option 3"], val.last[:answers]
    assert_equal "Choice Field2", val.last[:question_text]

    details = [[0.6, config2.id, ["option 2", "option 3"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])

    assert_equal ["Choice 1"], val.last[:answers]
    assert_equal "Choice Field1", val.last[:question_text]
    assert_equal ["Option 2", "Option 3"], val.first[:answers]
    assert_equal "Choice Field2", val.first[:question_text]

    #match_config_not_present
    details = [[0.6, config2.id+config.id+1, ["option 2", "option 3"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])
    expected_val = [{answers: ["Choice 1"], question_text: "Choice Field1"}]

    assert_equal expected_val, val

    #mentor question not present
    prof_q3 = create_profile_question(question_type: ProfileQuestion::Type::MULTI_CHOICE, question_text: "Choice Field2", question_choices: ["Option 1", "Option 2", "Option 3"], organization: programs(:org_primary))
    details = [[0.6, config2.id, ["option 2", "option 3"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q3, prof_q2])
    expected_val = [{answers: ["Option 2", "Option 3"], question_text: "Choice Field2"}]

    assert_equal expected_val, val

    #match_question_with_differnt_answer
    details = [[0.6, config2.id, ["option x", "option 3"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])

    assert_equal ["Choice 1"], val.last[:answers]
    assert_equal "Choice Field1", val.last[:question_text]
    assert_equal ["Option 3"], val.first[:answers]
    assert_equal "Choice Field2", val.first[:question_text]

    #match_question_with_all_differnt_answer
    details = [[0.6, config2.id, ["option x", "option y"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])
    expected_val = [{answers: ["Choice 1"], question_text: "Choice Field1"}]
    assert_equal expected_val, val

    #match_question_with_nil_answer
    details = [[0.6, config2.id, ["nil", "option 2"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])
    expected_val = [{answers: ["Option 2"], question_text: "Choice Field2"}, {answers: ["Choice 1"], question_text: "Choice Field1"}]
    assert_equal expected_val, val

    #match_question_with_all_nil_answer
    details = [[0.6, config2.id, ["nil", "nil"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])
    expected_val = [{answers: ["Choice 1"], question_text: "Choice Field1"}]
    assert_equal expected_val, val

    #match_question_with_prefix
    config2.update_attribute(:prefix, "prefix1")
    details = [[0.6, config2.id, ["option 2", "option 3"]], [0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.get_match_details_of(mentor_user, [prof_q, prof_q2])

    assert_equal ["Choice 1"], val.last[:answers]
    assert_equal "Choice Field1", val.last[:question_text]
    assert_equal ["prefix1 - Option 2", "prefix1 - Option 3"], val.first[:answers]
    assert_equal "Choice Field2", val.first[:question_text]
  end


  def test_get_matched_answer_text_with_explicit_preferences
    user = users(:arun_albers)
    assert_equal [question_choices(:student_single_choice_q_2).text], user.get_matched_answer_text_with_explicit_preferences(explicit_user_preferences(:explicit_user_preference_1), [], [question_choices(:student_single_choice_q_2)])

    user_1 = users(:drafted_group_user)
    assert_equal [], user_1.get_matched_answer_text_with_explicit_preferences(explicit_user_preferences(:explicit_user_preference_4), [], [])

    location_answer = explicit_user_preferences(:explicit_user_preference_4).role_question.profile_question.profile_answers.first
    ExplicitUserPreference.any_instance.stubs(:preference_string).returns(location_answer.location.full_city)
    assert_equal [location_answer.location.full_city], user_1.get_matched_answer_text_with_explicit_preferences(explicit_user_preferences(:explicit_user_preference_4), [location_answer].index_by(&:profile_question_id), [])
  end

  def test_get_visibile_match_config_profile_questions_for
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    mentor_role_questions = mentor_user.roles.first.role_questions
    mentor_profile_questions = mentor_role_questions.collect(&:profile_question)
    #with all Questions visible and part of match_configs
    RoleQuestion.any_instance.stubs(:visible_for?).returns(true)
    MatchConfig.const_get("ActiveRecord_AssociationRelation").any_instance.stubs(:pluck).returns(mentor_role_questions.map(&:id))
    visible_questions = user.get_visibile_match_config_profile_questions_for(mentor_user)
    assert_equal_unordered mentor_profile_questions, visible_questions

    #with no Questions visible and all part of match_configs
    RoleQuestion.any_instance.stubs(:visible_for?).returns(false)
    visible_questions = user.get_visibile_match_config_profile_questions_for(mentor_user)
    assert_equal_unordered [], visible_questions
  end

  def test_can_see_match_details_of
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    program = programs(:albers)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    pa1=ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_student))
    pa1.answer_value = ["Choice 1"]
    pa1.save!

    pa2=ProfileAnswer.create!(
        :answer_text => "Choice 1",
        :profile_question => prof_q, :ref_obj => members(:f_mentor))
    pa2.answer_value = ["Choice 1"]
    pa2.save!

    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true)

    details = []
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.can_see_match_details_of?(mentor_user)
    assert_false val

    details = [[0.5, config.id, []]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.can_see_match_details_of?(mentor_user)
    assert_false val

    details = [[0.5, config.id, ["choice 1"]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.can_see_match_details_of?(mentor_user)
    assert val

    details = [[0.5, config.id, [nil]]]
    user.expects(:get_match_details_answer_pairs).once.returns(details)
    val = user.can_see_match_details_of?(mentor_user)
    assert_false val
  end

  def test_process_match_details
    user = users(:f_student)
    details = [[0.5, 2, "choice 1"]]
    assert_equal [], user.send(:process_match_details, details)

    details = [[nil, 2, ["choice 1"]]]
    assert_equal [], user.send(:process_match_details, details)

    details = [[0.5, nil, ["choice 1"]]]
    assert_equal [], user.send(:process_match_details, details)
  end

  def test_get_visibile_match_config_profile_questions_for_without_match_configs
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    program = user.program
    choice_based_questions = program.organization.profile_questions.where(question_type: [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE]).pluck(:id)
    prog_student_question = user.roles.first.role_questions.where(profile_question_id: choice_based_questions).last
    prog_mentor_question = mentor_user.roles.first.role_questions.where(profile_question_id: choice_based_questions).last
    RoleQuestion.any_instance.stubs(:visible_for?).returns(true)
    assert_equal [], user.program.match_configs
    visible_questions = user.get_visibile_match_config_profile_questions_for(mentor_user)
    assert_equal_unordered [], visible_questions

    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true)
    assert_equal [config], user.program.reload.match_configs
    visible_questions = user.get_visibile_match_config_profile_questions_for(mentor_user)
    assert_equal_unordered [prog_mentor_question.profile_question], visible_questions

    RoleQuestion.any_instance.stubs(:visible_for?).returns(false)
    visible_questions = user.get_visibile_match_config_profile_questions_for(mentor_user)
    assert_equal_unordered [], visible_questions
  end

  def test_get_visibile_match_config_profile_questions_for_visibility
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    program = user.program
    choice_based_questions = program.organization.profile_questions.where(question_type: [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE]).pluck(:id)
    prog_student_question = user.roles.first.role_questions.where(profile_question_id: choice_based_questions).last
    prog_mentor_question = mentor_user.roles.first.role_questions.where(profile_question_id: choice_based_questions).last

    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true)
    prog_student_question2 = user.roles.first.role_questions.where(profile_question_id: choice_based_questions).first
    prog_mentor_question2 = mentor_user.roles.first.role_questions.where(profile_question_id: choice_based_questions).first

    config2 = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question2,
        student_question: prog_student_question2,
        show_match_label: true)
    assert_equal [config, config2], user.program.reload.match_configs

    prog_mentor_question.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    visible_questions = user.reload.get_visibile_match_config_profile_questions_for(mentor_user)
    assert_equal_unordered [prog_mentor_question2.profile_question], visible_questions
  end

  def test_get_active_announcements
    user = users(:f_mentor)
    assert_equal_unordered [announcements(:assemble), announcements(:big_announcement)], user.get_active_announcements
    announcements(:big_announcement).update_column(:updated_at, Time.now)
    user = users(:f_student)
    announcement1 = create_announcement(:title => "Draft", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name), :status => Announcement::Status::DRAFTED)
    announcement2 = create_announcement(:title => "Hello", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    assert_equal [announcement2, announcements(:big_announcement), announcements(:assemble)], user.get_active_announcements
  end

  def test_get_ordered_active_announcements
    user = users(:not_requestable_mentor)
    announcements(:assemble).update_column(:updated_at, Time.now)
    assert_equal [announcements(:big_announcement), announcements(:assemble)], user.get_ordered_active_announcements
    #announcements before cutoff date are also treated as unviewed
    announcements(:big_announcement).update_column(:updated_at, Announcement::VIEWABLE_CUTOFF_DATE.to_datetime - 1.day)
    assert_equal [announcements(:assemble), announcements(:big_announcement)], user.get_ordered_active_announcements
    create_viewed_object(ref_obj: announcements(:big_announcement), user: user)
    assert_equal [announcements(:assemble), announcements(:big_announcement)], user.get_ordered_active_announcements
    announcement1 = create_announcement(:title => "Hello", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    announcements(:assemble).update_column(:updated_at, Time.now)
    assert_equal [announcement1, announcements(:assemble), announcements(:big_announcement)], user.get_ordered_active_announcements
  end

  def test_get_active_unviewed_announcements_count
    user = users(:not_requestable_mentor)
    assert_equal 1, user.get_active_unviewed_announcements_count
    announcement1 = create_announcement(:title => "Draft", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name), :status => Announcement::Status::DRAFTED)
    announcement2 = create_announcement(:title => "Hello", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    assert_equal 2, user.get_active_unviewed_announcements_count
    announcement2.update_column(:updated_at, Announcement::VIEWABLE_CUTOFF_DATE.to_datetime - 1.day)
    assert_equal 1, user.get_active_unviewed_announcements_count
  end

  def test_email_with_id_hash
    user = users(:f_mentor)
    expected = {nameEmail: "Good unique name <robert@example.com>", userId: 3, nameEmailForDisplay: "Good unique name &lt;robert@example.com&gt;"}
    assert_equal expected, user.email_with_id_hash
  end

  def test_get_cummulative_unviewed_posts
    group = groups(:mygroup)
    group.mentoring_model = mentoring_models(:mentoring_models_1)
    group.mentoring_model.allow_forum = true
    group.save
    group.create_group_forum
    mentor = group.mentors.first
    student = group.students.first
    topic1 = create_topic(forum: group.forum, user: mentor)
    post1 = create_post(topic: topic1, user: mentor)
    post2 = create_post(topic: topic1, user: mentor)
    assert_equal [], mentor.get_cummulative_unviewed_posts([topic1.id])
    assert_equal_unordered [post1, post2], student.get_cummulative_unviewed_posts([topic1.id])
    ViewedObject.create(ref_obj: post1, user: student)
    assert_equal_unordered [post2], student.get_cummulative_unviewed_posts([topic1.id])
    topic1.update_column(:updated_at, 1.year.ago)
    assert_equal_unordered [], student.get_cummulative_unviewed_posts([topic1.id])
  end

  def test_get_unviewed_posts_count_by_topic
    group = groups(:mygroup)
    group.mentoring_model = mentoring_models(:mentoring_models_1)
    group.mentoring_model.allow_forum = true
    group.save
    group.create_group_forum
    mentor = group.mentors.first
    student = group.students.first
    topic1 = create_topic(forum: group.forum, user: mentor)
    topic2 = create_topic(forum: group.forum, user: mentor)
    post1 = create_post(topic: topic1, user: mentor)
    post2 = create_post(topic: topic1, user: mentor)
    post3 = create_post(topic: topic2, user: mentor)
    posts_count_hash = {}
    assert_equal posts_count_hash, mentor.get_unviewed_posts_count_by_topic(group, [topic1.id, topic2.id])
    posts_count_hash = {topic1.id=>2, topic2.id=>1}
    assert_equal posts_count_hash, student.get_unviewed_posts_count_by_topic(group, [topic1.id, topic2.id])
  end

  def test_can_see_guidance_popup
    user = users(:f_student)

    user.stubs(:is_student?).returns(false) 
    assert_false user.can_see_guidance_popup?

    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false user.can_see_guidance_popup?

    user.stubs(:can_view_mentors?).returns(false)
    assert_false user.can_see_guidance_popup?

    OneTimeFlag.stubs(:has_tag?).with(user, OneTimeFlag::Flags::Popups::MENTEE_GUIDANCE_POPUP_TAG).returns(true)
    assert_false user.can_see_guidance_popup?

    user.stubs(:not_sent_any_meeting_or_mentoring_requests?).returns(false)
    assert_false user.can_see_guidance_popup?

    Program.any_instance.stubs(:self_match_and_not_pbe?).returns(false)
    assert_false user.can_see_guidance_popup?

    user.stubs(:is_student?).returns(true) 
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(true)
    user.stubs(:can_view_mentors?).returns(true)
    Program.any_instance.stubs(:self_match_and_not_pbe?).returns(true)
    user.stubs(:not_sent_any_meeting_or_mentoring_requests?).returns(true)
    Program.any_instance.stubs(:self_match_and_not_pbe?).returns(true)
    OneTimeFlag.stubs(:has_tag?).with(user, OneTimeFlag::Flags::Popups::MENTEE_GUIDANCE_POPUP_TAG).returns(false)
    assert user.can_see_guidance_popup?
  end

  def test_not_sent_any_meeting_or_mentoring_requests
    user = users(:f_student)
    user.stubs(:sent_mentor_requests).returns([groups(:mygroup)])
    assert_false user.not_sent_any_meeting_or_mentoring_requests?

    user.stubs(:sent_meeting_requests).returns([groups(:mygroup)])
    assert_false user.not_sent_any_meeting_or_mentoring_requests?

    user.stubs(:sent_mentor_requests).returns([])
    user.stubs(:sent_meeting_requests).returns([])
    assert user.not_sent_any_meeting_or_mentoring_requests?
  end

  def test_explicit_preferences_configured
    user = users(:arun_albers)
    assert user.explicit_user_preferences.present?
    assert_false user.explicit_preferences_configured?

    Program.any_instance.stubs(:explicit_user_preferences_enabled?).returns(true)
    assert user.explicit_preferences_configured?
    assert_false users(:f_student).explicit_preferences_configured?
  end

  def test_can_configure_explicit_preferences
    user = users(:f_student)
    Program.any_instance.stubs(:explicit_user_preferences_enabled?).returns(false)
    assert_false user.can_configure_explicit_preferences?

    Program.any_instance.stubs(:explicit_user_preferences_enabled?).returns(true)
    assert user.can_configure_explicit_preferences?

    user.stubs(:is_student?).returns(false)
    assert_false user.can_configure_explicit_preferences?
  end

  def test_get_applicable_role_to_add_without_approval
    program = programs(:albers)
    mentor_user = users(:f_mentor)
    assert_equal ["mentor"], mentor_user.role_names

    mentee_user = users(:f_student)
    assert_equal ["student"], mentee_user.role_names

    assert_nil mentor_user.get_applicable_role_to_add_without_approval
    assert_nil mentee_user.get_applicable_role_to_add_without_approval

    program.roles.find_by(name: RoleConstants::MENTOR_NAME).add_permission("become_student")
    assert_equal roles("#{program.id}_student"), mentor_user.get_applicable_role_to_add_without_approval
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).add_permission("become_mentor")
    assert_equal roles("#{program.id}_mentor"), mentee_user.get_applicable_role_to_add_without_approval

    mentor_user.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::ADMIN_NAME]
    mentor_user.save!
    assert_nil mentor_user.reload.get_applicable_role_to_add_without_approval

    mentee_user.role_names = [RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME]
    mentee_user.save!
    assert_nil mentee_user.reload.get_applicable_role_to_add_without_approval
  end

  def test_allowed_to_edit_max_connections_limit
    program = programs(:albers)
    user = users(:f_mentor)
    assert user.allowed_to_edit_max_connections_limit?(program)
    program.stubs(:allow_mentor_update_maxlimit?).returns(false)
    assert user.allowed_to_edit_max_connections_limit?(program, true)
    assert_false user.allowed_to_edit_max_connections_limit?(program)
    program.stubs(:allow_mentor_update_maxlimit?).returns(true)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    assert_false user.allowed_to_edit_max_connections_limit?(program)
  end

  def test_profile_answer_choices
    assert_equal "", users(:f_admin).profile_answer_choices
    pas = profile_answers(:single_choice_ans_1, :one, :single_choice_ans_2)
    Member.any_instance.stubs(:profile_answers).returns(pas)
    assert_equal "#{answer_choices(:answer_choices_1).question_choice_id} #{answer_choices(:answer_choices_2).question_choice_id}", users(:f_admin).profile_answer_choices

    ProfileQuestion::Type.stubs(:choice_based_types).returns([])
    assert_equal "", users(:f_admin).profile_answer_choices
  end

  def test_allow_project_requests_for_role
    user = users(:f_student)
    role = user.roles.first
    role.stubs(:no_limit_on_project_requests?).returns(false)
    role.update_attributes(max_connections_limit: 3)
    user.stubs(:get_memberships_of_open_or_proposed_groups_with_role).with(role).returns([1,1])
    assert user.allow_project_requests_for_role?(role)
    role.update_attributes(max_connections_limit: 1)
    assert_false user.allow_project_requests_for_role?(role)
    role.stubs(:no_limit_on_project_requests?).returns(true)
    assert user.allow_project_requests_for_role?(role)
  end

  def test_get_memberships_of_open_or_proposed_groups_with_role
    role = programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME)
    users_array = [users(:pbe_mentor_1), users(:f_student_pbe), users(:f_mentor_pbe)]
    User.where(id: users_array.collect(&:id)).includes(connection_memberships: [:group, :role]).each do |user|
      memberships = user.connection_memberships.of_open_or_proposed_groups.with_role(role).to_a
      assert_equal_unordered memberships, user.get_memberships_of_open_or_proposed_groups_with_role(role).to_a
      assert_equal_unordered memberships, users_array.find{ |u| u.id == user.id }.get_memberships_of_open_or_proposed_groups_with_role(role).to_a
    end
  end

  def test_get_active_sent_project_requests_for_role
    role = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME)
    users_array = [users(:pbe_student_1), users(:pbe_student_2), users(:pbe_student_3)]
    User.where(id: users_array.collect(&:id)).includes(:sent_project_requests).each do |user|
      sent_active_request_for_role = user.sent_project_requests.active.with_role(role).to_a
      assert_equal_unordered sent_active_request_for_role, user.get_active_sent_project_requests_for_role(role).to_a
      assert_equal_unordered sent_active_request_for_role, users_array.find{ |u| u.id == user.id }.get_active_sent_project_requests_for_role(role).to_a
    end
  end

  def test_allow_to_propose_groups
    user = users(:f_admin)
    user.expects(:roles_for_proposing_groups).returns([])
    assert_false user.allow_to_propose_groups?
    user.expects(:roles_for_proposing_groups).returns([1])
    assert user.allow_to_propose_groups?
  end

  def test_roles_for_proposing_groups
    user = users(:f_mentor_pbe)
    program = programs(:pbe)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentor_role.remove_permission(RolePermission::PROPOSE_GROUPS)

    assert_equal [RoleConstants::MENTOR_NAME], user.roles.for_mentoring.pluck(:name)

    assert_equal [], user.roles_for_proposing_groups
    mentor_role.add_permission(RolePermission::PROPOSE_GROUPS)
    mentor_role.reload
    assert_equal [mentor_role], user.reload.roles_for_proposing_groups
    mentor_role.update_column(:max_connections_limit, 0)
    assert_empty user.reload.roles_for_sending_project_request
  end

  def test_can_view_preferece_based_mentor_lists
    user = users(:f_admin)
    program = user.program

    program.stubs(:preferece_based_mentor_lists_enabled?).returns(true)
    assert_false user.can_view_preferece_based_mentor_lists?

    user.stubs(:can_send_mentor_request?).returns(true)
    assert user.can_view_preferece_based_mentor_lists?

    user.stubs(:can_send_mentor_request?).returns(false)
    program.stubs(:calendar_enabled?).returns(true)
    assert_false user.can_view_preferece_based_mentor_lists?

    user.stubs(:is_student?).returns(true)
    assert user.can_view_preferece_based_mentor_lists?

    program.stubs(:preferece_based_mentor_lists_enabled?).returns(false)
    assert_false user.can_view_preferece_based_mentor_lists?
  end

  private

  def create_education_answers(user, question, options_array)
    answer = user.member.profile_answers.build(profile_question: question)
    options_array.each do |options|
      answer.educations.build(options) do |ed|
        ed.profile_answer = answer
      end
    end
    answer.save!
  end

  def create_experience_answers(user, question, options_array)
    answer = user.member.profile_answers.build(profile_question: question)
    options_array.each do |options|
      answer.experiences.build(options) do |ed|
        ed.profile_answer = answer
      end
    end
    answer.save!
  end
end