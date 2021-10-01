require_relative './../test_helper.rb'

class PendingNotificationTest < ActiveSupport::TestCase
  def test_digest_v2_card_type
    pending_notification = PendingNotification.new
    pending_notification.action_type = RecentActivityConstants::Type::QA_ANSWER_CREATION
    assert_equal DigestV2::CardType::QA_ANSWER, pending_notification.digest_v2_card_type
    pending_notification.action_type = RecentActivityConstants::Type::ARTICLE_CREATION
    assert_equal DigestV2::CardType::ARTICLE_CREATION, pending_notification.digest_v2_card_type
    pending_notification.action_type = RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
    assert_equal DigestV2::CardType::ARTICLE_COMMENT_CREATION, pending_notification.digest_v2_card_type
    pending_notification.action_type = RecentActivityConstants::Type::ANNOUNCEMENT_CREATION
    assert_equal DigestV2::CardType::ANNOUNCEMENT_CREATION, pending_notification.digest_v2_card_type
    pending_notification.action_type = RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE
    assert_equal DigestV2::CardType::ANNOUNCEMENT_UPDATE, pending_notification.digest_v2_card_type
    topic = create_topic(title: "Topic 1")
    post_1 = create_post(topic: topic, body: "Post 1")
    post_2 = create_post(topic: topic, body: "Post 2", ancestry: post_1.id)
    pending_notification.action_type = RecentActivityConstants::Type::POST_CREATION
    pending_notification.ref_obj = post_2
    assert_equal DigestV2::CardType::COMMENT, pending_notification.digest_v2_card_type
    pending_notification.ref_obj = post_1
    assert_equal DigestV2::CardType::POST, pending_notification.digest_v2_card_type
  end

  def test_digest_v2_card_author_name
    pending_notification = PendingNotification.new
    
    post = create_post(topic: create_topic)
    pending_notification.ref_obj = post
    pending_notification.action_type = RecentActivityConstants::Type::POST_CREATION
    assert_equal post.user.name(name_only: true), pending_notification.digest_v2_card_author_name

    answer = create_qa_answer
    pending_notification.ref_obj = answer
    pending_notification.action_type = RecentActivityConstants::Type::QA_ANSWER_CREATION
    assert_equal answer.user.name(name_only: true), pending_notification.digest_v2_card_author_name

    article_comment = articles(:anna_univ_1).publications.first.comments.first
    pending_notification.ref_obj = article_comment
    pending_notification.action_type = RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
    assert_equal article_comment.user.name(name_only: true), pending_notification.digest_v2_card_author_name

    article = articles(:anna_univ_1)
    pending_notification.ref_obj = article
    pending_notification.action_type = RecentActivityConstants::Type::ARTICLE_CREATION
    assert_equal article.author.name(name_only: true), pending_notification.digest_v2_card_author_name

    announcement = create_announcement
    pending_notification.ref_obj = announcement
    pending_notification.action_type = RecentActivityConstants::Type::ANNOUNCEMENT_CREATION
    assert_equal announcement.admin.name(name_only: true), pending_notification.digest_v2_card_author_name

    pending_notification.ref_obj = announcement
    pending_notification.action_type = RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE
    assert_equal announcement.admin.name(name_only: true), pending_notification.digest_v2_card_author_name
  end

  def test_digest_v2_card_base_details
    pending_notification = PendingNotification.new
    
    topic = create_topic
    post = create_post(topic: topic)
    pending_notification.ref_obj = post
    pending_notification.action_type = RecentActivityConstants::Type::POST_CREATION
    assert_equal_hash({:content_id=>PendingNotification.new.send(:class_name_with_id, topic), :content=>"Title", :call_to_action_url=>[:forum_topic_url, topic.forum, topic]}, pending_notification.digest_v2_card_base_details)

    pending_notification.ref_obj = topic
    pending_notification.action_type = RecentActivityConstants::Type::TOPIC_CREATION
    assert_equal_hash({:content_id=>PendingNotification.new.send(:class_name_with_id, topic), :content=>"Title", :call_to_action_url=>[:forum_topic_url, topic.forum, topic]}, pending_notification.digest_v2_card_base_details)

    answer = create_qa_answer
    pending_notification.ref_obj = answer
    pending_notification.action_type = RecentActivityConstants::Type::QA_ANSWER_CREATION
    assert_equal({:content_id=>PendingNotification.new.send(:class_name_with_id, answer.qa_question), :content=>"Hello", :call_to_action_url=>[:qa_question_url, answer.qa_question]}, pending_notification.digest_v2_card_base_details)

    article = articles(:anna_univ_1)
    pending_notification.ref_obj = article
    pending_notification.action_type = RecentActivityConstants::Type::ARTICLE_CREATION
    assert_equal({:content_id=>PendingNotification.new.send(:class_name_with_id, article), :content=>"About Anna University", :call_to_action_url=>[:article_url, article]}, pending_notification.digest_v2_card_base_details)

    announcement = create_announcement
    pending_notification.ref_obj = announcement
    pending_notification.action_type = RecentActivityConstants::Type::ANNOUNCEMENT_CREATION
    assert_equal({:content_id=>PendingNotification.new.send(:class_name_with_id, announcement), :content=>"Hello", :call_to_action_url=>[:announcement_url, announcement]}, pending_notification.digest_v2_card_base_details)

    announcement = create_announcement
    pending_notification.ref_obj = announcement
    pending_notification.action_type = RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE
    assert_equal({:content_id=>PendingNotification.new.send(:class_name_with_id, announcement), :content=>"Hello", :call_to_action_url=>[:announcement_url, announcement]}, pending_notification.digest_v2_card_base_details)

    article_comment = article.publications.first.comments.first
    pending_notification.ref_obj = article_comment
    pending_notification.action_type = RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
    assert_equal({:content_id=>PendingNotification.new.send(:class_name_with_id, article), :content=>"About Anna University", :call_to_action_url=>[:article_url, article]}, pending_notification.digest_v2_card_base_details)
  end

  def test_class_name_with_id
    article = articles(:anna_univ_1)
    assert_equal "#{article.class.name}_#{article.id}", PendingNotification.new.send(:class_name_with_id, article)
  end

  def test_should_not_create_a_pending_notification_without_program__user__ref_obj_and_action_type
    e = assert_raise(ActiveRecord::RecordInvalid) do
      PendingNotification.create!
    end

    assert_match(/Program can't be blank/, e.message)
    assert_match(/Ref obj creator can't be blank/, e.message)
    assert_match(/Ref obj can't be blank/, e.message)
    assert_match(/Action type can't be blank/, e.message)
  end

  # The allowed action types are in PendingNotificationConstants::ALLOWED_ACTION_TYPES
  def test_action_type_should_be_one_of_allowed_types
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :action_type, "is not included in the list") do
      c1 = PendingNotification.create!(:ref_obj => create_user, :program => programs(:albers), :ref_obj_creator => users(:f_admin), :action_type => RecentActivityConstants::Type::MENTOR_JOIN_PROGRAM)
    end

    assert_nothing_raised do
      c1 = PendingNotification.create!(:ref_obj => create_announcement, :program => programs(:albers), :ref_obj_creator => users(:f_mentor), :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION)
    end
  end
end