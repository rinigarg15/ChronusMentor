require_relative './../test_helper.rb'

class ArticleListItemTest < ActiveSupport::TestCase
  # !!! Is there a way to test the abstact base class?
  def test_should_require_type
    a = ArticleListItem.new
    assert !a.valid?
    assert_equal(["can't be blank"], a.errors[:type])
  end
  
  #-------------------- SiteListItem --------------------
  def test_sitelistitem_should_have_content
    assert_no_difference "ArticleListItem.count" do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :content) do
        a = SiteListItem.new
        a.save!      
      end
    end
  end
  
  def test_label_for_content_for_sitelistitem
    assert_equal("URL", SiteListItem.new.label_for_content)
  end
  
  def test_type_string_for_sitelistitem
    a = build_article(:type => ArticleContent::Type::LIST)
    a.list_items << SiteListItem.create!(:content => "http://google.com")
    a.save!
    assert_equal("SiteListItem", ArticleListItem.last.type_string)
  end
  
  def test_should_validate_content_for_sitelistitem
    item = SiteListItem.new(:content => "google")
    assert !item.valid?
    assert_equal(["format is invalid. Only HTTP, HTTPS URLs are allowed"], item.errors[:content])
    
    item = SiteListItem.new(:content => "http://google.com")
    item.valid?
    assert_blank item.errors[:content]
  end
  #-------------------- SiteListItem --------------------
  
  #-------------------- BookListItem --------------------
  def test_booklistitem_should_have_content
    assert_no_difference "ArticleListItem.count" do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :content) do
        a = BookListItem.new
        a.save!
      end
    end
  end
  
  def test_label_for_content_for_booklistitem
    assert_equal("Title", BookListItem.new.label_for_content)
  end
  
  def test_type_string_for_booklistitem
    a = build_article(:type => ArticleContent::Type::LIST)
    a.list_items << BookListItem.create!(:content => "Blink")
    a.save!
    assert_equal("BookListItem", ArticleListItem.last.type_string)
  end
  #-------------------- BookListItem --------------------

  def test_valid_types
    assert_equal [BookListItem, SiteListItem], ArticleListItem.valid_types
  end

  def test_valid_types_as_strings
    assert_equal [BookListItem.name, SiteListItem.name], ArticleListItem.valid_types_as_strings
  end
end