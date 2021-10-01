# == Schema Information
#
# Table name: qa_answers
#
#  id             :integer          not null, primary key
#  qa_question_id :integer
#  user_id        :integer
#  content        :text(65535)
#  score          :integer          default(0)
#  created_at     :datetime
#  updated_at     :datetime
#

class QaAnswer < ActiveRecord::Base
  acts_as_rateable

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:content]
  }

  validates_presence_of :content, :user, :qa_question
  validate :check_user_belongs_to_program

  belongs_to :qa_question
  counter_culture :qa_question
  belongs_to :user
  counter_culture :user

  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :flags, as: :content, dependent: :nullify
  has_many :push_notifications, :as => :ref_obj
  has_many :pending_notifications, as: :ref_obj, dependent: :destroy

  scope :by_user, ->(user_ids) {
    where({ :user_id => user_ids })
  }

  scope :latest_first, -> { order("id DESC")}

  def toggle_helpful!(user)
    return unless authorized?(user)
    if helpful?(user)
      mark_not_helpful!(user)
    else
      mark_helpful!(user)
    end
  end

  def helpful?(user)
    rated_by_user?(user)
  end

  def self.es_reindex(qa_answer)
    DelayedEsDocument.do_delta_indexing(QaQuestion, Array(qa_answer), :qa_question_id)
  end

  protected

  def mark_not_helpful!(user)
    if helpful?(user)
      self.find_user_rating(user).destroy
      new_score = self.score - 1
      self.update_attribute(:score, new_score)
    end
  end

  def mark_helpful!(user)
    unless helpful?(user)
      self.ratings << Rating.new(:rating => 1, :user => user)
      new_score = self.score + 1
      self.update_attribute(:score, new_score)
    end
  end

  def check_user_belongs_to_program
    errors.add(:user, "feature.question_answers.content.user_belongs_to_program_error".translate) if self.user and (self.user.program != self.qa_question.program)
  end

  def authorized?(user)
    user.program != self.qa_question.program ? false : true
  end
end
