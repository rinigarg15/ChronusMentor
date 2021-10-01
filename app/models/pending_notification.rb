# == Schema Information
#
# Table name: pending_notifications
#
#  id                   :integer          not null, primary key
#  ref_obj_creator_id   :integer
#  program_id           :integer
#  ref_obj_id           :integer
#  ref_obj_type         :string(255)
#  action_type          :integer
#  created_at           :datetime
#  updated_at           :datetime
#  initiator_id         :integer
#  ref_obj_creator_type :string(255)
#  message              :text(65535)
#

class PendingNotification < ActiveRecord::Base
  belongs_to_program
  belongs_to :ref_obj_creator, :polymorphic => true
  belongs_to :initiator, :class_name => 'User'
  belongs_to :ref_obj, :polymorphic => true

  validates_presence_of :program, :ref_obj_creator, :ref_obj, :action_type
  validates_inclusion_of :action_type, :in => PendingNotificationConstants::ALLOWED_ACTION_TYPES

  def digest_v2_card_base_details
    base_obj = case action_type
    when RecentActivityConstants::Type::POST_CREATION
      ref_obj.topic
    when RecentActivityConstants::Type::QA_ANSWER_CREATION
      ref_obj.qa_question
    when RecentActivityConstants::Type::ARTICLE_CREATION, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, RecentActivityConstants::Type::TOPIC_CREATION
      ref_obj
    when RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
      ref_obj.article
    end
    content, target_url_objs = case action_type
    when RecentActivityConstants::Type::POST_CREATION, RecentActivityConstants::Type::TOPIC_CREATION
      [base_obj.title, [:forum_topic_url, base_obj.forum, base_obj]]
    when RecentActivityConstants::Type::QA_ANSWER_CREATION
      [base_obj.summary, [:qa_question_url, base_obj]]
    when RecentActivityConstants::Type::ARTICLE_CREATION, RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
      [base_obj.title, [:article_url, base_obj]]
    when RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE
      [base_obj.title, [:announcement_url, base_obj]]
    end
    {content_id: class_name_with_id(base_obj), content: content, call_to_action_url: target_url_objs}
  end

  def digest_v2_card_author_name
    case action_type
    when RecentActivityConstants::Type::POST_CREATION, RecentActivityConstants::Type::QA_ANSWER_CREATION, 
      RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
      ref_obj.user
    when RecentActivityConstants::Type::ARTICLE_CREATION
      ref_obj.author
    when RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE
      ref_obj.admin
    end.name(name_only: true)
  end

  def digest_v2_card_type
    case action_type
    when RecentActivityConstants::Type::POST_CREATION
      ref_obj.parent.present? ? DigestV2::CardType::COMMENT : DigestV2::CardType::POST
    when RecentActivityConstants::Type::QA_ANSWER_CREATION
      DigestV2::CardType::QA_ANSWER
    when RecentActivityConstants::Type::ARTICLE_CREATION
      DigestV2::CardType::ARTICLE_CREATION
    when RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
      DigestV2::CardType::ARTICLE_COMMENT_CREATION
    when RecentActivityConstants::Type::ANNOUNCEMENT_CREATION
      DigestV2::CardType::ANNOUNCEMENT_CREATION
    when RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE
      DigestV2::CardType::ANNOUNCEMENT_UPDATE
    end
  end

  private

  def class_name_with_id(obj)
    "#{obj.class.name}_#{obj.id}"
  end

end
