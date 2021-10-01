require_relative './../../../test_helper'

class ModelAuthTest < ActiveSupport::TestCase

  def test_authenticate
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary), ["user_name", "password"])
    assert_raise(ModelAuth::NotImplementedError) do
      ModelAuth.authenticate?(auth_obj, {})
    end
  end

  def test_validate_attributes_from_sso
    options = get_options

    auth_obj = ProgramSpecificAuth.new(programs(:org_primary), ["user_name", "password"])
    ModelAuth.validate_attributes_from_sso(auth_obj, options, { status: "Unpaid", student: "false" }.with_indifferent_access)
    assert auth_obj.has_data_validation
    assert auth_obj.is_data_valid
    assert_equal "Sorry Failed", auth_obj.permission_denied_message
    assert_false auth_obj.prioritize_validation

    auth_obj1 = ProgramSpecificAuth.new(programs(:org_primary), ["user_name2", "password2"])
    ModelAuth.validate_attributes_from_sso(auth_obj1, options, { status: "Unpaid", student: "true" }.with_indifferent_access)
    assert auth_obj1.has_data_validation
    assert_false auth_obj1.is_data_valid
    assert_equal "Sorry Failed", auth_obj1.permission_denied_message
    assert_false auth_obj1.prioritize_validation

    auth_obj2 = ProgramSpecificAuth.new(programs(:org_primary), ["user_name3", "password3"])
    ModelAuth.validate_attributes_from_sso(auth_obj2, options, { status: "Paid", student: "true" }.with_indifferent_access)
    assert auth_obj2.has_data_validation
    assert auth_obj2.is_data_valid
    assert_equal "Sorry Failed", auth_obj2.permission_denied_message
    assert_false auth_obj2.prioritize_validation

    auth_obj3 = ProgramSpecificAuth.new(programs(:org_primary), ["user_name3", "password3"])
    ModelAuth.validate_attributes_from_sso(auth_obj3, {}, { status: "Paid", student: "true" }.with_indifferent_access)
    assert_nil auth_obj3.has_data_validation
    assert_nil auth_obj3.is_data_valid
    assert_nil auth_obj3.permission_denied_message
    assert_false auth_obj3.prioritize_validation
  end

  private

  def get_options
    return {
      "validate" => {
        "criterias" => [
          {
            "criteria" => [
              {
                "attribute" => "status",
                "operator" => "eq",
                "value" => "Unpaid"
              },
              {
                "attribute" => "student",
                "operator" => "eq",
                "value" => "false"
              }
            ]
          },
          {
            "criteria" => [
              {
                "attribute" => "status",
                "operator" => "eq",
                "value" => "Paid"
              }
            ]
          }
        ],
        "fail_message" => "Sorry Failed",
        "prioritize" => false
      }
    }
  end
end