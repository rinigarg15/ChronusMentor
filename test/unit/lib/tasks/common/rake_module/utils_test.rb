require_relative './../../../../../test_helper'

class Common::RakeModule::UtilsTest < ActiveSupport::TestCase

  def test_fetch_programs_and_organization
    assert_raise RuntimeError do
      Common::RakeModule::Utils.fetch_programs_and_organization("invalid-domain", "invalid-subdomain")
    end

    organization = programs(:org_primary)
    output_programs, output_organization = Common::RakeModule::Utils.fetch_programs_and_organization(organization.domain, organization.subdomain)
    assert_empty output_programs
    assert_equal organization, output_organization

    program = programs(:albers)
    program_2 = programs(:nwen)
    output_programs, output_organization = Common::RakeModule::Utils.fetch_programs_and_organization(organization.domain, organization.subdomain, "#{program_2.root},#{program.root}")
    assert_equal [program_2, program], output_programs
    assert_equal organization, output_organization

    assert_raise RuntimeError do
      Common::RakeModule::Utils.fetch_programs_and_organization(organization.domain, organization.subdomain, "invalid_root")
    end
  end
end