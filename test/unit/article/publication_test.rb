require_relative './../../test_helper.rb'

class Article::PublicationTest < ActiveSupport::TestCase
  def test_create_success
    assert_difference "Article::Publication.count" do
      @article_publication = Article::Publication.create!(
        :article => articles(:economy),
        :program => programs(:nwen)
      )
    end

    assert_equal articles(:economy), @article_publication.article
    assert_equal programs(:nwen), @article_publication.program
  end

  def test_article_and_program_are_required
    publication = Article::Publication.new
    assert_false publication.valid?

    assert publication.errors[:article]
    assert publication.errors[:program]
  end

  def test_article_and_program_tuple_is_uniq
    assert_difference "Article::Publication.count" do
      @article_publication = Article::Publication.create!(
        :article => articles(:economy),
        :program => programs(:nwen)
      )
    end

    publication_1 = Article::Publication.new(
      :article => articles(:economy),
      :program => programs(:nwen)
    )

    assert_false publication_1.valid?
    assert publication_1.errors[:article_id]

    # Creating with another program should work.
    publication_2 = Article::Publication.new(
      :article => articles(:economy),
      :program => programs(:moderated_program)
    )

    assert publication_2.valid?
  end

  def test_has_many_comments
    publication = create_article_publication(articles(:economy), programs(:nwen))
    assert publication.comments.empty?

    comment = Comment.create!(
      :publication => publication, :user => users(:f_student_nwen_mentor), :body => "Abc"
    )

    assert_equal [comment], publication.reload.comments

    comment_1 = Comment.create!(
      :publication => publication, :user => users(:f_mentor_nwen_student), :body => "Def"
    )

    assert_equal [comment, comment_1], publication.reload.comments

    assert_difference 'Comment.count', -2 do
      assert_difference 'Article::Publication.count', -1 do
        publication.destroy
      end
    end
  end

  def test_has_many_program_activities
    users(:f_mentor_nwen_student).add_role(RoleConstants::MENTOR_NAME)

    assert_difference 'RecentActivity.count' do
      assert_difference 'ProgramActivity.count' do
        assert_difference 'Article::Publication.count' do
          articles(:kangaroo).publish([programs(:albers), programs(:nwen)])
        end
      end
    end

    publication = articles(:kangaroo).publications.in_program(programs(:nwen)).first
    assert_equal [ProgramActivity.last], publication.program_activities

    # ProgramActivity should be dependent destroyed
    assert_difference 'Article::Publication.count', -1 do
      assert_difference 'ProgramActivity.count', -1 do
        publication.destroy
      end
    end
  end

  def test_watchers
    users(:f_mentor_nwen_student).add_role(RoleConstants::MENTOR_NAME)
    publication = create_article_publication(articles(:kangaroo), programs(:nwen))
    author_user = publication.article.author.user_in_program(programs(:nwen))

    admins = publication.program.admin_users

    assert_equal_unordered([author_user] + admins, publication.watchers)

    publication.comments.create!(:user => users(:f_student_nwen_mentor), :body => "Abc")
    assert_equal_unordered([author_user, users(:f_student_nwen_mentor)] + admins, publication.watchers)

    publication.comments.create!(:user => users(:f_student_nwen_mentor), :body => "Abc1")
    assert_equal_unordered([author_user, users(:f_student_nwen_mentor)] + admins, publication.watchers)

    publication.comments.create!(:user => users(:f_admin_nwen), :body => "Abc1")

    # Admin is among commenters. So, ensure he is not repeated.
    assert_equal_unordered([author_user, users(:f_student_nwen_mentor)] + admins, publication.watchers)
  end

  def test_author
    publication = create_article_publication(articles(:economy), programs(:nwen))
    assert_equal users(:f_admin_nwen), publication.author

    publication_1 = Article::Publication.new
    assert_nil publication_1.author
  end

  def test_author_should_be_present_and_have_write_privileges
    publication = Article::Publication.new(
      :article => articles(:kangaroo),
      :program => programs(:cit)
    )

    assert_false publication.valid?
    assert publication.errors[:author]

    publication = Article::Publication.new(
      :article => articles(:kangaroo),
      :program => programs(:psg)
    )

    assert_false publication.valid?
    assert publication.errors[:author]
  end

  def test_in_program_scope
    assert_equal_unordered [], Article::Publication.in_program(programs(:nwen))

    assert_equal_unordered(
      [
        articles(:anna_univ_1).get_publication(programs(:psg)),
        articles(:anna_univ_psg_1).get_publication(programs(:psg))
      ],
      Article::Publication.in_program([programs(:psg), programs(:nwen)])
    )

    publication = create_article_publication(articles(:economy), programs(:nwen))

    assert_equal_unordered(
      [
        articles(:anna_univ_1).get_publication(programs(:psg)),
        articles(:anna_univ_psg_1).get_publication(programs(:psg)),
        publication
      ],
      Article::Publication.in_program([programs(:psg), programs(:nwen)])
    )
  end

  def test_notification_list_for_creation
    assert_equal_unordered(
      [users(:psg_only_admin), users(:psg_admin)],
      articles(:anna_univ_1).get_publication(programs(:psg)).notification_list_for_creation
    )

    # For CEG publication.
    assert_equal_unordered(
      [users(:ceg_admin)],
      articles(:anna_univ_1).get_publication(programs(:ceg)).notification_list_for_creation
    )

    # The author :psg_admin should not be in the list.
    assert_equal_unordered(
      [users(:psg_only_admin)],
      articles(:anna_univ_psg_1).get_publication(programs(:psg)).notification_list_for_creation
    )

    assert_equal_unordered(
      [users(:ram)],
      articles(:economy).get_publication(programs(:albers)).notification_list_for_creation
    )

    assert_equal_unordered(
      [users(:f_admin), users(:ram)],
      articles(:kangaroo).get_publication(programs(:albers)).notification_list_for_creation
    )
  end

  def test_notify_users
    ## New article notification is disabled by default.
    mt = programs(:nwen).mailer_templates.where(uid: 's9kiyrsk').first
    mt.enabled = true
    mt.save!

    assert_difference "JobLog.count" do
      assert_emails 1 do
        @article_publication = Article::Publication.create!(
          :article => articles(:economy),
          :program => programs(:nwen)
        )
      end
    end
    joblog = JobLog.last
    assert_equal "Article::Publication", joblog.loggable_object_type
    assert_equal @article_publication.id, joblog.loggable_object_id

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Article::Publication.notify_users(@article_publication.id, RecentActivityConstants::Type::ARTICLE_CREATION)
      end
    end
  end
end