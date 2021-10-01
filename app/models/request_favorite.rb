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

class RequestFavorite < UserFavorite
  belongs_to :mentor_request, :foreign_key => 'mentor_request_id'
  belongs_to :favorite, :class_name => "User"

  validates_uniqueness_of :user_id, :scope => [:favorite_id, :mentor_request_id]
  validates_presence_of :mentor_request
  validate :check_student_is_user

  private

  def check_student_is_user
    if self.mentor_request && (self.user != self.mentor_request.student)
      errors.add(:user, "activerecord.custom_errors.request_favorite.invalid_user".translate)
    end
  end
end
