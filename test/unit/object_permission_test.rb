require_relative './../test_helper.rb'

class ObjectPermissionTest < ActiveSupport::TestCase
  def test_validations
    permission = ObjectPermission.new
    assert_false permission.save
    permission.name = "Carrie Mathison"
    assert permission.save

    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :name, "has already been taken") do
      ObjectPermission.create!(name: "Carrie Mathison")
    end

    assert_nothing_raised do
      ObjectPermission.create!(name: "Homeland")
    end
  end

  def test_create_default_permissions
    assert_equal ObjectPermission::MentoringModel::PERMISSIONS.count, ObjectPermission.count
    ObjectPermission.destroy_all

    assert_difference "ObjectPermission.count", ObjectPermission::MentoringModel::PERMISSIONS.count do
      ObjectPermission.create_default_permissions
    end

    assert_no_difference "ObjectPermission.count" do
      ObjectPermission.create_default_permissions
    end
  end

  def test_equality_admin_other_all_permissions
    assert_equal_unordered ObjectPermission::MentoringModel::PERMISSIONS, (ObjectPermission::MentoringModel::ADMIN_PERMISSIONS + ObjectPermission::MentoringModel::OTHER_USER_PERMISSIONS).uniq
  end
end
