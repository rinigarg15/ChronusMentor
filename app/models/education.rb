# == Schema Information
#
# Table name: educations
#
#  id                :integer          not null, primary key
#  school_name       :string(255)
#  degree            :string(255)
#  major             :string(255)
#  graduation_year   :integer
#  created_at        :datetime
#  updated_at        :datetime
#  profile_answer_id :integer          not null
#

class Education < ActiveRecord::Base
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  belongs_to :profile_answer

  validates :school_name, :profile_answer, presence: true
  validates :graduation_year, inclusion: ProfileConstants.valid_graduation_years, allow_blank: true

  include MaxAnswersCalculator

  def self.max_count_for_single_answer(profile_answer_ids)
    self.count_by_sql([%Q[
      SELECT MAX(edu_count)
      FROM (
        SELECT COUNT(*)
        AS edu_count
        FROM educations
        WHERE profile_answer_id IN (?)
        GROUP BY profile_answer_id) educations_count
      ], profile_answer_ids])
  end

  def user
    self.profile_answer.member
  end

  def self.column_names_for_question(question)
    question.education? ? export_column_names.map { |_, name| "#{question.question_text}-#{name}" } : []
  end

  def self.export_column_names
    {
      school_name: "feature.education_and_experience.content.college_school_name".translate,
      degree: "feature.education_and_experience.content.degree".translate,
      major: "feature.education_and_experience.content.major".translate,
      graduation_year: "feature.education_and_experience.content.graduation_year".translate
    }
  end
end