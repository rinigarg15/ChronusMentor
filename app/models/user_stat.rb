# == Schema Information
#
# Table name: user_stats
#
#  id             :integer          not null, primary key
#  user_id        :integer
#  average_rating :float(24)        default(0.5)
#  rating_count   :integer          default(0)
#

class UserStat < ActiveRecord::Base
  self.table_name = :user_stats

  module Rating
    MIN_RATING = 0.5
    MAX_RATING = 5
    DELTA = 0.001
  end
  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to :user
  
  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :user
  validates :rating_count, numericality: {:greater_than_or_equal_to => 0}, :presence => true
  validates :average_rating, numericality: {:greater_than_or_equal_to => Feedback::Response::MIN_RATING, :less_than_or_equal_to => Feedback::Response::MAX_RATING}, :presence => true

  after_save :reindex_user
  after_destroy :reindex_user


  def update_rating_on_response_create(rating_given)
    self.average_rating = (self.average_rating*self.rating_count + rating_given)/(self.rating_count + 1)
    self.rating_count = self.rating_count + 1
    self.save
  end

  def update_rating_on_response_update(rating_given, old_rating)
    self.average_rating = (self.average_rating*self.rating_count + rating_given - old_rating)/self.rating_count
    self.save
  end

  def update_rating_on_response_destroy(rating_given)
    if self.rating_count == 1
      self.destroy
    else
      self.average_rating = (self.average_rating*self.rating_count - rating_given)/(self.rating_count - 1)
      self.rating_count = self.rating_count - 1
      self.save
    end
  end

  def self.es_reindex(user_stat)
    DelayedEsDocument.do_delta_indexing(User, Array(user_stat), :user_id)
  end

  def reindex_user
    return unless self.new_record? || self.saved_change_to_average_rating? || self.destroyed?
    self.class.es_reindex(self)
  end
end