require_relative './../../../../../../test_helper'

class MemberPopulatorTest < ActiveSupport::TestCase

  def test_add_remove_members
    @organization = programs(:org_primary)
    @chronus_auth = @organization.chronus_auth
    member = MemberPopulator.new("member", { parent: "organization", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1] } )
    count = 5

    assert_members_count count do
      member.add_members(@organization.id, count, status: "Member::Status::ACTIVE")
    end
    assert_equal [Member::Status::ACTIVE], @organization.members.last(count).collect(&:state).uniq

    populator_object_save!(@organization.members.last)
    assert_members_count(-(count)) do
      member.remove_members(@organization.id, count, status: "Member::Status::ACTIVE")
    end

    assert_members_count count do
      member.add_members(@organization.id, count, status: "Member::Status::DORMANT")
    end
    assert_equal [Member::Status::DORMANT], @organization.members.last(count).collect(&:state).uniq

    populator_object_save!(@organization.members.last)
    assert_members_count(-(count)) do
      member.remove_members(@organization.id, count, status: "Member::Status::DORMANT")
    end
  end

  private

  def assert_members_count(count)
    assert_difference "@organization.members.count", count do
      assert_difference "@chronus_auth.login_identifiers.count", count do
        yield
      end
    end
  end
end