require_relative './../test_helper.rb'

class PermissionTest < ActiveSupport::TestCase

  def setup
    super
    Permission.all_permissions = nil
  end

  def test_create_name_is_required
    assert_no_difference 'Permission.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :name do
        Permission.create!
      end
    end
  end

  def test_create_name_is_required_should_be_uniq
    Permission.create!(:name => 'add_themes')
    assert_no_difference 'Permission.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :name do
        Permission.create!(:name => 'add_themes')
      end
    end
  end

  def test_create_success    
    assert_difference 'Permission.count' do
      assert_nothing_raised do
        @permission = Permission.create!(:name => 'add_themes')
      end
    end

    assert_equal 'add_themes', @permission.name
  end

  def test_validate_name_must_be_in_underscore_lowercase_format
    assert_no_difference 'Permission.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :name, "is invalid" do
        Permission.create!(:name => 'Cross bridge')
        Permission.create!(:name => 'cross bridge')
        Permission.create!(:name => 'Cross')
      end
    end
  end

  def test_has_many_roles
    permission = create_permission('view_emails')
    assert permission.roles.empty?
    role_1 = create_role(:name => 'farmer')
    role_2 = create_role(:name => 'carpenter')

    assert_difference 'permission.roles.reload.count', 2 do
      permission.roles << role_1
      permission.roles << role_2
    end

    assert_equal [role_1, role_2], permission.roles
  end

  def test_create_default_permissions
    Permission.destroy_all
    assert_difference 'Permission.count', 63 do
      Permission.create_default_permissions
    end
  end

  def test_create_default_permissions_with_persmissions_present
    assert_no_difference 'Permission.count' do
      Permission.create_default_permissions
    end
  end

  def test_exists_with_name
    assert Permission.exists_with_name?('write_article')
    assert_false Permission.exists_with_name?('drink_water')
  end

  def test_create_permission_with_name
    assert_no_difference 'Permission.count' do
      Permission.create_permission!(RoleConstants::DEFAULT_PERMISSIONS.first)
    end

    assert_false Permission.exists_with_name?("view_actors")
    assert_difference 'Permission.count' do
      Permission.create_permission!("view_actors")
    end
    assert Permission.exists_with_name?("view_actors")
  end
end
