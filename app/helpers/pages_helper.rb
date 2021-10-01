module PagesHelper
  def visibilities_for_select
    PagesHelper::visibility_text.map do |key, value|
      [value, key]
    end
  end

  def visibility_text(page)
    PagesHelper::visibility_text[page.visibility]
  end

  def page_link(page, admin_view = false)
    title = content_tag(:span, (admin_view ? get_icon_content("fa fa-arrows") : "") + page.title, class: page.published? ? '' : 'has-next')
    title += content_tag(:span, 'feature.page.draft'.translate, class: 'label') unless page.published?
    link_to sanitize(title.html_safe), page
  end

  def get_programs_listing_tab_heading
    return unless can_view_programs_listing_page?
    if organization_view?
      _Programs
    elsif program_view?
      @current_organization.name
    end
  end

  private

  def self.visibility_text
    {
      Page::Visibility::LOGGED_IN => "feature.page.visibility.logged_in".translate,
      Page::Visibility::BOTH      => "feature.page.visibility.both".translate,
    }
  end
end