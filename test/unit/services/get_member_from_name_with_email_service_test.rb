require_relative './../../test_helper.rb'

class GetMemberFromNameWithEmailServiceTest < ActiveSupport::TestCase
  def test_member
    service = GetMemberFromNameWithEmailService.new(members(:f_mentor).name, programs(:org_primary))
    assert_nil service.member

    service = GetMemberFromNameWithEmailService.new(members(:f_mentor).email, programs(:org_primary))
    assert_nil service.member

    service = GetMemberFromNameWithEmailService.new(members(:f_mentor).name_with_email, programs(:org_primary))
    assert_equal members(:f_mentor), service.member
  end

  def test_get_user
    service = GetMemberFromNameWithEmailService.new(members(:f_mentor).name, programs(:org_primary))
    assert_nil service.get_user(nil)
    assert_nil service.get_user(programs(:albers))

    service = GetMemberFromNameWithEmailService.new(members(:f_mentor).name_with_email, programs(:org_primary))
    assert_raise(NoMethodError) do
      service.get_user(nil)
    end
    assert_equal users(:f_mentor), service.get_user(programs(:albers))
    assert_equal users(:f_mentor), service.get_user(programs(:albers), RoleConstants::MENTOR_NAME)
    assert_nil service.get_user(programs(:albers), RoleConstants::STUDENT_NAME)
    assert_equal users(:f_mentor_nwen_student), service.get_user(programs(:nwen))
    assert_equal users(:f_onetime_mode_mentor), service.get_user(programs(:moderated_program))
  end
end