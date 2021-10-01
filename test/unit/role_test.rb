require_relative './../test_helper.rb'

class RoleTest < ActiveSupport::TestCase
  def setup
    super
    @role = create_role(:name => 'test_role')
  end

  def test_create_name_and_program_required
    assert_no_difference 'Role.count' do
      assert_multiple_errors([{:field => :program}, {:field => :name}]) do
        Role.create!
      end
    end
  end

  def test_create_success
    assert_difference 'Role.count' do
      assert_nothing_raised do
        @some_role = Role.create!(:name => 'new_role', :program => programs(:albers))
      end
    end

    assert_equal 'new_role', @some_role.name
    assert_equal programs(:albers), @some_role.program
  end

  def test_has_one_admin_view_dependent_destroy
    mentor_role = Role.create!(:name => 'new_role', :program => programs(:albers))
    mentor_admin_view = AdminView.create(title: "brand_new_title", description: "brand_new_desc", role_id: mentor_role.id)
    mentor_role.destroy
    assert_raise ActiveRecord::RecordNotFound do
      mentor_admin_view.reload
    end
  end

  def test_validate_name_must_be_in_underscore_lowercase_format
    assert_no_difference 'Role.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :name, "is invalid" do
        Role.create!(:name => 'General Manager', :program => programs(:albers))
        Role.create!(:name => 'general manager', :program => programs(:albers))
        Role.create!(:name => 'general_Manager', :program => programs(:albers))
      end
    end
  end

  def test_validate_name_is_unique_within_program
    Role.create!(:name => 'new_role', :program => programs(:albers))
    assert_no_difference 'Role.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :program, "already has the role" do
        Role.create!(:name => 'new_role', :program => programs(:albers))
      end
    end

    assert_difference 'Role.count' do
      assert_nothing_raised do
        @some_role = Role.create!(:name => 'new_role', :program => programs(:ceg))
      end
    end

    assert_equal 'new_role', @some_role.name
    assert_equal programs(:ceg), @some_role.program
  end

  def test_allowed_enrollment_options
    role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    [:join_directly, :membership_request, :join_directly_only_with_sso, :eligibility_rules].each do |col|
      role.send((col.to_s + "=").to_sym, false)
      assert_false role.allowed_enrollment_options.include?(col)
      role.send((col.to_s + "=").to_sym, true)
      assert role.allowed_enrollment_options.include?(col)
    end
    role.program.roles_without_admin_role.each do |r|
      assert_false role.allowed_enrollment_options.include?(:invitation)
    end
    [:join_directly, :membership_request, :join_directly_only_with_sso, :eligibility_rules].each { |col| role.send((col.to_s + "=").to_sym, false) }
    assert role.allowed_enrollment_options.include?(:invitation)
  end

  def test_has_many_permissions
    assert @role.permissions.empty?
    p_1 = create_permission('view_emails')
    p_2 = create_permission('delete_emails')

    assert_difference '@role.permissions.reload.count', 2 do
      @role.permissions << p_1
      @role.permissions << p_2
    end

    assert_equal [p_1, p_2], @role.permissions
  end

  def test_has_many_users
    user_1 = create_user
    create_user(:name => 'hello world')
    user_3 = create_user(:name => 'indo american')
    role_1 = create_role(:name => 'manager', :program => programs(:albers))
    programs(:albers).roles.reload
    assert role_1.users.empty?
    user_1.add_role('manager')
    user_3.add_role('manager')
    assert_equal [user_1, user_3], role_1.users.reload
    assert_equal_unordered programs(:albers).student_users, fetch_role(:albers, :student).users
  end

  def test_with_name_scope
    assert Role.with_name('hello').empty?
    r1 = create_role(:name => 'hello')
    r2 = create_role(:name => 'world')

    assert_equal [r1], Role.with_name('hello')
    assert_equal [r1, r2], Role.with_name(['hello', 'world'])
  end

  def test_add_permission
    r1 = fetch_role(:ceg, :admin)
    assert_false r1.permission_names.include?("send_mentor_request")
    assert_false r1.has_permission_name?("send_mentor_request")

    assert_difference "RolePermission.count" do
      r1.add_permission("send_mentor_request")
    end
    assert r1.permission_names.include?("send_mentor_request")
    assert r1.has_permission_name?("send_mentor_request")

    assert_no_difference "RolePermission.count" do
      r1.add_permission("send_mentor_request")
    end
  end

  def test_remove_permission
    r1 = fetch_role(:ceg, :admin)
    assert_false r1.permission_names.include?("send_mentor_request")
    assert_false r1.has_permission_name?("send_mentor_request")

    assert_no_difference "RolePermission.count" do
      r1.remove_permission("send_mentor_request")
    end

    r1.add_permission("send_mentor_request")
    assert r1.permission_names.include?("send_mentor_request")
    assert r1.has_permission_name?("send_mentor_request")

    assert_difference "RolePermission.count", -1 do
      r1.remove_permission("send_mentor_request")
    end
  end

  def test_can_invite_role
    role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    assert role.has_permission_name?('invite_mentors')
    assert role.can_invite_role?(RoleConstants::MENTOR_NAME)
    role.remove_permission('invite_mentors')
    assert_false role.can_invite_role?(RoleConstants::MENTOR_NAME)
  end

  def test_update_role_join_settings
    role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    assert_false role.join_directly?
    assert role.membership_request?
    assert_false role.join_directly_only_with_sso?
    join_settings = [RoleConstants::JoinSetting::MEMBERSHIP_REQUEST]
    role.update_role_join_settings!(join_settings)
    assert_false role.join_directly?
    assert role.membership_request?
    assert_false role.join_directly_only_with_sso?
    join_settings = [RoleConstants::JoinSetting::JOIN_DIRECTLY_ONLY_WITH_SSO]
    role.update_role_join_settings!(join_settings)
    assert_false role.join_directly?
    assert_false role.membership_request?
    assert role.join_directly_only_with_sso?
  end

  def test_allowing_membership_request
    p = programs(:albers)
    assert_equal p.roles.allowing_membership_request.count, 2
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.save
    assert_equal p.roles.allowing_membership_request.count, 1
  end

  def test_allowing_join_directly
    p = programs(:albers)
    assert_equal p.roles.allowing_join_directly.count, 0
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.join_directly = true
    mentor_role.save
    assert_equal p.roles.allowing_join_directly.count, 1
  end

  def test_allowing_join_directly_only_with_sso
    p = programs(:albers)
    assert_equal p.roles.allowing_join_directly_only_with_sso.count, 0
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert_equal p.roles.allowing_join_directly_only_with_sso.count, 1
  end

  def test_allowing_join_directly_or_join_directly_only_with_sso
    p = programs(:albers)
    assert_equal p.roles.allowing_join_directly_or_join_directly_only_with_sso.count, 0
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.join_directly_only_with_sso = true
    mentor_role.save
    assert_equal p.roles.allowing_join_directly_or_join_directly_only_with_sso.count, 1
    student_role = p.find_role(RoleConstants::STUDENT_NAME)
    student_role.membership_request = false
    student_role.join_directly = true
    student_role.save
    assert_equal p.roles.allowing_join_directly_or_join_directly_only_with_sso.count, 2
  end

  def test_allowing_invitation
    p = programs(:albers)
    assert_equal 3, p.roles.allowing_invitation.count
    mentor_role = p.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.invitation = false
    mentor_role.save
    assert_equal 2, p.roles.allowing_invitation.count
  end

  def test_default
    p = programs(:albers)
    default_roles = p.roles.default.collect(&:name)
    assert_equal default_roles.count , 3
    assert default_roles.include?(RoleConstants::MENTOR_NAME)
    assert default_roles.include?(RoleConstants::STUDENT_NAME)
    assert default_roles.include?(RoleConstants::ADMIN_NAME)
  end

  def test_is_default
    p = programs(:albers)
    admin = p.roles.find_by(name: "admin")
    assert admin.is_default?
    mentor = p.roles.find_by(name: "mentor")
		assert mentor.is_default?

    p = programs(:pbe)
    teacher = p.roles.find_by(name: "teacher")
    assert_false teacher.is_default?

    p = programs(:primary_portal)
    employee = p.roles.find_by(name: "employee")
    assert employee.is_default?
  end

  def test_employee_role_should_be_default_role
  	p = programs(:primary_portal)
    employee = p.roles.find_by(name: "employee")
    assert employee.is_default?
  end

  def test_non_default
    p = programs(:albers)
    assert_equal p.roles.non_default.count, 2
    assert p.roles.non_default.include?(p.find_role('test_role'))
    assert p.roles.non_default.include?(p.find_role('user'))
  end

  def test_administrative
    p = programs(:albers)
    r1 = Role.create!(name: "queen", program: p, administrative: true)
    r2 = Role.create!(name: "king", program: p)
    assert p.roles.administrative.include?(r1)
    assert_false p.roles.administrative.include?(r2)
  end

  def test_non_administrative
    p = programs(:albers)
    r1 = Role.create!(name: "queen", program: p, administrative: true)
    r2 = Role.create!(name: "king", program: p)
    assert p.roles.non_administrative.pluck(:id).include?(r2.id)
    assert_false p.roles.non_administrative.pluck(:id).include?(r1.id)
  end

  def test_of_member
    member1 = members(:f_mentor_student)
    users_of_member1 = member1.users
    assert_equal 1, users_of_member1.size
    assert_equal_unordered users_of_member1.first.roles, Role.of_member(member1)

    member2 = members(:f_student)
    users_of_member2 = member2.users
    assert_equal 3, users_of_member2.size
    assert_equal_unordered users_of_member2.collect(&:role_ids).flatten, Role.of_member(member2).collect(&:id)
  end

  def test_mentor_and_mentee_and_admin
    assert programs(:albers).find_role(RoleConstants::MENTOR_NAME).mentor?
    assert programs(:albers).find_role(RoleConstants::STUDENT_NAME).mentee?
    assert_false programs(:albers).find_role(RoleConstants::MENTOR_NAME).mentee?
    assert_false programs(:albers).find_role(RoleConstants::STUDENT_NAME).mentor?
    assert programs(:albers).find_role(RoleConstants::ADMIN_NAME).admin?
    assert_false programs(:albers).find_role(RoleConstants::MENTOR_NAME).admin?
    assert_false programs(:albers).find_role(RoleConstants::STUDENT_NAME).admin?
  end

  def test_slot_config_required
    student_role = fetch_role(:pbe, RoleConstants::STUDENT_NAME)
    assert_false student_role.slot_config_required?

    student_role.slot_config = RoleConstants::SlotConfig::REQUIRED
    assert student_role.slot_config_required?

    student_role.slot_config = nil
    assert_false student_role.slot_config_required?
  end

  def test_slot_config_optional
    student_role = fetch_role(:pbe, RoleConstants::STUDENT_NAME)
    assert student_role.slot_config_optional?

    student_role.slot_config = RoleConstants::SlotConfig::REQUIRED
    assert_false student_role.slot_config_optional?

    student_role.slot_config = nil
    assert_false student_role.slot_config_optional?
  end

  def test_slot_config_enabled
    student_role = fetch_role(:pbe, RoleConstants::STUDENT_NAME)
    assert student_role.slot_config_enabled?

    student_role.slot_config = RoleConstants::SlotConfig::REQUIRED
    assert student_role.slot_config_enabled?

    student_role.slot_config = nil
    assert_false student_role.slot_config_enabled?
  end

  def test_with_permission_name
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::ADMIN_NAME], programs(:albers).roles.with_permission_name('invite_mentors').collect(&:name)
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME], programs(:albers).roles.with_permission_name('rate_answer').collect(&:name)
    assert_equal_unordered [RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME], programs(:albers).roles.with_permission_name('invite_students').collect(&:name)
    assert_equal_unordered [RoleConstants::ADMIN_NAME], programs(:albers).roles.with_permission_name('manage_connections').collect(&:name)

    student_role = fetch_role(:albers, :student)
    student_role.remove_permission("invite_students")
    assert_equal_unordered [RoleConstants::ADMIN_NAME], programs(:albers).roles.with_permission_name('invite_students').collect(&:name)

    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::ADMIN_NAME], programs(:org_primary).roles.with_permission_name('invite_mentors').collect(&:name).uniq
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME], programs(:org_primary).roles.with_permission_name('rate_answer').collect(&:name).uniq
    assert_equal_unordered [RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME], programs(:org_primary).roles.with_permission_name('invite_students').collect(&:name).uniq
    assert_equal_unordered [RoleConstants::ADMIN_NAME], programs(:org_primary).roles.with_permission_name('manage_connections').collect(&:name).uniq
  end

  def test_set_default_customized_term
    role = programs(:albers).roles.create(:name => 'new_role')
    CustomizedTerm.destroy_all
    role.reload

    assert_difference 'CustomizedTerm.count', 1 do
      role.set_default_customized_term
    end
    assert_equal 'New role', role.customized_term.term

    assert_no_difference 'CustomizedTerm.count' do
      role.set_default_customized_term
    end

    student_role = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME)
    assert_difference 'CustomizedTerm.count', 1 do
      student_role.set_default_customized_term
    end
    assert_equal RoleConstants::DEFAULT_CUSTOMIZED_TERMS_MAPPING[RoleConstants::STUDENT_NAME], student_role.customized_term.term

    role = programs(:albers).roles.create(:name => 'trainer')
    role.base_term = 'basetrainer'
    CustomizedTerm.destroy_all
    role.reload
    assert_difference 'CustomizedTerm.count', 1 do
      role.set_default_customized_term
    end
    assert_equal 'basetrainer', role.customized_term.term
  end

  def test_role_with_for_mentoring
    program = programs(:albers)
    program.roles.where(name: RoleConstants::MENTORING_ROLES).destroy_all
    role = program.roles.new(name: RoleConstants::MENTOR_NAME, administrative: false)
    assert_false role.valid?
    assert_false role.for_mentoring?
    assert_equal ["can't be blank"], role.errors[:for_mentoring]
    role.for_mentoring = true
    assert role.valid?
    role = program.roles.new(name: RoleConstants::STUDENT_NAME, administrative: false)
    assert_false role.valid?
    assert_false role.for_mentoring?
    assert_equal ["can't be blank"], role.errors[:for_mentoring]
    role.for_mentoring = true
    assert role.valid?
  end

  def test_has_many_connection_memberships
    program = programs(:albers)
    mentor_role = program.roles.where(name: RoleConstants::MENTOR_NAME).first
    student_role = program.roles.where(name: RoleConstants::STUDENT_NAME).first
    mentor_memberships = program.connection_memberships.where(type: Connection::MentorMembership.name)
    student_memberships = program.connection_memberships.where(type: Connection::MenteeMembership.name)

    assert_equal (mentor_memberships.size+student_memberships.size), program.connection_memberships.size
    assert_equal_unordered program.groups.collect(&:memberships).flatten, program.connection_memberships
  end

  def test_for_mentoring
    for_mentoring_roles = Role.for_mentoring.collect(&:name).uniq
    new_role_name = "walter_skyler_white"
    create_role(name: new_role_name, for_mentoring: true)
    assert_equal for_mentoring_roles + [new_role_name], Role.for_mentoring.collect(&:name).uniq
  end

  def test_for_mentoring_models
    for_mentoring_roles = Role.for_mentoring.collect(&:name).uniq
    for_mentoring_model_roles = Role.for_mentoring_models.collect(&:name).uniq
    new_role_name = "walter_skyler_white"
    create_role(name: new_role_name, for_mentoring: true)
    assert_equal_unordered for_mentoring_roles + [new_role_name], Role.for_mentoring.collect(&:name).uniq
    assert_equal_unordered for_mentoring_model_roles + [new_role_name], Role.for_mentoring_models.collect(&:name).uniq
  end

  def test_get_signup_options
    organization = programs(:org_primary)
    program = programs(:albers)
    roles = program.roles.allowing_join_now
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    indigenous_auths = organization.auth_configs.where(auth_type: AuthConfig::Type::CHRONUS)
    non_indignenous_auth = organization.auth_configs.create!(auth_type: AuthConfig::Type::OPENSSL)
    non_indignenous_auths = [non_indignenous_auth]

    program.roles.all? { |role| role.membership_request? }
    assert_equal organization.auth_configs, Role.get_signup_options(program, roles)
    mentor_role.update_attributes!(membership_request: false, join_directly: true)
    assert_equal organization.auth_configs, Role.get_signup_options(program, roles)
    mentor_role.update_attributes!(membership_request: false, join_directly: false, join_directly_only_with_sso: true)
    assert_equal organization.auth_configs, Role.get_signup_options(program, roles)
    assert_equal non_indignenous_auths, Role.get_signup_options(program, [mentor_role])
  end

  def test_can_member_modify_eligibility_details
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    prof_ques1 = organization.profile_questions.find_by(question_text: "Work")
    prof_ques2 = organization.profile_questions.find_by(question_text: "Education")
    prof_ques3 = organization.profile_questions.find_by(question_text: "Phone")

    prof_ques1.role_questions.find_by({role_id: role.id}).update_attributes(admin_only_editable: true)
    prof_ques2.role_questions.find_by({role_id: role.id}).update_attributes(admin_only_editable: true)
    prof_ques3.role_questions.find_by({role_id: role.id}).update_attributes(admin_only_editable: true)

    admin_view = AdminView.create!(:program => program.organization, role_id: role.id, :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :profile => {:questions => {
                      :question_1 => {:question => prof_ques1.id, :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""},
                      :question_2 => {:question => prof_ques2.id, :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""},
                      :question_3 => {:question => prof_ques3.id, :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}
                     }},
    }))

    assert_false role.can_member_modify_eligibility_details?
    prof_ques2.role_questions.find_by({role_id: role.id}).update_attributes(admin_only_editable: false)
    assert role.can_member_modify_eligibility_details?
  end

  def test_can_member_modify_eligibility_details_not_effected_by_role_questions_not_present
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    prof_ques1 = organization.profile_questions.find_by(question_text: "Work")
    prof_ques2 = organization.profile_questions.find_by(question_text: "Education")
    prof_ques3 = organization.profile_questions.find_by(question_text: "Phone")

    prof_ques1.role_questions.find_by({role_id: role.id}).update_attributes(admin_only_editable: true)
    prof_ques2.role_questions.find_by({role_id: role.id}).destroy
    prof_ques3.role_questions.find_by({role_id: role.id}).update_attributes(admin_only_editable: true)

    admin_view = AdminView.create!(:program => program.organization, role_id: role.id, :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :profile => {:questions => {
                      :question_1 => {:question => prof_ques1.id, :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""},
                      :question_2 => {:question => prof_ques2.id, :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""},
                      :question_3 => {:question => prof_ques3.id, :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}
                     }},
    }))

    assert_false role.can_member_modify_eligibility_details?
    prof_ques1.role_questions.find_by({role_id: role.id}).update_attributes(admin_only_editable: false)
    assert role.can_member_modify_eligibility_details?
  end

  def test_translated_fields
    @role.description = "globalized role"
    @role.eligibility_message = "globalized eligibility message"
    Globalize.with_locale(:en) do
      @role.description = "english description"
      @role.eligibility_message = "english eligibility message"
      @role.save!
    end
    Globalize.with_locale(:"fr-CA") do
      @role.description = "french description"
      @role.eligibility_message = "french eligibility message"
      @role.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english description", @role.description
      assert_equal "english eligibility message", @role.eligibility_message
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french description", @role.description
      assert_equal "french eligibility message", @role.eligibility_message
    end
  end

  def test_add_default_questions_for
    role = Role.create(:name => 'new_role', :program => programs(:albers))

    role.role_questions.delete_all
    assert_difference "RoleQuestion.count", 2 do
      role.add_default_questions_for
    end

    assert_equal_unordered [ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::NAME], role.reload.role_questions.collect(&:profile_question).collect(&:question_type)
  end

  def test_populate_content_for_language
    organization = programs(:org_primary)
    non_admin_roles_count = Role.where(program_id: organization.program_ids, administrative: false).count
    Role.any_instance.expects(:populate_description_with_default_value_if_nil).with([:es]).times(non_admin_roles_count).returns(nil)
    Role.populate_content_for_language(organization, :es)
  end

  def test_get_role_translation_term
    assert_equal "mentee", Role.get_role_translation_term("student")
    assert_equal "mentor", Role.get_role_translation_term("mentor")
    assert_equal "king", Role.get_role_translation_term("king")
  end

  def test_populate_description_with_default_value_if_nil
    program = programs(:albers)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    mentor_role.customized_term.save_term('Test Guru', CustomizedTerm::TermType::ROLE_TERM)
    student_role.customized_term.save_term('Test Shishya', CustomizedTerm::TermType::ROLE_TERM)
    mentor_role.translations.destroy_all
    mentor_role.reload
    mentor_role.populate_description_with_default_value_if_nil([:en])

    assert_equal mentor_role.translations.size, 1
    assert_equal mentor_role.description, "Test Gurus are professionals who guide and advise test shishyas in their career paths to help them succeed. A test guru's role is to inspire, encourage, and support their test shishyas."

    student_role.translations.destroy_all
    student_role.reload
    student_role.populate_description_with_default_value_if_nil([:en])

    assert_equal student_role.translations.size, 1
    assert_equal student_role.description, "Test Shishyas are students who want guidance and advice to further their careers and to be successful. Test Shishyas can expect to strengthen and build their networks, and gain the skills and confidence necessary to excel."


    portal = programs(:primary_portal)
    employee_role = portal.roles.find_by(name: RoleConstants::EMPLOYEE_NAME)
    employee_role.customized_term.save_term('Test Worker', CustomizedTerm::TermType::ROLE_TERM)


    employee_role.translations.destroy_all
    employee_role.reload
    employee_role.populate_description_with_default_value_if_nil([:en])

    assert_equal employee_role.translations.size, 1
    assert_equal employee_role.description, "Test Workers can setup their career goals, create plans, and track their progress towards archiving the goals in the Career Development Program."

    employee_role.populate_description_with_default_value_if_nil([:en])

    program
    assert_equal employee_role.translations.size, 1
    assert_equal employee_role.description, "Test Workers can setup their career goals, create plans, and track their progress towards archiving the goals in the Career Development Program."
  end

  def test_project_requests
    program = programs(:pbe)
    mentor_role = programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME)
    assert_equal 0, mentor_role.project_requests.count
    assert_equal 10, student_role.project_requests.count
    user = users(:f_mentor_pbe)
    ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_mentor_pbe).id, group_id: groups(:group_pbe_1).id, sender_role_id: mentor_role.id)
    mentor_role.reload
    assert_equal 1, mentor_role.project_requests.count
  end

  def test_can_be_removed
    program = programs(:pbe)
    role = program.get_role(RoleConstants::TEACHER_NAME)
    assert_false role.can_be_removed?
    program.teacher_users.destroy_all
    assert role.can_be_removed?
    admin_view = program.admin_views.find_by(default_view: [nil, AdminView::EDITABLE_DEFAULT_VIEWS].flatten)
    filter_params_hash = admin_view.filter_params_hash
    filter_params_hash[:roles_and_status][:role_filter_1][:roles] << RoleConstants::TEACHER_NAME
    admin_view.update_attributes!(filter_params: filter_params_hash.to_yaml)
    assert_false role.can_be_removed?
    filter_params_hash[:roles_and_status][:role_filter_1][:roles] = ["admin"]
    admin_view.update_attributes!(filter_params: filter_params_hash.to_yaml)
    assert role.can_be_removed?
    forum = create_forum(access_role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, RoleConstants::TEACHER_NAME], program: program)
    assert_false role.can_be_removed?
    forum.destroy
    assert role.can_be_removed?
  end

  def test_editable_associated_admin_views
    program = programs(:pbe)
    role = program.get_role(RoleConstants::TEACHER_NAME)
    assert role.editable_associated_admin_views.blank?
    admin_view = program.admin_views.find_by(default_view: [nil, AdminView::EDITABLE_DEFAULT_VIEWS].flatten)
    filter_params_hash = admin_view.filter_params_hash
    filter_params_hash[:roles_and_status][:role_filter_1][:roles] << RoleConstants::TEACHER_NAME
    admin_view.update_attributes!(filter_params: filter_params_hash.to_yaml)
    assert_equal [admin_view], role.editable_associated_admin_views
    org_admin_view = program.organization.admin_views.first
    filter_params_hash = org_admin_view.filter_params_hash
    filter_params_hash[:program_roles] = ["#{role.id}"]
    org_admin_view.update_attributes!(filter_params: filter_params_hash.to_yaml)
    assert_equal_unordered [org_admin_view, admin_view], role.reload.editable_associated_admin_views
  end

  def test_no_limit_on_project_requests
    role = Role.first
    role.update_attributes!(max_connections_limit: nil)
    assert role.no_limit_on_project_requests?
    role.update_attributes!(max_connections_limit: 1)
    assert_false role.no_limit_on_project_requests?
  end

  def test_validate_max_connections_limit
    role = Role.first
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :max_connections_limit, "must be greater than 0" do
      role.update_attributes!(max_connections_limit: 0)
    end
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :max_connections_limit, "must be greater than 0" do
      role.update_attributes!(max_connections_limit: -1)
    end
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :max_connections_limit, "is not a number" do
      role.update_attributes!(max_connections_limit: "a")
    end
    role.update_attributes!(max_connections_limit: 5)
    role.update_attributes!(max_connections_limit: nil)
  end

end