require_relative './../test_helper.rb'

class BookListItemPresenterTest < ActiveSupport::TestCase
  def test_similar_book_items
    assert BookListItemPresenter.similar_book_titles?("Site list : this", "Site list: this")
    assert BookListItemPresenter.similar_book_titles?("Yahoo &amp; business", "yAhoo & business")
    assert BookListItemPresenter.similar_book_titles?("Code name ginger`s book", "code name ginger's book")
  end

  def test_initialize_should_return_https_image_link_if_ssl_isenabled
    
    book_title = "The Google Story"

    amazon_item = mock('amazon_item') do
      expects(:get_hash).times(2).with("MediumImage").returns({"URL" => "http://amazon.com/book.jpg"})
      expects(:get).times(2).with("DetailPageURL").returns("http://amazon.com/book1.html")
      expects(:get).times(2).with("ItemAttributes/Title").returns(book_title)
      expects(:get).with("ItemAttributes/Author").returns("Arthur Wilson")
    end
    response_mock = stub('res_mock', :items => [amazon_item])
    Amazon::Ecs.expects(:item_search).with(book_title, {:response_group => 'Images,Reviews,ItemAttributes'}).returns(response_mock)

    a = BookListItem.new(:content => book_title)
    presenter = BookListItemPresenter.new(a)
    assert presenter.image_link,"https://images-na.ssl-images-amazon.com/book.jpg"
  end

  def test_initialize_should_return_orig_image_link_if_ssldisabled
    
    book_title = "The Google Story"

    amazon_item = mock('amazon_item') do
      expects(:get_hash).times(2).with("MediumImage").returns({"URL" => "http://amazon.com/book.jpg"})
      expects(:get).times(2).with("DetailPageURL").returns("http://amazon.com/book1.html")
      expects(:get).times(2).with("ItemAttributes/Title").returns(book_title)
      expects(:get).with("ItemAttributes/Author").returns("Arthur Wilson")
    end
    response_mock = stub('res_mock', :items => [amazon_item])
    Amazon::Ecs.expects(:item_search).with(book_title, {:response_group => 'Images,Reviews,ItemAttributes'}).returns(response_mock)

    a = BookListItem.new(:content => book_title)
    Rails.application.config.stubs(:force_ssl).returns(false)
    presenter = BookListItemPresenter.new(a)
    assert presenter.image_link,"http://amazon.com/book.jpg"
  end

  def test_initialize_if_amazon_request_failed
    book_title = "The Google Story"

    Amazon::Ecs.stubs(:item_search).raises(RuntimeError)
    a = BookListItem.new(:content => book_title)
    presenter = BookListItemPresenter.new(a)
    assert_nil presenter.image_link
  end

  def test_get_search_response_from_amazon_raise_error
    Amazon::Ecs.stubs(:item_search).raises(RuntimeError)
    assert_nil BookListItemPresenter.get_search_response_from_amazon("The Google Story")
  end
end
