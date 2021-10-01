require_relative './../test_helper.rb'

class ArticlesControllerTest < ActionController::TestCase

  def test_should_get_new
    users(:f_mentor).program.organization.customized_terms.find_by(term_type: CustomizedTerm::TermType::ARTICLE_TERM).update_attribute :articleized_term_downcase, "a resource"
    current_user_is :f_mentor

    get :new
    assert_response :success
    assert_page_title "Pick an article type"
    assert_equal "mba,locations,animals", assigns(:tag_names)
  end

  def test_student_cannot_get_new_page
    current_user_is :f_student

    assert_permission_denied { get :new }
  end

  def test_should_create_text_article_draft
    current_user_is :f_mentor

    assert_difference 'Article.count', 1 do
      assert_difference "ArticleContent.count", 1 do
        assert_no_difference 'ActsAsTaggableOn::Tag.count' do
          post :create, params: { :article => {
            :article_content => {
              :title => "New article title",
              :type => ArticleContent::Type::TEXT,
              :body => "This is the body",
              :label_list => "mba, locations",
              :status => ArticleContent::Status::DRAFT
            },
            :publish_to => "#{programs(:albers).id},#{programs(:ceg).id}"
          }}
        end
      end
    end

    ac = assigns(:article).article_content
    assert_equal(1, ac.articles.size)

    article = ac.articles[0]
    assert_redirected_to(edit_article_path(article))

    assert_equal("New article title", article.title)
    assert_equal("This is the body", article.body)
    assert_equal(members(:f_mentor), article.author)
    assert_equal([], article.published_programs)
    assert_equal_unordered(["locations","mba"], article.label_list)
    assert(article.draft?)
  end

  def test_should_create_text_article_draft_with_vulnerable_content_with_version_v1_as_mentor
    current_user_is :f_mentor
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_difference 'Article.count', 1 do
        assert_difference "ArticleContent.count", 1 do
          assert_no_difference 'ActsAsTaggableOn::Tag.count' do
            post :create, params: { :article => {
              :article_content => {
                :title => "New article title",
                :type => ArticleContent::Type::TEXT,
                :body => "This is the body<script>alert(10);</script>",
                :label_list => "mba, locations",
                :status => ArticleContent::Status::DRAFT
              },
              :publish_to => "#{programs(:albers).id},#{programs(:ceg).id}"
            }}
          end
        end
      end
    end
  end

  def test_should_show_text_article_with_version_v1
    current_user_is :f_mentor
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    article = articles(:economy)
    article_content = article_contents(:economy)
    article_content.update_attributes(:body => "TEST <em>italic</em> <u>Underline</u>")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: article.title}).once
    get :show, params: { :id => article.id}
    assert_response :success
    assert_match "TEST <em>italic</em> <u>Underline</u>", response.body
  end

  def test_should_create_text_article_draft_with_vulnerable_content_with_version_v2_as_mentor
    current_user_is :f_mentor
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_difference 'Article.count' do
        assert_difference "ArticleContent.count" do
          assert_no_difference 'ActsAsTaggableOn::Tag.count' do
            post :create, params: { :article => {
              :article_content => {
                :title => "New article title",
                :type => ArticleContent::Type::TEXT,
                :body => "This is the body<script>alert(10);</script>",
                :label_list => "mba, locations",
                :status => ArticleContent::Status::DRAFT
              },
              :publish_to => "#{programs(:albers).id},#{programs(:ceg).id}"
            }}
          end
        end
      end
    end

    assert_equal ArticleContent.last.body, "This is the bodyalert(10);"
  end

  def test_should_create_text_article_draft_with_vulnerable_content_with_version_v1_as_admin
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_difference 'Article.count', 1 do
        assert_difference "ArticleContent.count", 1 do
          assert_no_difference 'ActsAsTaggableOn::Tag.count' do
            post :create, params: { :article => {
              :article_content => {
                :title => "New article title",
                :type => ArticleContent::Type::TEXT,
                :body => "This is the body<script>alert(10);</script>",
                :label_list => "mba, locations",
                :status => ArticleContent::Status::DRAFT
              },
              :publish_to => "#{programs(:albers).id},#{programs(:ceg).id}"
            }}
          end
        end
      end
    end
  end

  def test_should_create_text_article_draft_with_vulnerable_content_with_version_v2_as_admin
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_difference 'Article.count', 1 do
        assert_difference "ArticleContent.count", 1 do
          assert_no_difference 'ActsAsTaggableOn::Tag.count' do
            post :create, params: { :article => {
              :article_content => {
                :title => "New article title",
                :type => ArticleContent::Type::TEXT,
                :body => "This is the body<script>alert(10);</script>",
                :label_list => "mba, locations",
                :status => ArticleContent::Status::DRAFT
              },
              :publish_to => "#{programs(:albers).id},#{programs(:ceg).id}"
            }}
          end
        end
      end
    end
  end

  def test_should_directly_publish_text_article
    current_user_is :f_mentor

    assert_difference 'Article.count' do
      assert_difference "ArticleContent.count" do
        assert_no_difference 'ActsAsTaggableOn::Tag.count' do
          post :create, params: { :article => {
            :article_content => {
              :title => "New article title",
              :type => ArticleContent::Type::TEXT,
              :body => "This is the body",
              :label_list => "mba, locations",
              :status => ArticleContent::Status::PUBLISHED
            },
            :publish_to => "#{programs(:albers).id},#{programs(:moderated_program).id}"
          }}
        end
      end
    end

    ac = assigns(:article).article_content.reload
    assert_equal(1, ac.articles.size)
    article = ac.articles[0]
    assert_redirected_to(article_path(article))
    assert_equal("New article title", article.title)
    assert_equal("This is the body", article.body)
    assert_equal(members(:f_mentor), article.author)
    assert_equal([programs(:albers), programs(:moderated_program)], article.published_programs)
    assert_equal_unordered(["locations", "mba"], article.label_list)
    assert(article.published?)
  end

  def test_should_create_publication_for_article_published_in_current_program_only
     current_user_is :f_mentor

    assert_difference 'Article.count', 1 do
      assert_difference "ArticleContent.count", 1 do
        assert_no_difference 'ActsAsTaggableOn::Tag.count' do
          post :create, params: { :article => {
            :article_content => {
              :title => "New article title",
              :type => ArticleContent::Type::TEXT,
              :body => "This is the body",
              :label_list => "mba, locations",
              :status => ArticleContent::Status::PUBLISHED
            }
          }}
        end
      end
    end
    ac = assigns(:article).article_content.reload
    art = ac.articles[0]
    assert_equal([users(:f_mentor).program], art.published_programs)

  end

  def test_student_cannot_create_article
    current_user_is :f_student

    assert_permission_denied do
      post :create, params: { :article => {
        :article_content => {
          :title => "New article title",
          :body => "This is the body"
        }
      }}
    end
  end

  def test_create_text_article_failure
    current_user_is :f_mentor

    post :create, params: { :article => {
      :article_content => {
        :title => "",
        :body => "This is the body",
        :type => ArticleContent::Type::TEXT,
        :status => ArticleContent::Status::PUBLISHED
      }
    }}
    article = assigns(:article)
    assert_response :success

    assert_equal(["can't be blank"], article.article_content.errors[:title])
    assert_equal("This is the body", article.body)
    assert_template "new_text"
    assert_ckeditor_rendered
  end

  def test_update_article_with_virus_attachment
    current_user_is :f_mentor
    art = articles(:kangaroo)
    ArticleContent.any_instance.expects(:update_attributes).at_least(1).raises(VirusError)
    assert_no_difference 'Article.count' do
      put :update, params: { id: art.id, article: {
        article_content: {
          attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'),
          status: ArticleContent::Status::PUBLISHED
        }
      }}
    end
    assert_template "articles/_hidden_fields_and_buttons"
    assert_equal "Our security system has detected the presence of a virus in the attachment.", flash[:error]
  end

  def test_update_draft_with_virus_attachment
    current_user_is :f_mentor
    art = articles(:draft_article)
    ArticleContent.any_instance.expects(:update_attributes).at_least(1).raises(VirusError)
    assert_no_difference 'Article.count' do
      put :update, params: { id: art.id, article: {
        article_content: {
          attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'),
          status: ArticleContent::Status::DRAFT
        }
      }}
    end
    assert_template "articles/_hidden_fields_and_buttons"
    assert_equal "Our security system has detected the presence of a virus in the attachment.", flash[:error]
  end

  def test_create_article_with_virus
    current_user_is :f_mentor
    Article.any_instance.expects(:save).at_least(1).raises(VirusError)
    assert_no_difference 'Article.count' do
      post :create, params: { article: {
        article_content: {
          title: "New article title",
          type: ArticleContent::Type::UPLOAD_ARTICLE,
          attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'),
          body: "This is the body",
          status: ArticleContent::Status::PUBLISHED
        }
      }}
    end
    assert_redirected_to new_article_path(type: ArticleContent::Type::UPLOAD_ARTICLE)
    assert_equal "Our security system has detected the presence of a virus in the attachment.", flash[:error]
  end

  def test_create_draft_upload_article_with_virus
    current_user_is :f_mentor
    Article.any_instance.expects(:save).at_least(1).raises(VirusError)
    assert_no_difference 'Article.count' do
      post :create, params: { article: {
        article_content: {
          title: "New Draft article",
          type: ArticleContent::Type::UPLOAD_ARTICLE,
          attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'),
          body: "This is the body",
          status: ArticleContent::Status::DRAFT
        }
      }}
    end
    assert_redirected_to new_article_path(type: ArticleContent::Type::UPLOAD_ARTICLE)
    assert_equal "Our security system has detected the presence of a virus in the attachment.", flash[:error]
  end

  def test_should_update_article_by_mentor
    current_user_is :f_mentor
    art = articles(:kangaroo)
    assert_equal("Australia Kangaroo extinction", art.title)

    post :update, params: { :id => art.id, :article => {
      :article_content => {
        :title => "This is the new title",
        :body => "This is the body"
      }
    }}

    assert_redirected_to article_path(art.reload)
    assert_equal("This is the new title", art.title)
    assert_equal("This is the body", art.body)
  end

  def test_edit_article_should_not_show_save_draft
    current_user_is :f_mentor
    art = articles(:kangaroo)
    assert_equal("Australia Kangaroo extinction", art.title)
    assert(art.published?)

    get :edit, params: { :id => art.id}
    assert_response :success
    assert_no_select "input[value='Save Draft']"
    assert_select "input[value='Update']"
  end

  def test_should_update_article_by_admin
    current_user_is :f_admin
    art = articles(:kangaroo)
    assert_equal("Australia Kangaroo extinction", art.title)

    post :update, params: { :id => art.id, :article => {
      :article_content => {
        :title => "This is the new title",
        :body => "This is the body"
      }
    }}

    assert_equal("This is the new title", art.reload.title)
    assert_equal("This is the body", art.body)
  end

  def test_should_mark_article_as_helpful
    current_user_is :f_student
    art = articles(:kangaroo)
    assert_equal(0, art.helpful_count)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LIKE_ARTICLE, {context_object: art.title}).once
    post :rate, xhr: true, params: { :id => art.id, :useful => 1}
    assert_equal(1, art.reload.helpful_count)
    assert_response :success
  end

  def test_should_mark_article_as_helpful_logged_out
    current_organization_is :org_primary
    art = articles(:kangaroo)
    assert_equal(0, art.helpful_count)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LIKE_ARTICLE, {context_object: art.title}).never
    post :rate, xhr: true, params: { :id => art.id, :useful => 1}
    assert_response :unauthorized
  end

  def test_should_mark_article_as_helpful_logged_out_custom_auth
    ac = programs(:org_primary).auth_configs.first
    ac.update_attributes(:auth_type => AuthConfig::Type::OPENSSL)
    ac.set_options!("url" => "http://google.com", "private_key" => "abcd")
    current_organization_is :org_primary
    art = articles(:kangaroo)
    assert_equal(0, art.helpful_count)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LIKE_ARTICLE, {context_object: art.title}).never
    post :rate, xhr: true, params: { :id => art.id, :useful => 1}
    assert_equal "window.location.href = \"/session/new\";", @response.body
    assert_response :unauthorized
  end

  def test_should_unmark_article_as_helpful
    current_user_is :f_student
    art = articles(:kangaroo)
    viewer = members(:f_student)
    art.mark_as_helpful!(viewer)
    art.reload
    assert(art.rated_by_user?(viewer))
    assert_equal(1, art.helpful_count)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LIKE_ARTICLE, {context_object: art.title}).never
    post :rate, xhr: true, params: { :id => art.id, :useful => -1}
    assert_equal(0, art.reload.helpful_count)
    assert_response :success
  end

  def test_should_delete_article
    art = articles(:kangaroo)
    current_user_is users(:f_mentor)

    flag = create_flag(content: art)
    assert flag.unresolved?
    assert_difference("Article.count", -1) do
      post :destroy, params: { :id => art.id}
      assert_redirected_to articles_path
    end
    assert_equal Flag::Status::DELETED, flag.reload.status
  end

  def test_should_not_allow_non_author_to_delete_article
    art = articles(:kangaroo)
    assert_equal(members(:f_mentor), art.author)
    current_user_is :f_mentor_student

    assert_no_difference("Article.count") do
      assert_permission_denied do
        post :destroy, params: { :id => art.id}
      end
    end
  end

  def test_should_show_article_for_non_author
    @art = articles(:kangaroo)
    viewer = users(:f_student)
    assert(!viewer.member.authored?(@art))
    current_user_is viewer
    assert_equal(0, @art.view_count)

    3.times { Comment.create!(
        :publication => @art.get_publication(programs(:albers)),
        :user => users(:f_mentor),
        :body => "Abc")
    }

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object:@art.title}).once
    get :show, params: { :id => @art.id}
    assert_response :success
    assert_equal 1, @art.reload.view_count
    assert_equal 3, assigns(:comments_count)
    assert_template 'show'
    assert_select "a.rating_link", :text => "Like"
    assert_no_select "a.ct_edit_article"
    assert_select "form.cjs_comment_form"
    assert_select "div.cjs_comments_container"
  end

  def test_should_show_article_for_a_user_who_has_already_rated_the_article
    art = articles(:kangaroo)
    viewer = users(:f_student)
    art.mark_as_helpful!(viewer.member)
    art.reload
    assert art.rated_by_user?(viewer.member)
    current_user_is viewer

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: art.title}).once
    get :show, params: { :id => art.id}
    assert_response :success
    assert_equal(1, art.reload.view_count)
    assert_template 'show'

    assert_select "a.rating_link", :text => "1Like"
    assert_no_select "ul#quick_links"
  end

  def test_should_show_article_for_author
    art = articles(:kangaroo)
    users(:f_mentor_nwen_student).add_role(RoleConstants::MENTOR_NAME)
    current_user_is users(:f_mentor)
    assert_equal(0, art.view_count)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: art.title}).once
    get :show, params: { :id => art.id}
    assert_response :success
    assert_equal(0, art.reload.view_count)
    assert_template 'show'
    # Author should get quick links
    assert_select "a.ct_edit_article"
    assert_select "a.rating_link"
  end

  def test_articles_index_no_results
    current_user_is :foster_admin

    get :index
    assert_response :success
    assert_equal(0, assigns(:articles).size)
    assert assigns(:program_labels_with_count).empty?
  end

  def test_articles_search
    current_user_is :f_student

    get :index, params: { :search => 'economy'}
    assert_equal(1, assigns(:articles).size)
    assert_equal(articles(:economy), assigns(:articles).first)

    label_counts = {"animals"=>1, "locations"=>2, "mba"=>1}
    assert_equal label_counts, assigns(:program_labels_with_count)
  end

  def test_make_sure_properly_escaped
    current_user_is :f_student
    assert_nothing_raised do
      get :index, params: { :search => 'economy/'}
    end
    assert_response :success
    assert_equal(1, assigns(:articles).size)
    assert_equal(articles(:economy), assigns(:articles).first)

    label_counts = {"animals"=>1, "locations"=>2, "mba"=>1}
    assert_equal label_counts, assigns(:program_labels_with_count)
  end

  def test_articles_list_with_label
    users(:f_student).program.customized_terms.find_by(term_type: CustomizedTerm::TermType::ARTICLE_TERM).update_attribute :pluralized_term, "Resources"
    current_user_is :f_student

    get :index, params: { :label => fetch_article_label_by_name("locations").name}
    assert_equal(2, assigns(:articles).size)
    assert_equal_unordered([articles(:delhi), articles(:india)].collect(&:id), assigns(:articles).collect(&:id))
    assert_select "div#article_labels"
    assert_page_title "Resources labeled 'locations'"
  end

  def test_articles_search_a_non_existent_article
    current_user_is :f_student

    get :index, params: { :search => 'n0suchfraser'}
    assert_equal(0, assigns(:articles).size)
  end

  def test_should_show_related_articles_if_there_are_any
    art = articles(:economy)
    current_user_is :f_student

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: art.title}).once
    get :show, params: { :id => art.id}
    assert_equal(art, assigns(:article))
    assert_equal([articles(:india)], assigns(:related_articles).to_a)
  end

  def test_should_show_not_show_related_articles_if_there_are_no_related_articles
    art = articles(:kangaroo)
    current_user_is :f_student

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: art.title}).once
    get :show, params: { :id => art.id}
    assert_equal(art, assigns(:article))
    assert_equal([], assigns(:related_articles).to_a)
  end

  def test_should_get_new_text_article_page
    current_user_is :f_mentor
    create_user(:member => members(:f_mentor), :role_names => ['mentor'], :program => programs(:ceg))

    get :new, params: { :type => "text"}
    assert_template 'new_text'
    assert_select "textarea#article_body"
    assert_equal "mba,locations,animals", assigns(:tag_names)
    back_link = {:label=>"Articles", :link=>"/p/albers/articles"}
    assert_equal back_link, assigns[:back_link]
    assert_no_select "a.discard_draft"
    assert_select "input[value='Post']"
  end

  def test_should_get_new_media_article_page
    current_user_is :f_mentor
    get :new, params: { :type => "media"}
    assert_template 'new_media'

    assert_select "textarea#article_article_content_embed_code"
    assert_equal "mba,locations,animals", assigns(:tag_names)
    assert_no_select "a.discard_draft"
    assert_select "input[value='Post']"
  end

  def test_should_render_media_article
    embed_code = "youtube video"
    body = "Video desc"
    art = create_article(:type => "media", :embed_code => embed_code, :body => body)

    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: art.title}).once
    get :show, params: { :id => art.id}
    assert_template 'show'
    assert_select "div#embedded_content", :text => /#{embed_code}/
    assert_select 'div.description', :text => body
  end

  def test_should_get_new_list_article_page
    current_user_is :f_mentor

    get :new, params: { :type => 'list'}
    assert_response :success
    assert_template 'new_list'

    assert_select 'div#article_list_items' do
      assert_select "div#empty_list"
      assert_select "div.article_list_item", :count => 0
    end
    assert_select '#add_items_links'
    assert_equal "mba,locations,animals", assigns(:tag_names)
    assert_no_select "a.discard_draft"
    assert_select "input[value='Post']"
  end

  def test_should_get_edit_list_article_page
    current_user_is :f_mentor
    article = create_list_article
    assert article.published?
    article2 = programs(:org_anna_univ).articles.create!(
      {
        :author_id => members(:f_mentor_ceg).id,
        :article_content_id => article.article_content.id,
        :published_programs => [programs(:ceg)]
        }
    )

    get :edit, params: { :id => article.id}
    assert_template 'new_list'
    back_link = {:label=>"Articles", :link=>"/p/albers/articles"}
    assert_equal back_link, assigns[:back_link]

    assert_select 'div.article_list_item', :count => 2
    assert_select 'div.article_list_item' do
      assert_select "input[type=hidden][name=?][value='BookListItem']", "article[article_content][existing_listitem_attributes][#{article.list_items.last.id}][type_string]"
      assert_select 'input[value=?]', "The Google Story"
    end

    assert_select 'div.article_list_item' do
      assert_select "input[type=hidden][name=?][value='SiteListItem']", "article[article_content][existing_listitem_attributes][#{article.list_items.first.id}][type_string]"
      assert_select 'input[value=?]', "http://url.com"
    end
    assert_equal "mba,locations,animals", assigns(:tag_names)
    assert_select "input[value='Update']"
  end

  def test_should_get_new_upload_article_page
    current_user_is :f_mentor

    get :new, params: { :type => 'upload_article'}
    assert_response :success
    assert_template "new_upload_article"

  end

  def test_add_attachment
    current_user_is :f_admin

    art = articles(:kangaroo)
    assert !art.article_content.attachment?

    post :update, params: { :id => art.id, :article => {
      :article_content => {
        :type => ArticleContent::Type::UPLOAD_ARTICLE,
        :attachment => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
    }}

    assert art.reload.article_content.attachment?
  end

  def test_remove_attachment
    current_user_is :f_admin

    art = articles(:kangaroo)
    assert !art.article_content.attachment?

    post :update, params: {
        :id => art.id,
        :article => {
      :article_content => {
        :type => ArticleContent::Type::UPLOAD_ARTICLE,
        :attachment => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      }
    },
        :remove_attachment => true}

    assert !art.article_content.attachment?
  end

  def test_should_create_draft_of_list_article
    current_user_is :f_mentor

    assert_difference "Article.count", 1 do
      assert_difference("ArticleContent.count", 1) do
        post :create, params: { :article => {
          :article_content => {
            :title => "This title",
            :type => ArticleContent::Type::LIST,
            :status => ArticleContent::Status::DRAFT,
            :new_listitem_attributes => {
              47477474 => { :type_string => 'BookListItem', :content => "The White Tiger", description: "Booker Prize" },
              883883883 => { :type_string => "SiteListItem", :content => "http://google.com" }
            }
          },
          :publish_to => "albers,ceg"
        }}
      end
    end

    a = Article.last
    assert_equal("Your draft has been saved. You can continue editing the list.", flash[:notice])
    assert_redirected_to edit_article_path(a)
    assert_equal('This title', a.title)
    assert_equal(2, a.list_items.size)
    assert(a.draft?)
  end

  def test_should_create_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      assert_no_difference "Article.count" do
        assert_no_difference("ArticleContent.count") do
          post :create, params: { :article => {
            :article_content => {
              :title => "This title",
              :type => ArticleContent::Type::LIST,
              :status => ArticleContent::Status::DRAFT,
              :new_listitem_attributes => {
                47477474 => { :type_string => 'User', :content => "The White Tiger" }
              }
            },
            :publish_to => "albers,ceg"
          }}
        end
      end
    end
  end

  def test_should_publish_list_article
    current_user_is :f_mentor

    assert_difference "Article.count", 1 do
      post :create, params: { :article => {
        :article_content => {
          :title => "This title",
          :type => ArticleContent::Type::LIST,
          :status => ArticleContent::Status::PUBLISHED,
          :new_listitem_attributes => {
            47477474 => { :type_string => 'BookListItem', :content => "The White Tiger" },
            883883883 => { :type_string => "SiteListItem", :content => "http://google.com" }
          }
        }
      }}
    end

    a = Article.last
    assert_redirected_to article_path(a)
    assert_equal('This title', a.title)
    assert_equal(2, a.list_items.size)
  end

  def test_list_article_creation_failure
    current_user_is :f_mentor

    assert_difference "Article.count", 1 do
      post :create, params: { :article => {
        :article_content => {
          :title => "This title",
          :type => ArticleContent::Type::LIST,
          :status => ArticleContent::Status::PUBLISHED
        }
      }}
    end

    assert_template 'new_list'
    a = Article.last
    assert a.draft?
  end

  def test_should_render_list_article
    current_user_is :f_student
    create_list_article
    stub_amazon_response_for("The Google Story")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: Article.last.title}).once
    get :show, params: { :id => Article.last}
    assert_template 'show'
    assert_equal(Article.last, assigns(:article))
    a = assigns(:article)

    # Test the mocked amazon response item
    assert_equal('http://amazon.com/book.jpg', a.list_items[1].presenter.image_link)
    assert_equal('Arthur Wilson', a.list_items[1].presenter.author)
    assert_equal('http://amazon.com/book1.html', a.list_items[1].presenter.amazon_link)
    assert_equal(a.list_items[1], a.list_items[1].presenter.list_item)

    assert_select "div#view_article" do
      assert_select "div#list_item_#{a.list_items[0].id}" do
        assert_select 'script', :text => "stw_pagepix('http://url.com', '1390f7b3796fd1b', 'vsm', 0);"
      end

      assert_select "div#list_item_#{a.list_items[1].id}" do
        assert_select 'img[src=?]', "http://amazon.com/book.jpg"
        assert_select 'h4.book_details' do
          assert_select 'span.author', :text => "By Arthur Wilson"
        end
      end
    end
  end

  def test_should_update_list_article
    current_user_is :f_mentor
    a = create_list_article
    assert_equal(2, a.list_items.size)

    # Post 2 new items, update an existing item, delete an existing item
    assert_difference("ArticleListItem.count", 1) do
      post :update, params: { :id => a.id, :article => {
        :article_content => {
          :title => "This new title",
          :type => ArticleContent::Type::LIST,
          :label_list => "new, latest",
          :new_listitem_attributes => {
            1212312 => { :type_string => 'BookListItem', :content => "The White Tiger" },
            "temp_id_123" => { :type_string => "SiteListItem", :content => "http://google.com" }
          }, :existing_listitem_attributes => {
            a.list_items[0].id.to_s => { :content => "http://anothe.com", description: "Desc." }
          }
        }
      }}
    end

    a = Article.last
    assert_redirected_to article_path(a)
    assert_equal('This new title', a.title)
    assert_equal(3, a.list_items.size)
    assert_equal(["new", "latest"], a.label_list)

    item_titles = a.list_items.collect(&:content)
    assert_equal_unordered(['http://anothe.com', 'The White Tiger', 'http://google.com'], item_titles)
    assert_equal "Desc.", a.list_items.find_by(content: "http://anothe.com").description
  end

  def test_list_item_id
    current_user_is :f_mentor
    #Testing changes in following partials:
    #articles/book_list_item
    #articles/site_list_item
    SecureRandom.expects(:random_number).with(MAX_INT32).twice
    get :new_list_item, xhr: true, params: { type: 'book_list_item' }
    get :new_list_item, xhr: true, params: { type: 'site_list_item' }
  end

  def test_update_permission_denied
    current_user_is :f_mentor
    a = create_list_article
    assert_equal(2, a.list_items.size)

    assert_permission_denied do
      post :update, params: { :id => a.id, :article => {
        :article_content => {
          :title => "This new title",
          :type => ArticleContent::Type::LIST,
          :label_list => "new, latest",
          :new_listitem_attributes => {
            1212312 => { :type_string => 'User', :content => "The White Tiger" },
            "temp_id_123" => { :type_string => "Member", :content => "http://google.com" }
          }, :existing_listitem_attributes => {
            a.list_items[0].id.to_s => { :content => "http://anothe.com" }
          }
        }
      }}
    end
  end

  def test_list_article_update_failure
    current_user_is :f_mentor
    a = create_list_article
    assert_equal(2, a.list_items.size)

    # Try deleting all items
    assert_difference("ArticleListItem.count", 0) do
      post :update, params: { :id => a.id, :article => {
        :article_content => {
          :title => "This new title",
          :type => ArticleContent::Type::LIST
        }
      }}
    end

    assert_equal("Test title", a.reload.title)
    assert_equal(2, a.list_items.size)
    assert_template 'new_list'
  end

  def test_should_get_new_site_list_item
    current_user_is :f_mentor

    get :new_list_item, xhr: true, params: { :type => 'site_list_item'}
    assert_response :success
    assert_match(/SiteListItem/, @response.body.to_s)
  end

  def test_should_get_new_book_list_item
    current_user_is :f_mentor

    get :new_list_item, xhr: true, params: { :type => 'book_list_item'}
    assert_response :success
    assert_match(/BookListItem/, @response.body.to_s)
  end

  def test_should_raise_exception_for_invalid_type
    current_user_is :f_mentor

    assert_permission_denied do
      get :new_list_item, xhr: true, params: { :type => 'invalid_type'}
    end
  end

  def test_should_get_autocomplete_for_title
    current_user_is :f_mentor
    book_title = "Hunt"
    mock_items = [
      mock('item1') { expects(:get).with("ItemAttributes/Title").returns("Hunter and the hunted") },
      mock('item2') { expects(:get).with("ItemAttributes/Title").returns("Hunting in the jungle") },
      mock('item3') { expects(:get).with("ItemAttributes/Title").returns("Andy hunt") },
      mock('item4') { expects(:get).with("ItemAttributes/Title").returns("Whatever hunt") }
    ]
    response_mock = mock("amazon_response") do
      expects(:items).returns(mock_items)
    end
    Amazon::Ecs.expects(:item_search).with(nil, {:response_group => 'Small', :power => "title:*#{book_title}*"}).returns(response_mock)

    get :auto_complete_for_title, xhr: true, params: { :title => book_title, :format => :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Hunter and the hunted", "Hunting in the jungle", "Andy hunt", "Whatever hunt"], JSON.parse(@response.body)
  end

  def test_should_publish_a_draft_article
    art = articles(:draft_article)
    assert art.draft?

    current_user_is users(:f_mentor)

    assert_equal("Draft article", art.title)
    assert_equal(1, art.article_content.articles.size)

    assert_no_difference("Article.count") do
      assert_no_difference("ArticleContent.count") do
        post :update, params: { :id => art.id, :article => {
          :article_content => {
            :title => "Published article",
            :body => "What",
            :type => ArticleContent::Type::TEXT,
            :status => ArticleContent::Status::PUBLISHED
          },
          :publish_to => "#{programs(:albers).id},#{programs(:moderated_program).id}"
        }}
      end
    end

    assert_redirected_to article_path(art)
    ac = art.article_content.reload
    art.reload
    assert_equal(1, ac.articles.size)
    assert_equal_unordered([art], ac.articles)
    assert_equal("Your #{art.organization.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term_downcase} has been successfully published", flash[:notice])
    assert(ac.published?)
    assert(art.reload)
  end

  def test_draft_publish_failure_should_render_edit
    art = articles(:draft_article)
    assert art.draft?

    current_user_is users(:f_mentor)

    assert_no_difference("Article.count") do
      assert_no_difference("ArticleContent.count") do
        post :update, params: { :id => art.id, :article => {
          :article_content => {
            :title => "", # Title can't be blank
            :status => ArticleContent::Status::PUBLISHED
          },
          :publish_to => "#{programs(:albers).id},#{programs(:ceg).id}"
        }}
      end
    end

    assert_response :success
    assert_template 'articles/new_text'
    assert_equal(["can't be blank"], assigns(:article).article_content.errors[:title])
  end

  def test_should_update_draft
    art = articles(:draft_article)
    assert art.draft?

    current_user_is users(:f_mentor)

    post :update, params: { :id => art.id, :article => {
      :article_content => {
        :title => "Updated draft",
        :status => ArticleContent::Status::DRAFT
      }
    }}

    art.reload
    assert_redirected_to edit_article_path(art)
    assert_equal("Updated draft", art.reload.title)
    assert art.draft?
  end

  def test_update_draft_failure_should_render_edit
    art = articles(:draft_article)
    assert art.draft?

    current_user_is users(:f_mentor)

    # Simulate update failure
    ArticlesController.any_instance.expects(:update_article_content).returns(false)

    post :update, params: { :id => art.id, :article => {
      :article_content => {
        :title => "Updated draft",
      }
    }}

    assert_response :success
    assert_template 'new_text'
  end

  def test_should_raise_exception_for_invalid_status_update
    art = articles(:draft_article)
    assert art.draft?

    current_user_is users(:f_mentor)

    e = assert_raise RuntimeError do
      post :update, params: { :id => art.id, :article => {
        :article_content => {
          :title => "Updated draft",
          :status => 123
        }
      }}
    end
    assert_equal("Invalid Update Status", e.message)
  end

  def test_should_edit_draft
    art = articles(:draft_article)
    assert art.draft?

    current_user_is users(:f_mentor)

    get :edit, params: { :id => art.id}
    assert_response :success
    assert_select "a", :class => "discard_draft"
    assert_select "input[value='Post']"
  end

  def test_should_not_show_draft_articles
    art = articles(:draft_article)
    assert art.draft?

    current_user_is users(:f_mentor)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: art.title}).never
    assert_permission_denied do
      get :show, params: { :id => art.id}
    end
  end

  def test_should_show_drafts_warning_for_author_in_new_article_page
    art = articles(:draft_article)
    current_user_is users(:f_mentor)

    get :new
    assert_response :success
    assert_select "#pending_drafts_message"

  end

  def test_should_show_drafts_warning_for_author_in_articles_index_page
    art = articles(:draft_article)
    current_user_is users(:f_mentor)

    get :index
    assert_response :success
    assert_select "#pending_drafts_message"
  end

  def test_should_not_show_drafts_warning_for_non_authors
    art = articles(:draft_article)
    assert_not_equal(art.author, members(:f_admin))
    current_user_is users(:f_admin)

    get :index
    assert_response :success
    assert_no_select "#pending_drafts_message"
  end

  def test_should_discard_draft
    art = articles(:draft_article)
    assert art.draft?
    current_user_is users(:f_mentor)

    assert_difference("Article.count", -1) do
      assert_difference("ArticleContent.count", -1) do
        post :destroy, params: { :id => art.id}
      end
    end

    assert_equal("Your draft has been discarded", flash[:notice])
    assert_redirected_to member_path(art.author, :tab => 'articles')
  end

  def test_chrome_first_time_issue_check_response_with_verification_token
    current_user_is :f_mentor
    post :create, params: { :article => {
      :article_content => {
        :title => "Test",
        :body => "This is the body",
        :embed_code => "http://www.youtube.com/watch?v=hFeBccS8qFA",
        :type => ArticleContent::Type::MEDIA,
        :status => ArticleContent::Status::PUBLISHED
      },
      :publish_to => "#{programs(:albers).id}}"
    }}
    match_str = "http://test.host/p/albers/articles/#{assigns(:article).id}?verify=#{session["_verification_token"]}"
    assert_equal match_str, response.header["Location"]
  end

  def test_skip_x_xss_for_verified_request_on_chrome_success
    current_user_is :f_mentor
    article = articles(:kangaroo)
    session["_verification_token"] = "abcdef"
    Browser::Generic.any_instance.stubs(chrome?: true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: article.title}).once
    get :show, params: { id: article.id, verify: "abcdef"}
    assert_equal "0", response.headers["X-XSS-Protection"]
    assert_nil session["_verification_token"]
  end

  def test_skip_x_xss_for_verified_request_other_broswer
    current_user_is :f_mentor
    article = articles(:kangaroo)
    session["_verification_token"] = "abcdef"
    Browser::Generic.any_instance.stubs(chrome?: false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: article.title}).once
    get :show, params: { id: article.id, verify: "abcdef"}
    assert_equal "1; mode=block", response.headers["X-XSS-Protection"]
    assert_nil session["_verification_token"]
  end

  def test_skip_x_xss_for_non_verified_request
    current_user_is :f_mentor
    article = articles(:kangaroo)
    session["_verification_token"] = "abcdef"
    Browser::Generic.any_instance.stubs(chrome?: false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: article.title}).once
    get :show, params: { id: article.id, verify: "abcddd"}
    assert_equal "1; mode=block", response.headers["X-XSS-Protection"]
    assert_nil session["_verification_token"]
  end

  def test_skip_x_xss_for_blank_verify_token
    current_user_is :f_mentor
    article = articles(:kangaroo)
    session["_verification_token"] = "abcdef"
    Browser::Generic.any_instance.stubs(chrome?: false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: article.title}).once
    get :show, params: { id: article.id, verify: ""}
    assert_equal "1; mode=block", response.headers["X-XSS-Protection"]
  end

  def test_headers_for_no_cache_set
    current_user_is :f_mentor
    article = articles(:kangaroo)
    session["_verification_token"] = "abcdef"
    Browser::Generic.any_instance.stubs(chrome?: false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: article.title}).once
    get :show, params: { id: article.id, verify: "abcddd"}
    assert_equal response.headers["Cache-Control"], "no-store, no-cache"
    assert_equal response.headers["Pragma"], "no-cache"
  end

  def test_articles_listing_view_by_mentor
    current_member_is :anna_univ_mentor

    get :index
    assert_redirected_to programs_list_path
  end

  def test_articles_listing_view_by_student
    current_member_is :f_student

    get :index
    assert_redirected_to programs_list_path
  end

  def test_track1_admin_trying_to_manage_track2_articles
    current_user_is :f_mentor
    current_program_is :albers
    article = articles(:delhi)
    assert_not_equal members(:f_mentor), article.author
    assert_false users(:f_mentor_nwen_student).can_manage_articles?
    assert_false members(:f_mentor).can_manage_articles?
    add_role_permission(fetch_role(:nwen, :student), "manage_articles")
    users(:f_mentor_nwen_student).reload
    members(:f_mentor).reload
    assert users(:f_mentor_nwen_student).can_manage_articles?
    assert members(:f_mentor).can_manage_articles?
    assert_permission_denied do
      get :edit, params: { id: article.id}
    end
    assert_permission_denied do
      post :destroy, params: { id: article.id}
    end
  end

  private

  def create_list_article(opts = {})
    a = build_article(opts.merge(:type => ArticleContent::Type::LIST))
    a.list_items << SiteListItem.new(:content => "http://url.com")
    a.list_items << BookListItem.new(:content => "The Google Story")
    a.save!
    a
  end

  def stub_amazon_response_for(book_title, options = {})
    amazon_item = mock('amazon_item') do
      expects(:get_hash).times(2).with("MediumImage").returns({"URL" => "http://amazon.com/book.jpg"})
      expects(:get).times(2).with("DetailPageURL").returns("http://amazon.com/book1.html")
      expects(:get).times(2).with("ItemAttributes/Title").returns(book_title)
      expects(:get).with("ItemAttributes/Author").returns("Arthur Wilson")
    end
    response_mock = stub('res_mock', :items => [amazon_item])
    Amazon::Ecs.expects(:item_search).with(book_title, {:response_group => 'Images,Reviews,ItemAttributes'}).returns(response_mock)
  end

  def article_path(article, options = {})
    options.merge!({verify: session["_verification_token"]}) if session["_verification_token"].present?
    super
  end
end