require_relative './../../test_helper.rb'

class Group::MembershipSettingTest < ActiveSupport::TestCase

  def setup
    super
    @program = programs(:albers)
    @group = @program.groups.first
  end

  def test_assoc_belongs_to_group_and_role
    role = @program.get_role(RoleConstants::STUDENT_NAME)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [@group.id])

    membership_setting = Group::MembershipSetting.create(:role_id => role.id, :group_id => @group.id, :max_limit => 6)
    assert membership_setting.present?
    assert_equal membership_setting.group, @group
    assert_equal @group.membership_settings.find_by(role_id: role.id), membership_setting
    assert_equal membership_setting.role, role
    assert_equal role.group_settings.find_by(group_id: @group.id), membership_setting

    membership_setting.group_id = 3
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [3])
    membership_setting.max_limit = 10
    membership_setting.save
  end

  def test_validate_presence_and_group_and_role_uniqueness
    role = @program.get_role(RoleConstants::STUDENT_NAME)

    membership_setting_1 = Group::MembershipSetting.create(:role_id => role.id, :group_id => @group.id, max_limit: 6)
    assert membership_setting_1.valid?

    #role uniqueness validation
    membership_setting_2 = Group::MembershipSetting.create(:role_id => role.id, :group_id => @group.id, :max_limit => 12)

    assert membership_setting_1.valid?
    assert_false membership_setting_2.valid?

    #numeric validations
    membership_setting_1.max_limit = 0
    assert_false membership_setting_1.valid?
    assert_equal "must be greater than 0", membership_setting_1.errors[:max_limit].first
    membership_setting_1.max_limit = "sample"
    assert_false membership_setting_1.valid?
    assert_equal "is not a number", membership_setting_1.errors[:max_limit].first

    # Allow nil
    membership_setting_1.max_limit = nil
    assert membership_setting_1.valid?
  end

  def test_validate_group_and_role_program
    program_1 = @program
    program_2 = programs(:nwen)
    group_1 = program_1.groups.first
    role_1 = program_1.get_role(RoleConstants::STUDENT_NAME)
    group_2 = program_2.groups.first
    role_2 = program_2.get_role(RoleConstants::STUDENT_NAME)

    membership_setting_1 = Group::MembershipSetting.create(:role_id => role_1.id, :group_id => group_1.id, :max_limit => 6)
    membership_setting_2 = Group::MembershipSetting.create(:role_id => role_1.id, :group_id => group_2.id, :max_limit => 12)

    membership_setting_3 = Group::MembershipSetting.create(:role_id => role_2.id, :group_id => group_1.id, :max_limit => 6)
    membership_setting_4 = Group::MembershipSetting.create(:role_id => role_2.id, :group_id => group_2.id, :max_limit => 12)

    assert membership_setting_1.valid?
    assert_false membership_setting_2.valid?
    assert_false membership_setting_3.valid?
    assert membership_setting_4.valid?
  end

  def test_allow_join_validations
    role = @program.roles.for_mentoring.first

    membership_setting = @group.membership_settings.create!(role: role)
    assert membership_setting.valid?

    membership_setting.allow_join = false
    assert membership_setting.valid?

    membership_setting.allow_join = true
    assert_false membership_setting.valid?
  end

  def test_with_max_limit
    role = @program.roles.for_mentoring.first

    assert_equal 0, @group.membership_settings.size
    membership_setting = @group.membership_settings.create!(role: role)
    assert_equal 0, @group.membership_settings.with_max_limit.size
    membership_setting.update_attribute(:max_limit, 2)
    assert_equal 1, @group.membership_settings.with_max_limit.size
  end
end
