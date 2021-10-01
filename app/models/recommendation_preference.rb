# == Schema Information
#
# Table name: recommendation_preferences
#
#  id                       :integer          not null, primary key
#  user_id                  :integer
#  note                     :text(65535)
#  position                 :integer
#  mentor_recommendation_id :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

class RecommendationPreference < ActiveRecord::Base
  belongs_to :preferred_user, :class_name => 'User', :foreign_key => 'user_id'
  belongs_to :mentor_recommendation

  after_destroy :reindex_preferred_user, :destroy_recommendation_if_no_preferences
  after_save :reindex_preferred_user

  def self.es_reindex(recommendation_preferences)
    DelayedEsDocument.delayed_bulk_update_es_documents(User, [recommendation_preferences].flatten.map(&:user_id))
  end

  private

  def reindex_preferred_user
    RecommendationPreference.es_reindex(self)
  end

  def destroy_recommendation_if_no_preferences
    # destroying the orphaned parent
    mentor_recommendation.destroy if mentor_recommendation.reload.recommendation_preferences.count.zero?
  end
end
