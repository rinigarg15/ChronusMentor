require_relative './../test_helper.rb'

class ArticleContentTest < ActiveSupport::TestCase
  def test_has_many_organizations
    assert_equal [programs(:org_primary)], article_contents(:kangaroo).organizations

    Article.create!(
      { :article_content => article_contents(:kangaroo),
        :published_programs => [programs(:ceg)],
        :author => members(:f_mentor_ceg),
        :organization => programs(:org_anna_univ)
      }
    )

    assert_equal [programs(:org_primary), programs(:org_anna_univ)],
      article_contents(:kangaroo).reload.organizations
  end

  def test_should_create_a_list_article_with_book_and_site_items_and_destroy_it
    a = ArticleContent.new(:type => 'list', :title => 'test', :status => ArticleContent::Status::PUBLISHED)
    assert_difference "ArticleContent.count", 1 do
      assert_difference "ArticleListItem.count", 3 do
        a.list_items << SiteListItem.new(:content => "http://url.com")
        a.list_items << BookListItem.new(:content => "My New book")
        a.list_items << SiteListItem.new(:content => "https://google.com")

        a.save!
      end
    end
    assert_equal(3, a.reload.list_items.count)
    assert_equal(ArticleContent::Type::LIST, a.type)

    assert_difference "ArticleContent.count", -1 do
      assert_difference "ArticleListItem.count", -3 do
        a.destroy
      end
    end
  end

  def test_should_check_for_title_only_when_published
    a1 = ArticleContent.new(:type => 'list', :status => ArticleContent::Status::DRAFT)
    a2 = ArticleContent.new(:type => 'media', :status => ArticleContent::Status::DRAFT)
    a3 = ArticleContent.new(:type => 'text', :status => ArticleContent::Status::DRAFT)

    assert_difference("ArticleContent.count", 3) do
      a1.save!;a3.save!;a2.save!;
    end
  end

  def test_should_not_create_empty_list_article
    a = ArticleContent.new(:type => 'list', :title => 'test', :status => ArticleContent::Status::PUBLISHED)
    assert_difference "ArticleContent.count", 0 do
      e = assert_raise(ActiveRecord::RecordInvalid) do
        a.save!
      end
    end
    assert_equal(["List cannot be empty"], a.errors[:base])
  end

  def test_should_update_list_by_adding_new_item
    a = create_list_article_content
    assert_difference "ArticleListItem.count", 2 do
      assert_difference "a.list_items.count", 2 do
        a.new_listitem_attributes = {
          "temp_id_1" => { :content => "The White Tiger", :type_string => "BookListItem" },
          "temp_id_2" => { :content => "http://yahoo.com", :type_string => "SiteListItem" }
        }
        a.save!
      end
    end
  end

  def test_should_update_list_by_changing_existing_item
    a = create_list_article_content
    assert_equal('http://url.com', a.list_items.first.content)
    a.existing_listitem_attributes = {
      a.list_items.first.id.to_s => { :content => "http://gogole.com" }
    }
    assert_difference "ArticleListItem.count", 0 do
      assert_difference "a.list_items.count", 0 do
        a.save!
        a.reload
      end
    end
    assert_equal('http://gogole.com', a.list_items.first.content)
  end

  def test_should_update_list_by_deleting_an_existing_item_and_add_new_ones
    a = create_list_article_content
    assert_equal('http://url.com', a.list_items.first.content)

    assert_difference "ArticleListItem.count", 1 do
      assert_difference "a.list_items.count", 1 do
        # Empty array to simulate all items are cleared
        a.existing_listitem_attributes = { }

        # New items
        a.new_listitem_attributes = {
          "temp_id_1" => { :content => "The White Tiger", :type_string => "BookListItem" },
          "temp_id_2" => { :content => "http://yahoo.com", :type_string => "SiteListItem" }
        }
        a.save!
      end
    end

    assert_equal(2, a.list_items.count)
    assert_equal("The White Tiger", a.list_items.first.content)
    assert_equal("http://yahoo.com", a.list_items.last.content)
  end

  def test_new_listitem_attributes_permission_denied
    a = create_list_article_content
    assert_equal('http://url.com', a.list_items.first.content)

    assert_permission_denied do
      assert_no_difference "ArticleListItem.count" do
        assert_no_difference "a.list_items.count" do
          a.new_listitem_attributes = {
            "temp_id_1" => { :content => "Something", :type_string => "BookListItem" },
            "temp_id_2" => { :content => "Test", :type_string => "User" }
          }
        end
      end
    end
  end

  def test_should_fail_the_update_if_user_attempts_to_empty_all_items_on_list
    a = create_list_article_content
    assert_equal('http://url.com', a.list_items.first.content)
    # Empty array to simulate all items are cleared
    a.existing_listitem_attributes = { }

    assert_raise(ActiveRecord::RecordInvalid) do
      a.save!
    end
  end

  def test_should_update_list_if_author_tries_to_delete_existing_items
    ac = create_list_article_content
    ac.list_items << SiteListItem.new(:content => "http://google.com")
    ac.list_items << BookListItem.new(:content => "Ajax Design patterns")
    assert_equal(3, ac.list_items.size)

    ac.existing_listitem_attributes = {
      ac.list_items[1].id.to_s => { :content => "http://gogole.com" },
      ac.list_items[2].id.to_s => { :content => "Ajax design patterns" }
    }

    assert_difference "ArticleListItem.count", -1 do
      assert_difference "ac.list_items.count", -1 do
        ac.save!
        ac.reload
      end
    end
  end

  def test_labels_for_article
    assert_difference "ActsAsTaggableOn::Tag.count", 2 do
      @article = Article.new(organization: programs(:org_primary), author: members(:f_mentor))
      @article.build_article_content(title: "Test title", body: "Test body", 'type' => "text", label_list: "ABC, XYZ", status: ArticleContent::Status::PUBLISHED)
      @article.save!
    end
    assert_equal ["ABC", "XYZ"], @article.label_list

    assert_no_difference "ActsAsTaggableOn::Tag.count" do
      @article.article_content.update_attributes(label_list: "MBA, animals")
    end
    assert_equal ["mba", "animals"], @article.reload.label_list
  end

  def test_change_labels_for_existing_articles
    @article = articles(:economy)
    assert_equal ["mba"], @article.label_list

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Article, [@article.id]).once
    assert_no_difference "ActsAsTaggableOn::Tag.count" do
      @article.article_content.update_attributes(label_list: "MBA, animals")
    end
    assert_equal ["mba", "animals"], @article.reload.label_list
  end

  def test_should_not_create_media_article_without_embed_code
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :embed_code) do
      ArticleContent.create!(:type => "media", :status => ArticleContent::Status::PUBLISHED)
    end
  end

  def test_should_create_new_media_article
    assert_difference("ArticleContent.count", 1) do
      create_article(:type => "media", :embed_code => "Abc", :status => ArticleContent::Status::PUBLISHED)
    end

    a = ArticleContent.last
    assert_equal("media", a.type)
    assert_equal("Abc", a.embed_code)
  end

  def test_validate_attachment_on_create

    #Validate an attachment which is invalid(Not an allowed type AND Not within attachment_size limits).
    a = ArticleContent.new(
      :title => 'test',
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment_file_name => 'some_file.txt',
      :attachment_file_size => 21.megabytes
    )

    assert_false a.valid?
    assert a.errors[:attachment]

    #Validate an attachment which is invalid(Not within attachment_size limits).
    a = ArticleContent.new(
      :title => 'test',
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment_file_name => 'some_file.pdf',
      :attachment_file_size => 21.megabytes,
      :attachment_content_type => "application/pdf"
    )
    
    assert_false a.valid?
    assert a.errors[:attachment]

    #Validate an attachment which is invalid(Not an allowed type of file).
    a = ArticleContent.new(
      :title => 'test',
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    )

    assert_false a.valid?
    assert a.errors[:attachment]

    #Validate the type of article(i.e., UPLOAD_ARTICLE as a allowed type of article included in addition to MEDIA, LIST, TEXT ).
    a = ArticleContent.new(
      :title => 'test',
      :type => 'not an allowed type',
      :status => ArticleContent::Status::PUBLISHED
    )

    assert_false a.valid?
    assert a.errors[:type]

    #Validate an attachment which is VALID.
    a = ArticleContent.new(
      :title => 'test',
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment_file_name => "some_file.pdf",
      :attachment_file_size => 20.megabytes,
      :attachment_content_type => "application/pdf"
    )

    assert a.valid?
  end

  def test_validate_Attachment_file_name
    a = ArticleContent.new(
      :title => 'test',
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment_file_name => "some_file.php",
      :attachment_file_size => 1.megabytes,
      :attachment_content_type => "application/octet-stream"
    )

    assert_false a.valid?
  end

  def test_attachment_is_required_only_for_upload_type
    content = ArticleContent.new(:title => "New", :type => ArticleContent::Type::TEXT, :status => ArticleContent::Status::PUBLISHED)
    content.valid?
    assert_blank content.errors[:attachment]

    content.type = ArticleContent::Type::UPLOAD_ARTICLE
    content.valid?
    assert content.errors[:attachment]
  end

  def test_article_has_uploaded_content
    a1 = ArticleContent.new(
      :title => 'test',
      :type => ArticleContent::Type::LIST,
      :status => ArticleContent::Status::PUBLISHED
    )
    assert_false a1.uploaded_content?

    a2 = ArticleContent.new(
      :title => 'test',
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment_file_name => 'some_file.txt',
      :attachment_file_size => 6.megabytes
    )

    assert a2.uploaded_content?
  end

  def test_should_remove_allowscriptaccess_in_media_during_article_content_before_save
    embed_code = '<object width="425" height="344"><param name="movie" value="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;"><param name="allowFullScreen" value="true"><param name="allowscriptaccess" value="always"><embed src="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="425" height="344"></object>'
    body = "Video desc"
    article = create_article(:type => "media", :embed_code => embed_code, :body => body)
    article_content = article.article_content
    article_content.current_member = members(:f_admin)
    article_content.sanitization_version = "v1"
    article_content.update_attribute(:embed_code , embed_code + " ")
    assert_match "<param name=\"allowscriptaccess\" value=\"never\">", article_content.embed_code
  end

  def test_after_save_es_reindex_article
    article_content = article_contents(:economy)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Article, [articles(:economy).id])
    article_content.update_attributes!(title: "Test 1")
    # should not reindex
    article_content.update_attributes!(updated_at: Time.now)
  end

  private
  def create_list_article_content
    a = ArticleContent.new(:type => ArticleContent::Type::LIST, :title => "test title", :status => ArticleContent::Status::PUBLISHED)
    a.list_items << SiteListItem.new(:content => "http://url.com")
    a.save!
    return a
  end
end