require_relative './../../test_helper.rb'

class Program::DomainTest < ActiveSupport::TestCase
  def test_create_success
    assert_difference "programs(:org_primary).program_domains.count" do
      organization = programs(:org_primary)
      pd = Program::Domain.new(:organization => programs(:org_primary))
      pd.is_default = false
      pd.subdomain = "blahblah"
      pd.save!
    end
  end

  def test_should_have_name_and_subdomain
    porg = Program::Domain.new
    assert_false porg.valid?

    assert_equal(["can't be blank"], porg.errors[:subdomain])
    assert_equal ["can't be blank"], porg.errors[:organization]
  end

  def test_prog_dom_can_have_nil_subdomain
    organization = programs(:org_primary)
    pd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
    pd.domain = DEFAULT_DOMAIN_NAME
    # Default domain must have subdomain
    assert_false pd.valid?
    assert_equal(["can't be blank"], pd.errors[:subdomain])

    pd.domain = "arbit.com"
    # Subdomain is not mandatory for custom domains
    assert pd.valid?
  end

  def test_subdomain_name_should_be_unique
    npd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
    npd.subdomain = "primary"
    assert_false npd.valid?
    assert_equal(["has already been taken"], npd.errors[:subdomain])

    # try a different case
    npd.subdomain = "PriMary"
    assert_false npd.valid?
    assert_equal(["has already been taken"], npd.errors[:subdomain])
  end

  def test_should_not_create_programs_subdomains_having_2_or_less_characters
    npd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
    npd.subdomain = "fi"
    assert_false npd.valid?
    assert_equal(["is too short (minimum is 3 characters)"], npd.errors[:subdomain])

    # try a different case
    npd.subdomain = "fir"
    assert npd.valid?
  end

  def test_should_not_create_programs_with_invalid_characters_in_subdomain_string
    npd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
    npd.subdomain = "!@#^&"
    assert_false npd.valid?
    assert_equal(["can only contain alphanumeric characters and dashes or dots"], npd.errors[:subdomain])
    npd.subdomain = "test_prog"
    assert_false npd.valid?
    assert_equal(["can only contain alphanumeric characters and dashes or dots"], npd.errors[:subdomain])
  end

  def test_should_downcase_subdomain_before_creating_a_program
    npd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
    npd.subdomain = "ArEnAr"
    npd.save!

    assert_equal("arenar", npd.subdomain)
  end

  def test_program_subdomain_should_not_be_one_of_reserved_domains
    npd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
    npd.subdomain = 'advisor'
    assert_false npd.valid?
    assert_equal(["advisor is reserved"], npd.errors[:subdomain])
  end

  def test_should_accept_custom_domain_name
    assert_difference "Program::Domain.count" do
      npd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
      npd.subdomain = 'mentor'
      npd.domain = "iit.com"
      npd.save!
    end

    npd = Program::Domain.last
    assert_equal "mentor", npd.subdomain
    assert_equal "iit.com", npd.domain
    assert !npd.default_domain?
  end

  def test_program_domain_name_regex
    npd = Program::Domain.new(:organization => programs(:org_primary), :is_default => false)
    npd.domain = "j*&((jaj.6161"
    assert_false npd.valid?
    assert_equal ["is not of valid format"], npd.errors[:domain]

    npd.domain = "tws.org"
    assert npd.valid?
    assert npd.errors[:domain].blank?
  end

  def test_get_organization
    assert_nil Program::Domain.get_organization("chronus.com", "nonexisting")

    assert_equal programs(:org_primary), Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, "primary")
    assert_equal programs(:org_anna_univ) , Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, "annauniv")
    assert_equal programs(:org_foster) , Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, "foster")
    assert_equal programs(:org_custom_domain) , Program::Domain.get_organization("customtest.com", "mentor")
    assert_equal programs(:org_no_subdomain) , Program::Domain.get_organization("nosubdomtest.com", nil)
  end

  def test_get_url
    assert_equal "nosubdomtest.com", program_domains(:org_no_subdomain).get_url
    assert_equal "mentor.customtest.com", program_domains(:org_custom_domain).get_url
    assert_equal "annauniv.#{DEFAULT_DOMAIN_NAME}", program_domains(:org_anna_univ).get_url
  end
end
