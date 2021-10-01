# == Schema Information
#
# Table name: mentor_recommendations
#
#  id          :integer          not null, primary key
#  program_id  :integer
#  status      :integer
#  sender_id   :integer
#  receiver_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class MentorRecommendation < ActiveRecord::Base
  include MentorRecommendationElasticsearchSettings
  include MentorRecommendationElasticsearchQueries

  REINDEX_FOR_UPDATED_AT = true

  module Status
    DRAFTED   = 0
    PUBLISHED = 1

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module Source
    NEW_PAGE = 'new_page'
    ADMIN_QUICK_CONNECT = "quick_connect_box_admin"
  end

  # Associations
  has_many :recommendation_preferences, -> { order(:position) },  dependent: :destroy
  belongs_to :program
  belongs_to :sender, :class_name => 'User', :foreign_key => 'sender_id'
  belongs_to :receiver, :class_name => 'User', :foreign_key => 'receiver_id'
  has_many :recommended_users, -> { order 'recommendation_preferences.position' }, through: :recommendation_preferences, :source => :preferred_user
  has_many :push_notifications, :as => :ref_obj

  # Validations
  validates_presence_of :sender, :receiver, :status
  validates :receiver_id, uniqueness: true
  validates :status, inclusion: {in: Status.all}

  after_save :reindex_followups, :set_published_at
  after_destroy :reindex_followups

  def self.send_bulk_publish_mails(program_id, receiver_ids)
    mentor_recommendations = Program.find(program_id).mentor_recommendations.where(receiver_id: receiver_ids)
    mentor_recommendations.each do |mr|
      MentorRecommendation.handle_publish_notifications(mr) if mr.recommendation_preferences.present? && mr.receiver.present?
    end
  end

  def self.handle_publish_notifications(mentor_recommendation)
    Push::Base.queued_notify(PushNotification::Type::MENTOR_RECOMMENDATION_PUBLISH, mentor_recommendation)
    ChronusMailer.mentor_recommendation_notification(mentor_recommendation.receiver, mentor_recommendation).deliver_now
  end

  def self.es_reindex(mentor_recommendations)
    [mentor_recommendations].flatten.each { |mentor_recommendation| RecommendationPreference.es_reindex(mentor_recommendation.recommendation_preferences) }
  end

  def reindex_followups
    MentorRecommendation.es_reindex(self) if saved_change_to_status?
  end

  def valid_recommendation_preferences
    recommendation_preferences = []
    self.recommendation_preferences.each do |rp|
      recommendation_preferences << rp unless (self.receiver.actively_connected_with?(rp.preferred_user) || self.program.mentor_requests.involving([self.receiver, rp.preferred_user]).try(:active).try(:present?))
    end
    return recommendation_preferences
  end

  def drafted?
    self.status == Status::DRAFTED
  end

  def published?
    self.status == Status::PUBLISHED
  end

  def publish!
    return true if published?
    self.status = Status::PUBLISHED
    self.published_at = Time.now
    save!
    MentorRecommendation.handle_publish_notifications(self) unless recommendation_preferences.blank?
  end

  def recommendations_hash
    results_hash = {}
    recommendation_preferences.each do |rp|
      results_hash[rp.preferred_user.id] = true
    end
    results_hash
  end

  def set_published_at
    self.update_columns(published_at: Time.now) if self.published? && self.published_at.nil?
  end

  def is_drafted_mentor_recommendation_for?(mentor_ids)
    return drafted? && recommendation_preferences.pluck(:user_id) == mentor_ids.collect(&:to_i)
  end

end
