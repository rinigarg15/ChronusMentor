require_relative './../../../test_helper.rb'

class Api::V2::BasePresenterTest < ActiveSupport::TestCase

  def test_get_valid_roles_should_return_correct_database_roles
    program = programs(:albers)
    roles_string = ["admin", "user", "director"]
    roles = []
    assert_equal roles, Api::V2::BasePresenter::RolesMapping.get_valid_roles(program, roles_string)

    roles_string = ["admin","user","student","mentor"]
    roles = ["admin", "user", "student", "mentor"]
    assert_equal roles, Api::V2::BasePresenter::RolesMapping.get_valid_roles(program, roles_string)
  end

end