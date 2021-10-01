require_relative './../test_helper.rb'

class FlagTest < ActiveSupport::TestCase

  def test_validate
    content = articles(:economy)
    program = programs(:albers)
    user = users(:f_mentor)
    reason = 'offensive'
    flag = Flag.new({content: content, program: program, user: user})
    assert_false flag.valid?
    flag = Flag.new({reason: reason, content: content, user: user})
    assert_false flag.valid?
    flag = Flag.new({reason: reason, content: content, program: program})
    assert_false flag.valid?
    flag = Flag.new({reason: reason, content: content, program: program, user: user, status: Flag::Status::UNRESOLVED})
    assert flag.valid?
    flag = Flag.new({reason: reason, program: program, user: user, status: Flag::Status::UNRESOLVED})
    assert flag.valid? # Content deleted state
  end

  def test_unresolved_scope_and_resolved_scope
    flag = create_flag(content: articles(:economy))
    program = flag.program
    unresolved_flags = Flag.unresolved.to_a
    resolved_flags = Flag.resolved.to_a
    flag.update_attribute(:status, Flag::Status::ALLOWED)
    assert_equal_unordered unresolved_flags - [flag], Flag.unresolved
    assert_equal_unordered unresolved_flags - [flag], Flag.get_flags(program, {filter: {unresolved: true}})
    assert_equal_unordered resolved_flags + [flag], Flag.resolved
    assert_equal_unordered resolved_flags + [flag], Flag.get_flags(program, {filter: {resolved: true}})
    flag.update_attribute(:status, Flag::Status::EDITED)
    assert_equal_unordered unresolved_flags - [flag], Flag.unresolved
    assert_equal_unordered unresolved_flags - [flag], Flag.get_flags(program, {filter: {unresolved: true}})
    assert_equal_unordered resolved_flags + [flag], Flag.resolved
    assert_equal_unordered resolved_flags + [flag], Flag.get_flags(program, {filter: {resolved: true}})
    flag.update_attribute(:status, Flag::Status::DELETED)
    assert_equal_unordered unresolved_flags - [flag], Flag.unresolved
    assert_equal_unordered unresolved_flags - [flag], Flag.get_flags(program, {filter: {unresolved: true}})
    assert_equal_unordered resolved_flags + [flag], Flag.resolved
    assert_equal_unordered resolved_flags + [flag], Flag.get_flags(program, {filter: {resolved: true}})
    flag.update_attribute(:status, Flag::Status::UNRESOLVED)
    assert_equal_unordered unresolved_flags, Flag.unresolved
    assert_equal_unordered unresolved_flags, Flag.get_flags(program, {filter: {unresolved: true}})
    assert_equal_unordered resolved_flags, Flag.resolved
    assert_equal_unordered resolved_flags, Flag.get_flags(program, {filter: {resolved: true}})
  end

  def test_flagged_and_unresolved_by_user
    nonflagging_user = users(:f_mentor)
    flagging_user = users(:f_student)
    article = articles(:economy)
    flag = create_flag(content: article, user: flagging_user)
    assert_false Flag.flagged_and_unresolved_by_user?(article, nonflagging_user)
    assert Flag.flagged_and_unresolved_by_user?(article, flagging_user)
  end

  def test_flagged_and_unresolved
    content = articles(:economy)
    flag = create_flag(content: content)
    assert Flag.flagged_and_unresolved?(content, programs(:albers))
    flag.destroy
    assert_false Flag.flagged_and_unresolved?(content, programs(:albers))
  end

  def test_set_status_as_deleted
    article = articles(:economy)
    flag = create_flag(content: article)
    admin = users(:f_admin)
    Flag.set_status_as_deleted(article, admin, Time.now)
    article.flags.each do |flag|
      assert_equal Flag::Status::DELETED, flag.status
    end
  end

  def test_set_flags_status_as_edited
    article = articles(:economy)
    flag = create_flag(content: article)
    admin = users(:f_admin)
    Flag.set_flags_status_as_edited(article,  admin, Time.now)
    article.flags.each do |flag|
      assert_equal Flag::Status::EDITED, flag.status if flag.unresolved?
    end
  end

  def test_ignore_all_flags
    article = articles(:economy)
    flag = create_flag(content: article)
    admin = users(:f_admin)
    Flag.ignore_all_flags(article, admin, Time.now)
    article.flags.each do |flag|
      assert_equal Flag::Status::ALLOWED, flag.status if flag.unresolved?
    end
  end

  def test_unresolved
    article = articles(:economy)
    flag = create_flag(content: article)
    assert flag.unresolved?
    assert_equal Flag::Status::UNRESOLVED, flag.status
    [Flag::Status::DELETED, Flag::Status::EDITED, Flag::Status::ALLOWED].each do |status|
      flag.update_attribute(:status, status)
      assert_equal status, flag.status
      assert_false flag.unresolved?
    end
  end

  def test_content_type_name
    obj_class_ary = [Post, Comment, QaQuestion, QaAnswer, Article]
    name_ary = ['Forum Post', 'Comment', 'Question', 'Answer', 'Article']
    flag = create_flag
    obj_class_ary.each do |klass|
      flag.update_attribute(:content_type, klass.to_s)
      flag.reload
      assert_equal name_ary[obj_class_ary.index(klass)], flag.content_type_name
    end
  end

  def test_count_for_content
    article = articles(:economy)
    flag = create_flag(content: article)
    nonflagging_user = users(:f_mentor)
    count = article.flags.size
    assert_equal count, Flag.count_for_content(article, programs(:albers))
    create_flag(content: article, user: nonflagging_user)
    assert_equal count+1, Flag.count_for_content(article, programs(:albers))
  end

  def test_content_owner_and_check
    article = articles(:economy)
    program = programs(:albers)
    article_owner = article.author.user_in_program(program)
    user = users(:f_mentor)
    assert_equal article_owner, Flag.content_owner(article, program)
    assert Flag.content_owner_is_user?(article, article_owner)
    assert_false Flag.content_owner_is_user?(article, user)
  end

  def test_get_flags_when_feature_enabled_or_disabled
    article = articles(:economy)
    program = article.organization.programs.first
    flag = create_flag(content: article)
    assert program.articles_enabled?
    assert_equal [flag], Flag.get_flags(program, {filter: {unresolved: true}})
    program.enable_feature(FeatureName::ARTICLES, false)
    assert_false program.articles_enabled?
    assert_equal [], Flag.get_flags(program.reload, {filter: {unresolved: true}})
  end

  def test_send_content_flagged_admin_notification
    flag = create_flag
    program = flag.program
    admin_user_emails = program.admin_users.collect(&:email)

    assert_equal 2, program.admin_users.count

    assert_difference "JobLog.count", 2 do
      assert_emails 2 do
        Flag.send_content_flagged_admin_notification(flag.id, "some_uuid")
      end
    end

    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered admin_user_emails, emails.collect(&:to).flatten
    assert_equal ["#{users(:f_student).name} has flagged content as inappropriate"], emails.collect(&:subject).uniq

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Flag.send_content_flagged_admin_notification(flag.id, "some_uuid")
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Flag.send_content_flagged_admin_notification(0, "some_other_uuid")
      end
    end
  end

  def test_flaggable_klasses
    assert_equal [Article, QaQuestion, QaAnswer, Post, Comment], Flag.flaggable_klasses
  end

  def test_flaggable_content_types
    assert_equal [Article.name, QaQuestion.name, QaAnswer.name, Post.name, Comment.name], Flag.flaggable_content_types
  end
end