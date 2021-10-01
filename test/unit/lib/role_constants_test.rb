require_relative './../../test_helper.rb'

class RoleConstantsTest < ActiveSupport::TestCase
  def test_to_program_role_names
    program = programs(:albers)
    organization = program.organization
    setup_admin_custom_term
    program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute :term, 'Book'
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute :term, 'Car'
    program.roles.find_by(name: RoleConstants::ADMIN_NAME).customized_term.update_attribute :term, 'Bike'
    assert_equal ['Book'], RoleConstants.to_program_role_names(program, [RoleConstants::MENTOR_NAME])
    assert_equal ['Car'], RoleConstants.to_program_role_names(program, [RoleConstants::STUDENT_NAME])
    assert_equal ['Super Admin'], RoleConstants.to_program_role_names(program, [RoleConstants::ADMIN_NAME])
    assert_equal ['Super Admin', 'Book', 'Car'], RoleConstants.to_program_role_names(program, RoleConstants::DEFAULT_ROLE_NAMES)
  end

  def test_human_role_string
    assert_equal 'Mentor', RoleConstants.human_role_string(['mentor'])
    assert_equal 'Administrator and Mentor', RoleConstants.human_role_string(['administrator', 'mentor'])
    assert_equal 'Administrator, Mentor and Student', RoleConstants.human_role_string(['administrator', 'mentor', 'student'])
    assert_equal 'administrator, mentor and student', RoleConstants.human_role_string(['administrator', 'mentor', 'student'], no_capitalize: true)
    assert_equal 'administrators, mentors and students', RoleConstants.human_role_string(['administrator', 'mentor', 'student'], no_capitalize: true, pluralize: true)
    assert_equal 'Administrators, Mentors and Students', RoleConstants.human_role_string(['administrator', 'mentor', 'student'], pluralize: true)
    assert_equal 'an Administrator, Mentor and Student', RoleConstants.human_role_string(['administrator', 'mentor', 'student'], articleize: true)

    # No effect of articleizing when pluralized.
    assert_equal 'administrators, mentors and students', RoleConstants.human_role_string(['administrator', 'mentor', 'student'], no_capitalize: true, pluralize: true, articleize: true)
    assert_equal 'an administrator, mentor and student', RoleConstants.human_role_string(['administrator', 'mentor', 'student'], no_capitalize: true, articleize: true)
    assert_equal 'a mentor and administrator', RoleConstants.human_role_string(['mentor', 'administrator'], no_capitalize: true, articleize: true)
  end

  def test_human_role_string_with_program_names
    program = programs(:albers)
    organization = program.organization
    setup_admin_custom_term
    program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute :term, 'Apple'
    program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute :pluralized_term, 'Apples'
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute :term, 'Car'
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute :pluralized_term, 'Cars'
    assert_equal 'Apple', RoleConstants.human_role_string(['mentor'], program: program)
    assert_equal 'Car', RoleConstants.human_role_string(['student'], program: program)
    assert_equal 'Super Admin and Apple', RoleConstants.human_role_string(['admin', 'mentor'], program: program)
    assert_equal 'mentor', program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.term_downcase
    assert_equal 'super admin and mentor', RoleConstants.human_role_string(['admin', 'mentor'], program: program, no_capitalize: true)

    program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute :term_downcase, 'apple'
    assert_equal 'super admin and apple', RoleConstants.human_role_string(['admin', 'mentor'], program: program, no_capitalize: true)
    assert_equal 'Super Admins and Cars', RoleConstants.human_role_string(['admin', 'student'], program: program, pluralize: true)
    assert_equal 'a Super Admin and Car', RoleConstants.human_role_string(['admin', 'student'], program: program, articleize: true)
    assert_equal 'a Car and Super Admin', RoleConstants.human_role_string(['student', 'admin'], program: program, articleize: true)
  end

  def test_program_roles_mapping
    program = programs(:albers)
    organization = program.organization
    setup_admin_custom_term
    program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute :term, 'Book'
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute :term, 'Car'
    program.roles.find_by(name: RoleConstants::ADMIN_NAME).customized_term.update_attribute :term, 'Bike'

    role_mapping = RoleConstants.program_roles_mapping(programs(:albers))

    assert_equal_unordered  program.roles.collect(&:name), role_mapping.keys
    assert_equal 'Book', role_mapping[RoleConstants::MENTOR_NAME]
    assert_equal 'Car', role_mapping[RoleConstants::STUDENT_NAME]
    assert_equal 'Super Admin', role_mapping[RoleConstants::ADMIN_NAME]

    role_mapping = RoleConstants.program_roles_mapping(programs(:albers), roles: program.roles.for_mentoring)

    assert_not_equal program.roles.collect(&:name), role_mapping.keys
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], role_mapping.keys
    assert_equal 'Book', role_mapping[RoleConstants::MENTOR_NAME]
    assert_equal 'Car', role_mapping[RoleConstants::STUDENT_NAME]
    assert_nil role_mapping[RoleConstants::ADMIN_NAME]

    mentor_custom_term = program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term
    mentor_custom_term.update_attribute :pluralized_term, 'Books'
    mentor_custom_term.update_attribute :pluralized_term_downcase, 'books'
    mentor_custom_term.update_attribute :term_downcase, 'book'
    program.reload

    role_mapping = RoleConstants.program_roles_mapping(programs(:albers), pluralize: true)
    assert_equal 'Books', role_mapping[RoleConstants::MENTOR_NAME]
    assert_equal 'Super Admins', role_mapping[RoleConstants::ADMIN_NAME]

    role_mapping = RoleConstants.program_roles_mapping(programs(:albers), no_capitalize: true, pluralize: true)
    assert_equal 'books', role_mapping[RoleConstants::MENTOR_NAME]
    assert_equal 'super admins', role_mapping[RoleConstants::ADMIN_NAME]

    role_mapping = RoleConstants.program_roles_mapping(programs(:albers), no_capitalize: true)
    assert_equal 'book', role_mapping[RoleConstants::MENTOR_NAME]
    assert_equal 'super admin', role_mapping[RoleConstants::ADMIN_NAME]
  end

  def test_admin_can_manage_translation
    program = programs(:albers)
    assert program.admin_users.first.can_manage_translations?
  end

  def test_student_can_ignore_and_mark_favorite
    program = programs(:albers)
    assert program.student_users.first.can_ignore_and_mark_favorite?
  end
end
