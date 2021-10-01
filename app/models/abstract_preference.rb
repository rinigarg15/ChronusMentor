class AbstractPreference < ActiveRecord::Base
  MASS_UPDATE_ATTRIBUTES = {
    create: [:preference_marked_user_id]
  }

  FAVORITE_THRESHOLD = 5

  module Source
    SYSTEM_RECOMMENDATIONS = 'sys_rec'
    ADMIN_RECOMMENDATIONS = 'admin_rec'
    EXPLICIT_PREFERENCES_RECOMMENDATIONS ='explicit_pre_rec'
    PROFILE = 'profile'
    LISTING = 'listing'
  end

  # Relationships
  belongs_to_student_with_validations :preference_marker_user, foreign_key: :preference_marker_user_id
  belongs_to_mentor_with_validations :preference_marked_user, foreign_key: :preference_marked_user_id

  # Validations
  validates :preference_marker_user_id, :preference_marked_user_id, presence: true
  validates_uniqueness_of :type, :scope => [:preference_marker_user_id, :preference_marked_user_id]
  validate :check_program_integrity, :if => Proc.new{ |preference| preference.preference_marker_user && preference.preference_marked_user }

  private
  
  # Make sure the marker_user and the marked user's program are the same.
  def check_program_integrity
    if self.preference_marker_user.program != self.preference_marked_user.program
      self.errors[:base] << "activerecord.custom_errors.skip_and_favorite_profile.different_programs".translate
    end
  end
end