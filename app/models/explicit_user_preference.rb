# == Schema Information
#
# Table name: explicit_user_preferences
#
#  id                 :integer          not null, primary key
#  preference_weight  :integer          default: 3
#  from_match_config  :boolean          default: false
#  preference_string  :text(65535)
#  user_id            :integer
#  role_question_id   :integer
#  created_at         :datetime
#  updated_at         :datetime
#

class ExplicitUserPreference < ActiveRecord::Base

  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  has_many :user_preference_choices, dependent: :destroy
  has_many :question_choices, through: :user_preference_choices
  belongs_to :user
  belongs_to :role_question

  MASS_UPDATE_ATTRIBUTES = {
    create: [:role_question_id, :question_choice_ids, :preference_string],
    update: [:question_choice_ids, :preference_string],
    change_weight: [:preference_weight]
  }

  QUESTION_CHOICES_TRUNCATE_LENGTH = 80

  module PriorityValues
    NICE_TO_HAVE = 1
    SLIGHTLY_IMPORTANT = 2
    IMPORTANT = 3
    FAIRLY_IMPORTANT = 4
    VERY_IMPORTANT = 5

    def self.preference_weights_for_slider
      {
        NICE_TO_HAVE => "feature.explicit_preference.label.nice_to_have".translate,
        SLIGHTLY_IMPORTANT => "feature.explicit_preference.label.slightly_important".translate,
        IMPORTANT => "feature.explicit_preference.label.important".translate,
        FAIRLY_IMPORTANT => "feature.explicit_preference.label.fairly_important".translate,
        VERY_IMPORTANT => "feature.explicit_preference.label.very_important".translate
      }
    end
  end

  GA_SRC = [EngagementIndex::Src::ExplicitPreferences::HOME_PAGE, EngagementIndex::Src::ExplicitPreferences::MENTOR_LISTING_PAGE_ACTION, EngagementIndex::Src::ExplicitPreferences::MENTOR_LISTING_BOTTOM_BAR, EngagementIndex::Src::ExplicitPreferences::MATCH_DETAILS]

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates_presence_of :user, :role_question
  validates :preference_weight, inclusion: { in: PriorityValues::NICE_TO_HAVE..PriorityValues::VERY_IMPORTANT }
  validate :check_preference_field_based_on_question_type

  def self.populate_default_explicit_user_preferences_from_match_configs(user, program)
    ActiveRecord::Base.transaction do
      GlobalizationUtils.run_in_locale(I18n.default_locale) do
        MatchConfig.get_match_configs_of_filterable_mentor_questions_for_mentee(user, program).each do |match_config|
          create_explicit_preference_based_on_match_config(user, match_config)
        end
      end
    end
  end

  def self.destroy_invalid_records(object)
    if object.instance_of?(User) || object.instance_of?(RoleQuestion)
      object.explicit_user_preferences.destroy_all
    elsif object.instance_of?(ProfileQuestion)
      destroy_explicit_preference_of_all_role_questions(object)
    elsif object.instance_of?(UserPreferenceChoice)
      destroy_explicit_preference_with_no_question_choices(object)
    end
  end

  def profile_question
    role_question.profile_question
  end

  def location_type?
    profile_question.location?
  end

  def weight_scaled_to_one
    preference_weight.to_f/PriorityValues::VERY_IMPORTANT
  end

  private

  def check_preference_field_based_on_question_type
    preference_role_question = self.role_question
    if preference_role_question.present?
      if preference_role_question.profile_question.location?
        check_preference_field_for_location_type
      else
        check_preference_field_for_choice_based
      end
    end
  end

  def check_preference_field_for_location_type
    errors.add(:question_choices, "activerecord.custom_errors.explicit_user_preferences.empty".translate) if self.question_choices.present?
    errors.add(:preference_string, "activerecord.custom_errors.explicit_user_preferences.blank".translate) unless self.preference_string.present?
  end

  def check_preference_field_for_choice_based
    errors.add(:question_choices, "activerecord.custom_errors.explicit_user_preferences.blank".translate) unless self.question_choices.present?
    errors.add(:preference_string, "activerecord.custom_errors.explicit_user_preferences.empty".translate) if self.preference_string.present?
  end

  def self.destroy_explicit_preference_of_all_role_questions(object)
    object.role_questions.includes(:explicit_user_preferences).each do |question|
      question.explicit_user_preferences.destroy_all
    end
  end

  def self.destroy_explicit_preference_with_no_question_choices(object)
    explicit_preference = object.explicit_user_preference.reload
    explicit_preference.destroy unless explicit_preference.question_choices.present?
  end

  def self.create_explicit_preference_based_on_match_config(user, match_config)
    question_choices_for_explicit_user_preference = []
    location_or_choices = match_config.get_mentor_location_or_questions_choices_for(user)
    if location_or_choices.is_a?(String)
      preference_string = location_or_choices
    else
      question_choices_for_explicit_user_preference = location_or_choices
    end
    ExplicitUserPreference.create!(user: user, role_question: match_config.mentor_question, preference_weight: convert_match_config_weight_to_prefernce_weight(match_config.weight), from_match_config: true, preference_string: preference_string, question_choices: question_choices_for_explicit_user_preference) if (question_choices_for_explicit_user_preference.present? || preference_string.present?)
  end

  def self.convert_match_config_weight_to_prefernce_weight(weight)
    (weight * PriorityValues::VERY_IMPORTANT).round
  end
end
