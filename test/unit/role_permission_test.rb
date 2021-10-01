require_relative './../test_helper.rb'

class RolePermissionTest < ActiveSupport::TestCase

  def test_validates_unique_ness
    p = Permission.create!(:name => "test_test")
    role = Role.create!(:name => "test", :program => programs(:albers))
    assert_difference "RolePermission.count" do
      RolePermission.create!(:role => role, :permission => p)
    end

    assert_no_difference "RolePermission.count" do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :permission_id do
        RolePermission.create!(:role => role, :permission => p)
      end
    end
  end
end
