# == Schema Information
#
# Table name: user_favorites
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  favorite_id       :integer          not null
#  created_at        :datetime
#  updated_at        :datetime
#  note              :text(65535)
#  position          :integer
#  type              :string(255)
#  mentor_request_id :integer
#

class UserFavorite < ActiveRecord::Base
  MASS_UPDATE_ATTRIBUTES = {
    create: [:favorite_id]
  }
  belongs_to_student_with_validations :user, :foreign_key => 'user_id'
  belongs_to_mentor_with_validations :favorite, :foreign_key => 'favorite_id'

  validates_uniqueness_of :user_id, :scope => [:favorite_id, :mentor_request_id], :if => Proc.new{|user_fav| user_fav.class == UserFavorite }
end
