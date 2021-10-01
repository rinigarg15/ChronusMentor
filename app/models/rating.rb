# == Schema Information
#
# Table name: ratings
#
#  id               :integer          not null, primary key
#  rating           :integer
#  rateable_type    :string(255)
#  rateable_id      :integer
#  user_id          :integer
#  created_at       :datetime
#  updated_at       :datetime

class Rating < ActiveRecord::Base
  belongs_to :rateable, :polymorphic => true
  
  # NOTE: Comments belong to a user
  belongs_to :user

  # Used for article rating at Organization level.
  belongs_to :member, :foreign_key => 'user_id'
  
  # Helper class method to lookup all ratings assigned
  # to all rateable types for a given user.
  def self.find_ratings_by_user(user)
    find(:all,
      :conditions => ["user_id = ?", user.id],
      :order => "created_at DESC"
    )
  end
end