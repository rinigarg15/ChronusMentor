# == Schema Information
#
# Table name: user_preference_choices
#
#  id                                     :integer       not null, primary key
#  explicit_user_preference_id            :integer
#  question_choice_id                     :integer
#  created_at                             :datetime
#  updated_at                             :datetime
#

class UserPreferenceChoice < ActiveRecord::Base

  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  belongs_to :explicit_user_preference
  belongs_to :question_choice

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates_presence_of :question_choice, :explicit_user_preference

  #-----------------------------------------------------------------------------
  # CALLBACKS
  #-----------------------------------------------------------------------------

  after_destroy :destroy_invalid_explicit_preferences

  def destroy_invalid_explicit_preferences
    ExplicitUserPreference.destroy_invalid_records(self)
  end

end
