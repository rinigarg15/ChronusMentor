require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/articles_helper"

class ArticlesHelperTest < ActionView::TestCase
  include FlagsHelper
  include QaAnswersHelper

  def test_site_preview_image
    item = stub(:content => "http://google.com")
    assert_match(/script.*stw_pagepix.*http:\/\/google\.com/, site_preview_image(item))
  end

  def test_book_image
    presenter1 = stub("presenter") {
      expects(:image_link).returns("http://abc.com")
      expects(:amazon_link).returns("http://amazon.com/book")
    }
#    presenter2 = stub("presenter") {
#      expects(:image_link).returns(nil)
#      expects(:amazon_link).returns("http://amazon.com/book")
#    }

    item1 = stub('book1') {
      stubs(:presenter).returns(presenter1)
      stubs(:content).returns("Book1")
    }
#    item2 = stub('book2') {
#      stubs(:presenter).returns(presenter2)
#      stubs(:content).returns("Book2")
#    }

    assert_match(/img.*class="amazon_img.*".*src="http:\/\/abc\.com"/, book_image(item1))
#    assert_match(/img.*class="amazon_img".*src=".*\/assets\/book-icon.gif.*"/, book_image(item2))
  end

  def test_book_link
    alink = "http://amazon.com/book"
    presenter1 = stub("presenter") {
      expects(:amazon_link).returns(alink)
    }
    item1 = stub('book1') {
      stubs(:presenter).returns(presenter1)
      stubs(:content).returns("Book1")
    }
    assert_equal(alink, book_link(item1))


    presenter2 = stub("presenter") {
      expects(:amazon_link).returns(nil)
    }
    book_name = 'Book another'
    item2 = stub('book1') {
      stubs(:presenter).returns(presenter2)
      stubs(:content).returns(book_name)
    }
    assert_match(/books\.google\.com\/books\?q=#{book_name}/, book_link(item2))
  end

  def test_thumbnail_of_for_booklist_item
    item = BookListItem.new
    self.expects(:book_image).with(item)
    thumbnail_of(item)
  end

  def test_thumbnail_of_for_sitelist_item
    item = SiteListItem.new
    self.expects(:site_preview_image).with(item)
    thumbnail_of(item)
  end

  def test_site_banner
    item = SiteListItem.new(:content => "http://conway.com")
    assert_match(/.*http:\/\/conway\.com/, site_banner(item))
  end

  def test_book_banner
    item = BookListItem.new(:content => "The White Tiger")
    presenter = mock("presenter") do
      expects(:author).returns("Aravind Adiga")
      expects(:amazon_link).returns("http://amazon.com/white_tiger")
    end
    item.stubs(:presenter).returns(presenter)

    str = book_banner(item)
    set_response_text(str)
    assert_select "h4.book_details" do
      "The White Tiger"
      assert_select "div.small", text: "By Aravind Adiga"
    end
  end

  def test_banner_of_for_book
    item = BookListItem.new
    self.expects(:book_banner).with(item)
    banner_of(item)
  end

  def test_banner_of_for_site
    item = SiteListItem.new
    self.expects(:site_banner).with(item)
    banner_of(item)
  end

  def test_article_type_of
    assert_equal("General Advice", type_of(build_article))
    assert_equal("List", type_of(build_article(:type => ArticleContent::Type::LIST)))
    assert_equal("Embedded Media", type_of(build_article(:type => ArticleContent::Type::MEDIA)))
  end

  def test_excerpt_for_text_article
    @current_organization = programs(:org_primary)
    text = "Abc abc abc"
    a = create_article(:body => text)
    assert_equal(text, excerpt(a))
  end

  def test_excerpt_for_list_article
    a = build_article(:type => ArticleContent::Type::LIST)
    a.list_items << SiteListItem.new(:content => 'http://a9.com')
    a.list_items << BookListItem.new(:content => 'The art of controversial war')
    a.list_items << SiteListItem.new(:content => 'http://www.discoverbing.com')
    a.save!
    set_response_text(excerpt(a))

    assert_select 'ul.list_excerpt' do
      assert_select 'li', :inner_text => 'http://a9.com'
      assert_select 'li', :inner_text => 'The art of controversial war'
      assert_select 'li', :inner_text => 'http://www.discoverbing.com'
    end
  end

  def test_excerpt_for_media_article
    a1 = create_article(:body => "text", :type => ArticleContent::Type::MEDIA, :embed_code => 'abc')
    assert_match /abc/, excerpt(a1)
  end

  def test_excerpt_for_upload_file
    @current_organization = programs(:org_primary)
    current_program_is :albers
    a1 = create_article(:body => "text", :type => ArticleContent::Type::UPLOAD_ARTICLE, :article_content => create_upload_article_content)
    assert_equal "&lt;script&gt;alert(1)&lt;/script&gt;", excerpt(a1)
  end

  def test_article_label_links
    set_response_text(article_label_links(articles(:india)))
    assert_select "a[href=\"/articles?label=locations\"]", :text => 'locations'
  end

  def test_article_label_links_with_multiple_labels
    article_contents(:india).update_attributes(label_list: "abc, locations")
    set_response_text(article_label_links(articles(:india).reload))
    assert_select "a[href=\"/articles?label=locations\"]", :text => 'locations'
    assert_select "a[href=\"/articles?label=abc\"]", :text => 'abc'
  end

  def test_listing_label_links_sorting_labels
    article_contents(:india).update_attributes(label_list: "abc, locations, bad")
    set_response_text(article_label_links(articles(:india).reload))
    all_labels = { "abc" => 1, "locations" => 1, "bad" => 1 }
    stub_request_parameters("action" => "index", "controller" => "articles", "root" => "main")
    content_tag = listing_label_links(nil, all_labels, 3)
    set_response_text(content_tag)
    assert_select "li" do
      assert_select "li.gray-bg", :text => "All labels (3)"
      assert_select "li", :text => "abc (1)"
      assert_select "li", :text => "bad (1)"
      assert_select "li", :text => "locations (1)"
    end
  end

  def test_edit_or_create_page_title
    # Draft, Tainted draft object
    a = articles(:draft_article)
    assert_equal("Draft article (draft)", edit_or_create_page_title(a))

    # Make title blank
    a.article_content.title = ""
    a.article_content.status = ArticleContent::Status::PUBLISHED
    assert_equal("(no title) (draft)", edit_or_create_page_title(a))

    # Published
    assert_equal("Edit #{_Article}", edit_or_create_page_title(articles(:economy)))

    # New Text Article
    ac = ArticleContent.new(:type => ArticleContent::Type::TEXT)
    assert_equal("New General #{_Article}", edit_or_create_page_title(Article.new(:article_content => ac)))

    # New List Article
    ac = ArticleContent.new(:type => ArticleContent::Type::LIST)
    assert_equal("New Books/Websites List", edit_or_create_page_title(Article.new(:article_content => ac)))

    # New Media Article
    ac = ArticleContent.new(:type => ArticleContent::Type::MEDIA)
    assert_equal("New Media #{_Article}", edit_or_create_page_title(Article.new(:article_content => ac)))

    # Upload New Article
    ac = ArticleContent.new(:type => ArticleContent::Type::UPLOAD_ARTICLE)
    assert_equal("Upload New #{_Article}", edit_or_create_page_title(Article.new(:article_content => ac)))
  end

  def test_get_common_article_actions_for_author
    self.expects(:current_program).at_least(0).returns(programs(:albers))
    article = articles(:kangaroo)
    assert_equal members(:f_mentor), article.author
    assert_equal 0, article.view_count
    assert_equal 0, article.helpful_count

    self.expects(:wob_member).at_least(0).returns(members(:f_mentor))
    @current_user = users(:f_mentor)
    content = get_common_article_actions(article, 1)
    set_response_text(content)
    assert_select "div.btn-group" do
      assert_select "a.rating_link.btn-white[data-replace-content][data-toggle-class='btn-primary btn-white']" do
        assert_select "i.fa-thumbs-up"
        assert_select "span.hidden-xs", text: "Like"
      end
      assert_select "a.btn-white" do
        assert_select "i.fa-comments"
        assert_select "span", text: "1Comment"
        assert_select "span.hidden-xs", text: "Comment"
      end
      assert_select "span.cursor-default" do
        assert_select "i.fa-eye"
        assert_select "span", text: "0Views"
        assert_select "span.hidden-xs", text: "Views"
      end
    end
    assert_no_match(/Report Content/, content)
  end

  def test_get_common_article_actions_for_non_author
    article = articles(:kangaroo)
    self.expects(:current_program).at_least(0).returns(programs(:albers))
    self.expects(:wob_member).at_least(0).returns(members(:f_student))
    @current_user = users(:f_student)

    article.expects(:view_count).at_least(0).returns(2)
    article.expects(:helpful_count).at_least(0).returns(1)
    content = get_common_article_actions(article, 5, listing: false, no_comments_info: true)
    set_response_text(content)
    assert_select "div.btn-group" do
      assert_select "a.rating_link.btn-white[data-replace-content][data-toggle-class='btn-primary btn-white']" do
        assert_select "i.fa-thumbs-up"
        assert_select "span", text: "1"
        assert_select "span.hidden-xs", text: "Like"
      end
      assert_select "span.cursor-default" do
        assert_select "i.fa-eye"
        assert_select "span", text: "2Views"
        assert_select "span.hidden-xs", text: "Views"
      end
      assert_no_select "a.cjs_grey_flag"
    end
    assert_select "a.cjs_grey_flag" do
      assert_select "i.fa-flag"
      assert_select "span", text: "Report Content"
      assert_select "span.hidden-xs", text: "Report Content"
    end
    assert_no_match(/Comment/, content)

    content = get_common_article_actions(article, 5, listing: true)
    assert_match /Comment/, content
    assert_no_match(/Report Content/, content)
  end

  def test_get_article_actions_for_author_or_admin
    article = articles(:kangaroo)
    assert_equal members(:f_mentor), article.author

    # non-admin | author
    self.expects(:wob_member).at_least(0).returns(members(:f_mentor))
    @current_user = users(:f_mentor)
    content = get_article_actions_for_author_or_admin(article)
    assert_equal 2, content.size
    assert_match /Edit Article/, content[0][:label]
    assert_match /Delete Article/, content[1][:label]

    # non-admin | non-author
    self.expects(:wob_member).at_least(0).returns(members(:f_student))
    @current_user = users(:f_student)
    assert_nil get_article_actions_for_author_or_admin(article)

    # admin | non-author
    self.expects(:wob_member).at_least(0).returns(members(:f_admin))
    @current_user = users(:f_admin)
    content = get_article_actions_for_author_or_admin(article)
    assert_equal 2, content.size
    assert_match /Edit Article/, content[0][:label]
    assert_match /Delete Article/, content[1][:label]
  end

  def test_get_comment_actions
    self.expects(:current_program).at_least(0).returns(programs(:ceg))
    comment = comments(:anna_univ_ceg_1_c1)
    assert_equal users(:f_mentor_ceg), comment.user

    # non-admin | comment-owner
    @current_user = comment.user
    content = get_comment_actions(comment)
    assert_equal 1, content.size
    assert_match /Delete/, content[0][:label]

    # non-admin | non-comment-owner
    @current_user = users(:arun_ceg)
    content = get_comment_actions(comment)
    assert_equal 1, content.size
    assert_match /Report Content/, content[0][:label]

    # admin | non-comment-owner
    @current_user = users(:ceg_admin)
    content = get_comment_actions(comment)
    assert_equal 2, content.size
    assert_match /Report Content/, content[0][:label]
    assert_match /Delete/, content[1][:label]
  end

  def test_get_content_to_render_inside_community_widget
    article = articles(:economy)
    self.stubs(:excerpt).returns("calling excerpt")

    article.article_content.update_attribute(:type, ArticleContent::Type::MEDIA)
    assert_equal "Embedded media content inside.", get_content_to_render_inside_community_widget(article)

    article.article_content.update_attribute(:type, ArticleContent::Type::UPLOAD_ARTICLE)
    assert_nil get_content_to_render_inside_community_widget(article)

    article.article_content.update_attribute(:type, ArticleContent::Type::TEXT)
    assert_equal "calling excerpt", get_content_to_render_inside_community_widget(article)

    article.article_content.update_attribute(:type, ArticleContent::Type::LIST)
    assert_equal "calling excerpt", get_content_to_render_inside_community_widget(article)
  end

  def test_render_community_widget_article_content
    article = articles(:economy)
    self.stubs(:get_content_to_render_inside_community_widget).returns("sample content")
    content = render_community_widget_article_content(article)
    set_response_text(content)

    assert_select "div.clearfix.height-65.overflowy-ellipsis.break-word-all" do
      assert_select "a.btn-link" do
        assert_select "h4.m-b-xs.maxheight-30.overflowy-ellipsis.h5.no-margins.text-info", text: truncate_html(article.article_content.title, max_length: 65)
      end
      assert_select "div.m-t-xs.inline.m-b-sm" do
        assert_select "span.small.text-muted", text: "#{time_ago_in_words(article.article_content.updated_at)} ago" do
          assert_select "i.fa-clock-o"
        end
      end
    end
    assert_select "div.height-54.break-word-all.overflowy-ellipsis.p-r-xs", text: "sample content"
  end

  def test_get_list_item_description
    list_item = SiteListItem.create!(content: "https://google.com")
    assert_match /No description provided by the article contributor./, get_list_item_description(list_item)
    list_item.update_attribute(:description, "List item desc.")
    assert_equal "List item desc.", get_list_item_description(list_item)
  end

  def test_display_embed_content
    article = articles(:economy)
    assert_nil display_embed_content(article)

    article.article_content.update_attribute(:type, ArticleContent::Type::MEDIA)
    article.article_content.update_attribute(:embed_code, "<html><body></body></html>")
    content = display_embed_content(article)
    assert_match /cjs_embedded_media/, content
    assert_no_match(/embed-responsive/, content)
    assert_match /<html><body><\/body><\/html>/, content

    article.article_content.update_attribute(:embed_code, "<iframe src='www.youtube.com'></iframe>")
    content = display_embed_content(article)
    assert_match /cjs_embedded_media/, content
    assert_match /embed-responsive/, content
    assert_match /<iframe src=\'www.youtube.com\'><\/iframe>/, content
  end

  def test_display_uploaded_article_content
    article = articles(:economy)
    assert_nil display_uploaded_article_content(article)

    article.article_content.update_attribute(:type, ArticleContent::Type::UPLOAD_ARTICLE)
    article.article_content.update_attribute(:attachment_file_name, "test")
    content = display_uploaded_article_content(article)
    assert_match /fa-file/, content
    assert_match /test/, content
    assert_match /a.*href/, content
    assert_match /Download/, content
  end

  def test_get_comment_action_label
    assert_equal "<span class=\"cjs_comments_count\"><span class=\"m-r-xs\">1</span><span class=\"hidden-xs\">Comment</span></span>", get_comment_action_label(1)
    assert_equal "<span class=\"cjs_comments_count\"><span class=\"hidden-xs\">Comment</span></span>", get_comment_action_label(0)
    assert_equal "<span class=\"cjs_comments_count\"><span class=\"m-r-xs\">2</span><span class=\"hidden-xs\">Comments</span></span>", get_comment_action_label(2)
  end

  def test_article_comments_container
    article = articles(:economy)
    article_publication = article.publications.first
    options = {
      comment_partial: "comments/comment",
      comment_partial_key: :comment,
      new_comment_partial: "comments/new_comment_form",
      new_comment_partial_locals: { article: article },
      container_id: "comments_box"
    }
    self.expects(:comments_container).with([], options).once
    article_comments_container(article_publication)

    assert_nil article_comments_container(nil)

    comments = 3.times.collect do
      Comment.create!(
        publication: article_publication,
        user: users(:f_mentor),
        body: "Comment"
      )
    end
    self.expects(:comments_container).with(comments, options).once
    article_comments_container(article_publication.reload)
  end

  private

  def _a_article
    "an article"
  end

  def _article
    "article"
  end

  def _Article
    "Article"
  end

  def _articles
    "articles"
  end

  def _Articles
    "Articles"
  end
end