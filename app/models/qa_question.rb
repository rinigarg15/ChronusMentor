# == Schema Information
#
# Table name: qa_questions
#
#  id               :integer          not null, primary key
#  program_id       :integer
#  user_id          :integer
#  summary          :text(65535)
#  description      :text(65535)
#  qa_answers_count :integer          default(0)
#  views            :integer          default(0)
#  delta            :boolean          default(FALSE)
#  created_at       :datetime
#  updated_at       :datetime
#

class QaQuestion < ActiveRecord::Base
  include QaQuestionElasticsearchSettings
  include QaQuestionElasticsearchQueries

  acts_as_rateable

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:summary, :description],
    :new => [:summary, :description]
  }

  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :qa_answers, :dependent => :destroy
  has_many :flags, as: :content, dependent: :nullify

  belongs_to :user, -> { includes([:member, :roles])}
  belongs_to_program

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates_presence_of :summary, :user, :program
  validate :check_user_belongs_to_program

  #-----------------------------------------------------------------------------
  # CALLBACKS
  #-----------------------------------------------------------------------------
  
  after_create :mark_creater_follows_question

  def followers
    User.where(id: ratings.pluck(:user_id)).to_a
  end

  def self.human_name
    'feature.question_answers.content.answer'.translate
  end

  # Returns questions similar to self by searching its peers for self.summary
  # FIXME: Search should ignore stop words
  # :count option (defaults to 10), gets the size of the array
  #  Also note that similarity is not symmetric here
  def similar_qa_questions(options = {})
    count = options[:count] || PER_PAGE
    QaQuestion.get_qa_questions_matching_query(QueryHelper::EsUtils.sanitize_es_query(self.summary), page: 1, per_page: count, with: {program_id: self.program_id}, without: {id: self.id}, includes_list: [:program])
  end

  # User can either follow or not follow a question.
  # This function toggles between the two options
  def toggle_follow!(user)
    return unless authorized?(user)
    if follow?(user)
      mark_not_follow!(user)
    else
      mark_follow!(user)
    end
  end

  def total_likes
    self.qa_answers.sum(:score)
  end

  def latest_qa_answer_by(user)
    qa_answers.where(user_id: user).order("id DESC").first
  end

  # Checks whether a user follows a question
  def follow?(user)
    rated_by_user?(user)
  end

  protected
  
  def mark_not_follow!(user)
    self.find_user_rating(user).destroy if follow?(user)
  end

  def mark_follow!(user)
    self.ratings << Rating.new(:rating => 1, :user => user) unless follow?(user)
  end

  def check_user_belongs_to_program
    errors.add(:user, "feature.question_answers.content.user_belongs_to_program_error".translate) if self.user and (self.user.program != self.program)
  end

  def authorized?(user)
    user.program == self.program
  end

  def mark_creater_follows_question
    mark_follow!(user)
  end
end
