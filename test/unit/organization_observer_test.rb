require_relative './../test_helper.rb'

class OrganizationObserverTest < ActiveSupport::TestCase
  def test_should_create_default_sections_and_questions_custom_terms_and_resources
    organization = Organization.new(name: "Some Organization")
    assert_difference "Resource.count", 4 do
      assert_difference "Section.count", 3 do
        assert_difference "ProfileQuestion.count", 17 do
          organization.save!
        end
      end
    end
    assert_not_empty organization.sections
    assert_not_empty organization.profile_questions
    assert_not_empty organization.resources

    assert organization.sections.where(title: "Basic Information").any?
  end

  def test_should_not_create_default_sections_and_questions_if_already_built
    organization = Organization.new(name: "Some Organization")
    section = organization.sections.build(
      title: "Section",
      organization: organization)
    section.profile_questions.build(
      section: section,
      organization: organization,
      question_text: "Email",
      question_type: ProfileQuestion::Type::EMAIL)
    assert_difference "Section.count", 1 do
      assert_difference "ProfileQuestion.count", 1 do
        organization.save!
      end
    end
  end

  def test_create_competency_and_questions
    Organization.any_instance.stubs(:create_competency_and_questions!).at_least(1).returns()
    organization = Organization.new(name: "Some Organization")
    organization.save!
  end

  def test_create_about_pages
    Organization.any_instance.stubs(:create_competency_and_questions!).at_least(1).returns()
    organization =  Organization.new(name: "SomeOrganization")
    organization.save!
    assert_equal organization.pages.size, 3
    mentor_page = organization.pages.where(:title => "For Mentors").first.content
    mentee_page = organization.pages.where(:title => "For Mentees").first.content
    assert_match /<h3>Mentor DO&#39;s<\/h3>/, mentor_page
    assert_match /<h3>Mentor DON&#39;Ts<\/h3>/, mentor_page
    assert_match /<h3>Mentee DO&#39;s<\/h3>/, mentee_page
    assert_match /<h3>Mentee DON&#39;Ts<\/h3>/, mentee_page
  end

  def test_should_not_create_about_pages_for_sales_demo
    organization = Organization.new(name: "SomeOrganization")
    organization.stubs(:created_for_sales_demo).returns(true)
    organization.save!
    assert_empty organization.pages
  end

  def test_create_default_browser_warning_content
    Organization.any_instance.stubs(:create_competency_and_questions!).at_least(1).returns()
    organization = Organization.new(name: "Some Organization")
    assert_nil organization.browser_warning

    organization.save!
    assert_not_nil organization.browser_warning
  end
end
