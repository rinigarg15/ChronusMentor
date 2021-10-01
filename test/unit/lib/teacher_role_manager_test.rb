require_relative "./../../test_helper.rb"

class TeacherRoleManagerTest < ActiveSupport::TestCase

  def test_create
    program = programs(:albers)
    default_views = program.admin_views.where(default_view: TeacherRoleManager::DEFAULT_VIEWS_TO_UPDATE)
    assert_false default_views.any? { |default_view| default_view.filter_params_hash["roles_and_status"]["role_filter_1"]["roles"].include?(RoleConstants::TEACHER_NAME) }

    assert_difference "RoleQuestion.count", 2 do
      assert_difference "Role.count" do
        assert TeacherRoleManager.new(program).create_third_role
      end
    end
    program.reload
    teacher_role = program.find_role(RoleConstants::TEACHER_NAME)
    assert_equal true, teacher_role.for_mentoring
    new_role_permissions = [
      "view_teachers",
      "write_article",
      "view_articles",
      "answer_question",
      "view_students",
      "view_mentors",
      "view_ra",
      "view_find_new_projects",
      "ask_question",
      "follow_question",
      "rate_answer",
      "set_availability",
      "view_questions"
    ]
    assert_equal_unordered new_role_permissions, teacher_role.permission_names
    assert program.roles.all? { |role| role.has_permission_name?("view_teachers") }
    assert default_views.reload.all? { |default_view| default_view.filter_params_hash["roles_and_status"]["role_filter_1"]["roles"].include?(RoleConstants::TEACHER_NAME) }
  end

  def test_remove
    program = programs(:albers)
    role_names = program.roles.pluck(:name)
    default_views = program.admin_views.where(default_view: TeacherRoleManager::DEFAULT_VIEWS_TO_UPDATE)
    non_editable_default_views = default_views.select { |default_view| !default_view.editable? }

    assert_no_difference "RoleQuestion.count" do
      assert_no_difference "Role.count" do
        assert_no_difference "RolePermission.count" do
          assert_no_difference "ObjectRolePermission.count" do
            teacher_role_manager = TeacherRoleManager.new(program)
            teacher_role_manager.create_third_role
            default_views.select(&:editable?).each do |default_view|
              yaml_params = default_view.filter_params_hash
              yaml_params[:roles_and_status][:role_filter_1] = { type: :include, roles: role_names }
              default_view.filter_params = AdminView.convert_to_yaml(yaml_params)
              default_view.save!
            end
            assert teacher_role_manager.remove_third_role
          end
        end
      end
    end
    assert non_editable_default_views.all? { |default_view| default_view.filter_params_hash["roles_and_status"]["role_filter_1"]["roles"].exclude?(RoleConstants::TEACHER_NAME) }
  end
end