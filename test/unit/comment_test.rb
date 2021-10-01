require_relative './../test_helper.rb'

class CommentTest < ActiveSupport::TestCase
  def test_should_require_article_user_and_body
    c = Comment.new
    assert_false c.valid?

    assert_equal(["can't be blank"], c.errors[:publication])
    assert_equal(["can't be blank"], c.errors[:body])
    assert_equal(["can't be blank"], c.errors[:user])
  end

  def test_should_not_create_program_when_user_and_publication_belong_to_different_programs
    publication = create_article_publication(articles(:economy), programs(:nwen))
    commenter = users(:mentor_3)

    assert_not_equal publication.program, commenter.program

    comment = Comment.new(
      :publication => publication, :user => commenter, :body => "ANC"
    )

    assert_false comment.valid?
    assert_equal ["You can comment only on articles in your program"], comment.errors[:base]
  end

  def test_should_create_comment
    publication = create_article_publication(articles(:economy), programs(:nwen))

    assert_difference "RecentActivity.count" do
      assert_difference "Comment.count" do
        @comment = Comment.create!(
          :publication => publication, :user => users(:f_student_nwen_mentor), :body => "Abc")
      end
    end

    @comment = Comment.last

    assert_equal("Abc", @comment.body)
    assert_equal(users(:f_student_nwen_mentor), @comment.user)

    assert_equal(1, publication.reload.comments.size)

    activity = RecentActivity.last

    assert_equal(@comment, activity.ref_obj)
    assert_equal(RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION, activity.action_type)
    assert_equal(users(:f_student_nwen_mentor), activity.get_user(publication.program))
    assert_equal(RecentActivityConstants::Target::ALL, activity.target)

    assert_difference("RecentActivity.count", -1) do
      assert_difference("Comment.count", -1) do
        @comment.destroy
      end
    end
  end

  def test_should_notify_watchers_on_comment
    article_publication = articles(:kangaroo).publications.first
    admins = article_publication.program.admin_users
    article_publication.comments.create!(:user => users(:f_student), :body => "Abc")
    article_publication.comments.create!(:user => users(:student_1), :body => "Abc1")
    article_publication.comments.create!(:user => users(:mentor_1), :body => "Abc1")
    article_publication.comments.create!(:user => users(:f_admin), :body => "Abc1")

    assert_equal_unordered([
        users(:f_mentor), users(:f_student), users(:student_1), users(:mentor_1),
        users(:f_admin)] + admins,
      article_publication.watchers)

    article_publication.watchers.each do |user|
      user.update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    end

    Push::Base.expects(:queued_notify).times(article_publication.watchers.size)
    assert_emails article_publication.watchers.size do
      article_publication.comments.create!(:user => users(:mentor_2), :body => "Abc1")
    end

    article_publication.watchers.each do |user|
      user.update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    end

    fetch_role(:albers, :mentor).remove_permission('view_mentors')

    # Reload to fetch new permissions.
    article_publication.watchers.collect(&:reload)

    expected_count = (article_publication.watchers - [users(:f_mentor), users(:mentor_1), users(:mentor_2), users(:mentor_3)]).size
    Push::Base.expects(:queued_notify).times(expected_count)
    # The mentors should not get the email.
    assert_emails(expected_count) do
      article_publication.comments.create!(:user => users(:mentor_3), :body => "Abc1")
    end

    article_publication.watchers.each do |user|
      user.update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    end

    fetch_role(:albers, :student).remove_permission('view_students')

    # Reload to fetch new permissions.
    article_publication.watchers.collect(&:reload)
    
    Comment.expects(:delay).returns(Comment).once 

    expected_count = (article_publication.watchers - [users(:f_student), users(:student_1), users(:student_2)]).size
    Push::Base.expects(:queued_notify).times(expected_count)
    # The students should not get the email.
    assert_emails(expected_count) do
      article_publication.comments.create!(:user => users(:student_2), :body => "Abc1")
    end
  end

  def test_created_in_date_range_scope
    publication = create_article_publication(articles(:economy), programs(:nwen))
    t = Time.now
    comment = Comment.create!(
          :publication => publication, :user => users(:f_student_nwen_mentor), :body => "Abc")
    date_range = t..Time.now
    assert Comment.created_in_date_range(date_range).pluck(:id).include?(comment.id)

    end_date = Time.now-1.day
    date_range = t..end_date
    assert_false Comment.created_in_date_range(date_range).pluck(:id).include?(comment.id)
  end

def test_pending_notifications_should_dependent_destroy_on_comment_deletion
    program = programs(:nwen)
    user = users(:f_mentor)
    comment = comments(:anna_univ_ceg_1_c1)
    #Testing has_many association
    action_types =  [RecentActivityConstants::Type::TOPIC_CREATION, RecentActivityConstants::Type::POST_CREATION]
    pending_notifications = []
    assert_difference "PendingNotification.count", 2 do
      action_types.each do |action_type|
        pending_notifications << comment.pending_notifications.create!(
                  ref_obj_creator: user,
                  ref_obj: comment,
                  program: program,
                  action_type:  action_type)
      end
    end
    assert_equal pending_notifications, comment.pending_notifications
    assert_difference 'Comment.count', -1 do
      assert_difference 'PendingNotification.count', -2 do
        comment.destroy
      end
    end
  end
end