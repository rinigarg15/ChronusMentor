require_relative './../test_helper.rb'

class PageTest < ActiveSupport::TestCase
  def test_should_belong_to_a_program_and_have_a_title
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Page.create!
    end

    assert_match(/Program can't be blank/, e.message)
    assert_match(/Page title can't be blank/, e.message)
  end
  
  def test_page_states
    assert_equal [1, 0], Page::Visibility.all
  end

  def test_for_non_logged_in_users_should_success
    program = programs(:albers)
    # create pages of 3 types
    p1 = program.pages.create!(title: "Logged in user page", visibility: Page::Visibility::LOGGED_IN)
    p2 = program.pages.create!(title: "Both users page", visibility: Page::Visibility::BOTH)

    program.reload
    pages = Page.for_not_logged_in_users

    assert !pages.include?(p1), "expect #for_non_logged_in_users not to contain page with LOGGED_IN visibility"
    assert  pages.include?(p2), "expect #for_non_logged_in_users to contain page with BOTH visibility"
  end

  def test_page_published_scope
    published_page = Page.create(program: programs(:albers), title: 'Active page', published: true)
    draft_page     = Page.create(program: programs(:albers), title: 'Drafted page', published: false)

    assert  Page.published.include?(published_page)
    assert !Page.published.include?(draft_page)
  end

  def test_publish_method
    draft_page = Page.create(program: programs(:albers), title: 'Drafted page', published: false)
    draft_page.publish!
    assert draft_page.published?
  end

  def test_publicize_assets
    asset = create_ckasset
    assert asset.login_required?
    page = Page.create(program: programs(:albers), title: "Page", published: false, content: "Attachment: #{asset.url_content}", visibility: Page::Visibility::BOTH)
    program = programs(:albers)
    assert_false page.publicly_accessible?
    assert asset.login_required?

    page.publish!
    assert page.publicly_accessible?
    assert_false asset.reload.login_required?

    page.update_attributes(visibility: Page::Visibility::LOGGED_IN)
    assert page.publicly_accessible?
    assert_false asset.reload.login_required?

    assert page.publicly_accessible?
    assert_false asset.reload.login_required?

    program.enable_feature(FeatureName::LOGGED_IN_PAGES)
    assert_false page.publicly_accessible?
    assert_false asset.reload.login_required?
  end

  def test_removescript_access_on_save
    page = Page.new(program: programs(:albers), title: 'Active page', published: true, content: '<object width="425" height="344"><param name="movie" value="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;"><param name="allowFullScreen" value="true"><param name="allowscriptaccess" value="always"><embed src="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="425" height="344"></object>')
    page.current_member = members(:f_admin)
    page.sanitization_version = "v1"
    page.save!
    assert_match "<param name=\"allowscriptaccess\" value=\"never\">", page.content
  end

end