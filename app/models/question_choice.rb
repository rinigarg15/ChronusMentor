# == Schema Information
#
# Table name: question_choices
#
#  id           :integer          not null, primary key
#  text         :text(16777215)
#  is_other     :boolean          default(FALSE)
#  position     :integer          default(0)
#  ref_obj_id   :integer
#  ref_obj_type :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class QuestionChoice < ActiveRecord::Base
  belongs_to :ref_obj, polymorphic: true # ProfileQuestion, CommonQuestion
  # answer choices are destroyed in the after destroy of question_choices
  has_many :answer_choices
  has_many :answer_choice_versions
  has_many :profile_answers, through: :answer_choices, source_type: ProfileAnswer.name, source: :ref_obj
  has_many :common_answers, through: :answer_choices, source_type: CommonAnswer.name, source: :ref_obj
  has_many :conditional_match_choices, dependent: :destroy
  has_many :user_preference_choices, dependent: :destroy
  has_many :explicit_user_preferences, through: :user_preference_choices
  has_many :user_search_activities, dependent: :nullify
  has_many :preference_based_mentor_lists, dependent: :destroy, as: :ref_obj

  validates :text, presence: true, uniqueness: { scope: [:ref_obj_id, :ref_obj_type] }
  validates :ref_obj, presence: true

  translates :text

  default_scope -> { order("question_choices.position ASC") }
  scope :other_choices, -> { where(is_other: true) }
  scope :default_choices, -> { where(is_other: false) }

  def populate_question_choice_attributes
    qc_attributes = self.attributes
    qc_attributes["text"] = self.text
    return qc_attributes
  end

  # Running SFTP feed and Import CSV users parallely might create duplicate other choice records. So cleaning other choice records post imports.
  def self.cleanup_duplicate_other_choices(question_ids, question_type = ProfileQuestion.name)
    return unless question_ids.present?

    duplicate_qcs = QuestionChoice.includes(:translations).where(is_other: true, ref_obj_id: question_ids, ref_obj_type: question_type).group_by{|qc| [qc.ref_obj_id, qc.ref_obj_type, qc.text] }.select{|_k, v| v.size > 1 }

    duplicate_qcs.each do |_group_by_qc, qcs|
      valid_qc = qcs[0]
      qcs[1..-1].each do |duplicate_qc|
        duplicate_qc.answer_choices.update_all(question_choice_id: valid_qc.id)
        duplicate_qc.translations.delete_all
        duplicate_qc.delete
      end
    end
  end
end
