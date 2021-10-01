require_relative '../../test_helper.rb'

class PagesHelperTest < ActionView::TestCase
  def test_visibilities_for_select_should_success
    expect = [
      ["Logged in users only", 1],
      ["Both logged in users and non logged in users", 0],
    ]
    assert_equal expect, visibilities_for_select
  end

  def test_visibility_text
    page = pages(:pages_1)

    page.update_attribute(:visibility, Page::Visibility::LOGGED_IN)
    assert_equal "Logged in users only", visibility_text(page)

    page.update_attribute(:visibility, Page::Visibility::BOTH)
    assert_equal "Both logged in users and non logged in users", visibility_text(page)
  end

  def test_page_link
    page = pages(:pages_1)
    assert_match %{<a href=\"/pages/1\"><span class=\"\">General Overview</span></a>}, page_link(page)

    page.update_attribute(:published, false)
    assert_match %{<a href=\"/pages/1\"><span class=\"has-next\">General Overview</span><span class=\"label\">draft</span></a>}, page_link(page)
  end

  def test_get_programs_listing_tab_heading
    @current_organization = programs(:org_primary)
    self.expects(:can_view_programs_listing_page?).returns(false)
    assert_nil get_programs_listing_tab_heading

    self.expects(:can_view_programs_listing_page?).at_least_once.returns(true)
    self.expects(:_Programs).returns("Programs")

    self.expects(:organization_view?).returns(true)
    assert_equal "Programs", get_programs_listing_tab_heading

    self.expects(:organization_view?).returns(false)
    self.expects(:program_view?).returns(true)
    assert_equal @current_organization.name, get_programs_listing_tab_heading
  end
end
