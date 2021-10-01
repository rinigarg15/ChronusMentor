require_relative './../test_helper.rb'

class ArticleTest < ActiveSupport::TestCase
  def test_should_require_program_and_author_and_content
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Article.create!
    end

    assert_match(/Author can't be blank/, e.message)
    assert_match(/Organization can't be blank/, e.message)
    assert_match(/Article content can't be blank/, e.message)
  end

  def test_has_many_publications_and_published_programs
    assert_equal [programs(:albers)], articles(:economy).published_programs
    albers_publication = articles(:economy).publications.first

    publication_1 = create_article_publication(articles(:economy), programs(:nwen))
    publication_2 = create_article_publication(articles(:economy), programs(:moderated_program))

    articles(:economy).reload
    assert_equal [albers_publication, publication_1, publication_2], articles(:economy).publications
    assert_equal [programs(:albers), programs(:nwen), programs(:moderated_program)],
        articles(:economy).published_programs

    assert_no_difference 'Program.count' do
      assert_difference 'Article::Publication.count', -3 do
        assert_difference 'Article.count', -1 do
          articles(:economy).destroy
        end
      end
    end
  end

  def test_should_create_recent_activity_on_marking_as_helpful
    a = create_article

    RecentActivity.destroy_all
    assert_no_emails do
      assert_difference("RecentActivity.count", 1) do
        a.mark_as_helpful!(members(:f_student))
      end
    end

    r1 = RecentActivity.first

    assert_equal(RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL, r1.action_type)
    assert_equal(Article.last, r1.ref_obj)
    assert_equal(members(:f_student), r1.member)
    assert_equal([programs(:albers)], r1.programs)
    assert_equal(RecentActivityConstants::Target::USER, r1.target)
    assert_equal(a.author, r1.for)
  end

  def test_mark_helpful
    assert_equal(0, articles(:economy).rating)
    assert_difference("Rating.count", 1) do
      assert_difference("articles(:economy).reload.helpful_count", 1) do
        articles(:economy).mark_as_helpful!(members(:f_student))
      end
    end

    r = Rating.last
    assert_equal(articles(:economy), r.rateable)
    assert_equal(1, articles(:economy).rating)
  end

  def test_allow_authors_to_mark_helpful
    assert_equal(0, articles(:economy).rating)
    assert_difference("Rating.count", 1) do
      assert_difference("articles(:economy).reload.helpful_count", 1) do
        articles(:economy).mark_as_helpful!(articles(:economy).author)
      end
    end
  end

  def test_should_not_allow_members_from_other_programs_to_mark_helpful
    assert_no_difference("Rating.count") do
      assert_no_difference("articles(:economy).reload.helpful_count") do
        articles(:economy).mark_as_helpful!(members(:anna_univ_admin))
      end
    end
  end

  def test_unmark_as_helpful
    member = members(:f_student)

    articles(:economy).mark_as_helpful!(member)
    assert_equal(1, articles(:economy).rating)
    assert_difference("Rating.count", -1) do
      assert_difference("articles(:economy).reload.helpful_count", -1) do
        articles(:economy).unmark_as_helpful!(member)
      end
    end
  end

  def test_deleting_an_article_should_delete_the_article_content_if_no_other_org_publications
    assert_difference("RecentActivity.count", 2) do
      @article = create_article
      @article.mark_as_helpful!(members(:f_student))
    end

    assert_difference("RecentActivity.count", -2) do
      assert_difference("ArticleContent.count", -1) do
        assert_difference("Article.count", -1) do
          @article.destroy
        end
      end
    end
  end

  def test_related_articles
    assert_equal([articles(:anna_univ_psg_1)].collect(&:id), articles(:anna_univ_1).related(programs(:psg)).collect(&:id))
    assert_empty articles(:anna_univ_1).related(programs(:ceg)).collect(&:id)
    assert_equal([articles(:india)].collect(&:id), articles(:economy).related(programs(:albers)).collect(&:id))
    assert_equal([articles(:delhi), articles(:economy)].collect(&:id), articles(:india).related(programs(:albers)).collect(&:id))
    assert_empty articles(:kangaroo).related(programs(:albers)).collect(&:id)
  end

  def test_type
    a = Article.new
    a.build_article_content
    assert_nil(a.type)
    assert_equal("text", create_article.type)
    assert_equal("media", create_article(:type => 'media', :embed_code => "test").type)
  end

  def test_save_draft_and_publish_failure
    assert_difference("Article.count", 1) do
      assert_difference("ArticleContent.count", 1) do
        assert_no_difference("RecentActivity.count") do
          assert_no_emails do
            art, success = Article.create_draft(
              :organization => programs(:org_primary),
              :author => members(:f_mentor),
              :article_content => {
                :title => "", # Intentionally blank title
                :body => "Body",
                :type => ArticleContent::Type::TEXT,
                :status => ArticleContent::Status::DRAFT,
                :label_list => "draft, usb, nokia"
              }
            )

            assert success
          end
        end
      end
    end

    art = Article.last
    assert(art.draft?)
    assert(art.article_content.draft?)
    assert_equal(['draft', 'usb', 'nokia'], art.label_list)

    # Create a dummy draft
    assert_no_difference("Article.count") do
      assert_no_difference("ArticleContent.count") do
        assert_no_difference("RecentActivity.count") do
          assert_no_emails do
            assert !art.publish([programs(:albers)])
          end
        end
      end
    end

    assert_equal(["can't be blank"], art.article_content.errors[:title])
  end

  def test_publish
    art = articles(:economy)
    create_user(:program => programs(:no_mentor_request_program), :member => articles(:economy).author, :role_names => RoleConstants::MENTOR_NAME)

    assert_equal [programs(:albers)], art.article_content.programs

    assert_no_difference('Article.count') do
      assert_difference('Article::Publication.count') do
        art.publish([programs(:albers), programs(:nwen)])
      end
    end
    assert_equal [programs(:albers), programs(:nwen)], art.reload.article_content.programs

    assert_no_difference('Article.count') do
      assert_difference('Article::Publication.count', -1) do
        art.publish([programs(:nwen)])
      end
    end
    assert_equal [programs(:nwen)], art.reload.article_content.programs

    assert_no_difference('Article.count') do
      assert_difference('Article::Publication.count') do
        art.publish([programs(:albers), programs(:nwen)])
      end
    end
    assert_equal [programs(:albers), programs(:nwen)], art.reload.article_content.programs

    assert_no_difference('Article.count') do
      assert_no_difference('Article::Publication.count') do
        art.publish([programs(:albers), programs(:no_mentor_request_program)])
      end
    end
    assert_equal [programs(:albers), programs(:no_mentor_request_program)], art.reload.article_content.programs

    assert_difference('Article.count', -1) do
      assert_difference('Article::Publication.count', -2) do
        art.publish([])
      end
    end
  end

  def test_publish_should_destroy_comments_for_removed_programs
    art = articles(:anna_univ_1)
    create_user(:program => programs(:albers), :member => art.author, :role_names => RoleConstants::MENTOR_NAME)

    assert_equal [programs(:ceg), programs(:psg)], art.published_programs
    assert_equal 2, art.publications.first.comments.size

    assert_no_difference('Article.count') do
      assert_difference('Article::Publication.count', -1) do
        assert_difference('Comment.count', -2) do
          art.publish([programs(:psg)])
        end
      end
    end
  end

  def test_publish_should_handle_program_activities
    ac = ArticleContent.create!(:title => "What", :type => "text", :status => ArticleContent::Status::PUBLISHED)
    a = nil

    # A program activity should be created for a publication
    assert_difference 'ProgramActivity.count' do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Article::Publication.count' do
          assert_difference 'Article.count' do
            a = Article.create!({:article_content => ac, :author => members(:f_admin), :organization => programs(:org_primary), :published_programs => [programs(:albers)]})
          end
        end
      end
    end

    ra = RecentActivity.last

    assert_equal [ra], a.reload.recent_activities
    assert_equal [programs(:albers)], ra.programs

	  # A program activity should be created for a publication
    assert_difference 'ProgramActivity.count' do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Article::Publication.count' do
          assert_no_difference 'Article.count' do
            a.publish([programs(:albers), programs(:nwen)])
          end
        end
      end
    end

    ras = RecentActivity.all[-2, 2]
    assert_equal ras, a.reload.recent_activities
    assert_equal [programs(:albers)], ras[0].programs
    assert_equal [programs(:nwen)], ras[1].programs
    pa = ProgramActivity.last
    assert_equal programs(:nwen), pa.program
    assert_equal [pa], a.publications.in_program(programs(:nwen)).first.program_activities

    # A program activity should be destroyed with a publication
    assert_no_difference 'RecentActivity.count' do
      assert_difference 'ProgramActivity.count', -1 do
        assert_difference 'Article::Publication.count', -1 do
          assert_no_difference 'Article.count' do
            a.publish([programs(:albers)])
          end
        end
      end
    end
  end

  def test_publish_article_draft_success
    mt = programs(:albers).mailer_templates.where(uid: 's9kiyrsk').first
    mt.enabled = true
    mt.save!

    mt = programs(:nwen).mailer_templates.where(uid: 's9kiyrsk').first
    mt.enabled = true
    mt.save!

    art = create_article_draft(
      :organization => programs(:org_primary), :author => members(:f_mentor)
    )

    users(:f_mentor_nwen_student).add_role(RoleConstants::MENTOR_NAME)
    assert art.draft? && !art.published? && art.article_content.published_at.nil?

    assert_emails(4) do
      assert_difference("RecentActivity.count", 1) do
        assert_no_difference("ArticleContent.count") do
          assert_difference("Article::Publication.count", 2) do
            assert_no_difference("Article.count") do
              assert art.publish(
                [programs(:albers), programs(:nwen)]
              )
            end
          end
        end
      end
    end

    ac = art.reload.article_content
    assert_equal(1, ac.articles.size)
    assert ac.published?
    assert !ac.published_at.nil?

    assert_equal(ac, art.article_content)

    new_article = Article.last # Anna univ article
    assert_equal(ac, new_article.article_content)

    r = RecentActivity.last
    assert_equal(RecentActivityConstants::Type::ARTICLE_CREATION, r.action_type)
    assert ac.articles.index(r.ref_obj).present?
    assert_equal(members(:f_mentor), r.member)
    assert_equal(RecentActivityConstants::Target::ALL, r.target)

    mails = ActionMailer::Base.deliveries
    assert_equal_unordered(
      ((art.publications.collect(&:notification_list_for_creation) +
        new_article.publications.collect(&:notification_list_for_creation))
       ).flatten.collect(&:email),
      mails.collect(&:to).flatten
    )
    assert_match(/New article posted by Good unique name/, mails[0].subject)
    assert_match("has published a new article titled", get_html_part_from(mails[0]))
    assert_match "/articles/#{art.id}", get_html_part_from(mails[0])
    assert_match "Read article", get_html_part_from(mails[0])
    assert_match(/New article posted by Good unique name/, mails[1].subject)
    assert_match("has published a new article titled", get_html_part_from(mails[1]))
    assert_match(/New article posted by Good unique name/, mails[2].subject)
    assert_match("has published a new article titled", get_html_part_from(mails[2]))
    assert_match(/New article posted by Good unique name/, mails[3].subject)
    assert_match("has published a new article titled", get_html_part_from(mails[3]))
  end

  def test_publish_article_draft_failure
    art = create_article_draft(
      :organization => programs(:org_primary), :author => members(:f_mentor)
    )

    assert art.draft? && !art.published? && art.article_content.published_at.nil?

    # f_mentor cannot write articles in nwen since he is a student there.
    assert_no_difference "Article::Publication.count" do
      assert_no_difference "Article.count" do
        assert_no_difference "ArticleContent.count" do
          assert_raise ActiveRecord::RecordInvalid do
            assert art.publish(
              [programs(:ceg), programs(:albers), programs(:nwen)]
            )
          end
        end
      end
    end
  end

  def test_article_search_should_not_search_for_html_tags
    assert(Article.get_es_articles("span").empty?)
  end

  def test_article_search_should_not_return_draft_articles
    assert(Article.get_es_articles("draft").empty?)
  end

  def test_real_status
    a = articles(:draft_article)
    assert_equal(ArticleContent::Status::DRAFT, a.status)
    assert_equal(ArticleContent::Status::DRAFT, a.real_status)

    a.article_content.status = ArticleContent::Status::PUBLISHED
    assert_equal(ArticleContent::Status::PUBLISHED, a.status)
    assert_equal(ArticleContent::Status::DRAFT, a.real_status)

    assert_equal(ArticleContent::Status::DRAFT, Article.new.real_status)

    b = articles(:kangaroo)
    assert_equal(ArticleContent::Status::PUBLISHED, b.status)
    b.article_content.status = ArticleContent::Status::DRAFT
    assert_equal(ArticleContent::Status::DRAFT, b.status)
    assert_equal(ArticleContent::Status::PUBLISHED, b.real_status)
  end

  def test_create_with_attachment
    ArticleContent.create!(
      :title => 'test',
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt'),'application/pdf')
    )

    ac = ArticleContent.last
    assert ac.attachment?
    assert_equal 'some_file.txt', ac.attachment_file_name
  end

  def test_in_organization_scope
    assert_equal(
      [articles(:anna_univ_1), articles(:anna_univ_psg_1)],
       Article.in_organization([programs(:org_anna_univ)])
    )

    assert_equal(
      [articles(:economy), articles(:india), articles(:kangaroo),
       articles(:delhi), articles(:draft_article),
       articles(:anna_univ_1), articles(:anna_univ_psg_1)],
       Article.in_organization([programs(:org_primary), programs(:org_anna_univ)])
    )
  end

  def test_get_publication
    assert_nil articles(:economy).get_publication(programs(:nwen))
    assert_nil articles(:economy).get_publication(programs(:moderated_program))

    publication_1 = create_article_publication(articles(:economy), programs(:nwen))
    publication_2 = create_article_publication(articles(:economy), programs(:moderated_program))

    assert_equal publication_1, articles(:economy).get_publication(programs(:nwen))
    assert_equal publication_2, articles(:economy).get_publication(programs(:moderated_program))
  end

  def test_published_in_scope
    assert_equal(
      [articles(:economy),
       articles(:india),
       articles(:kangaroo),
       articles(:delhi),
       articles(:draft_article)
      ],
      Article.published_in(programs(:albers))
    )

    assert_equal(
      [articles(:anna_univ_1),
       articles(:anna_univ_psg_1)
      ],
      Article.published_in(programs(:psg))
    )
  end

  #Admin, receives an email notification, if he has chosen the digest mail setting
  def test_pending_notifications_should_dependent_destroy_on_article_deletion
    users(:f_admin).update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    assert_difference('Article.count',1) do
      assert_difference('PendingNotification.count',1) do
        @article = create_article
      end
    end
    assert_difference('PendingNotification.count', -1) do
      assert_difference('Article.count',-1) do
        @article.destroy
      end
    end
  end

  def test_published_labels
    article_contents(:draft_article).update_attributes(label_list: "New Draft Label")
    article_contents(:economy).update_attributes(label_list: "New Published Label")

    label_list = Article.published_labels(programs(:org_primary).program_ids).collect(&:name)
    assert label_list.include? "New Published Label"
    assert_false label_list.include? "New Draft Label"
  end

  def test_get_article_ids_published_in_program
    assert_equal [1, 2, 3, 4], Article.get_article_ids_published_in_program([programs(:albers).id])
  end

  def test_created_in_date_range_scope
    article = articles(:economy)
    article_created_at = article.created_at

    date_range = (article_created_at - 20.seconds)..(article_created_at - 10.seconds)
    assert_false Article.created_in_date_range(date_range).pluck(:id).include?(article.id)

    date_range = (article_created_at + 10.seconds)..(article_created_at + 20.seconds)
    assert_false Article.created_in_date_range(date_range).pluck(:id).include?(article.id)

    date_range = (article_created_at - 10.seconds)..(article_created_at + 10.seconds)
    assert Article.created_in_date_range(date_range).pluck(:id).include?(article.id)
  end
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