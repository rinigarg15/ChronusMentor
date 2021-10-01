require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/publications_helper"

class PublicationsHelperTest < ActionView::TestCase  
  def test_formatted_publication_in_listing
    publication = Publication.new(:title => "Publication")
    assert_dom_equal("<div class=\"m-b-xs\"><i class=\"fa fa-book fa-fw m-r-xs\"></i><strong>Publication</strong><div></div></div>", formatted_publication_in_listing(publication))

    publication.publisher = 'Publisher'
    assert_dom_equal(%Q{<div class=\"m-b-xs\"><i class=\"fa fa-book fa-fw m-r-xs\"></i><strong>Publication</strong><div><span>Publisher</span></div></div>}, formatted_publication_in_listing(publication))

    publication.year = 2010
    publication.month = 1
    publication.day = 1
    assert_dom_equal(%Q{<div class=\"m-b-xs\"><i class=\"fa fa-book fa-fw m-r-xs\"></i><strong>Publication</strong><div><span>Publisher</span><span class=\"text-muted\"> | </span><span class=\"text-muted\">January 01, 2010</span></div></div>}, formatted_publication_in_listing(publication))

    publication.url = 'http://url.com'
    assert_dom_equal(%Q{<div class=\"m-b-xs\"><i class=\"fa fa-book fa-fw m-r-xs\"></i><strong><a href=\"http://url.com\" target=\"_blank\">Publication</a></strong><div><span>Publisher</span><span class=\"text-muted\"> | </span><span class=\"text-muted\">January 01, 2010</span></div></div>}, formatted_publication_in_listing(publication))

    publication.authors = 'Agata'
    assert_dom_equal(%Q{<div class=\"m-b-xs\"><i class=\"fa fa-book fa-fw m-r-xs\"></i><strong><a href=\"http://url.com\" target=\"_blank\">Publication</a></strong><div><span>Publisher</span><span class=\"text-muted\"> | </span><span class=\"text-muted\">January 01, 2010</span></div><div class=\"m-b-xs\"><strong class=\"m-r-xs text-muted\">Authors:</strong>Agata</div></div>}, formatted_publication_in_listing(publication))

    publication.description = nil
    assert_dom_equal(%Q{<div class=\"m-b-xs\"><i class=\"fa fa-book fa-fw m-r-xs\"></i><strong><a href=\"http://url.com\" target=\"_blank\">Publication</a></strong><div><span>Publisher</span><span class=\"text-muted\"> | </span><span class=\"text-muted\">January 01, 2010</span></div><div class=\"m-b-xs\"><strong class=\"m-r-xs text-muted\">Authors:</strong>Agata</div></div>}, formatted_publication_in_listing(publication))
  end
end