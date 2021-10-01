# == Schema Information
#
# Table name: experiences
#
#  id                :integer          not null, primary key
#  job_title         :string(255)
#  start_year        :integer
#  end_year          :integer
#  company           :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  start_month       :integer          default(0)
#  end_month         :integer          default(0)
#  current_job       :boolean          default(FALSE)
#  profile_answer_id :integer          not null
#

class Experience < ActiveRecord::Base
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  belongs_to :profile_answer

  validates :company, :profile_answer, presence: true
  validates :start_month, :end_month, inclusion: { in: 0..12 }
  validates :start_year, :end_year, inclusion: ProfileConstants.valid_years, allow_blank: true
  validate :validate_end_year

  include MaxAnswersCalculator

  def self.max_count_for_single_answer(profile_answer_ids)
    self.count_by_sql([%Q[
      SELECT MAX(exp_count)
      FROM (
        SELECT COUNT(*)
        AS exp_count
        FROM experiences
        WHERE profile_answer_id IN (?)
        GROUP BY profile_answer_id) experience_count
      ], profile_answer_ids])
  end

  def self.valid_months_array
    # [["Month", 0], ["Jan", 1], ["Feb", 2], ["Mar", 3], ["Apr", 4], ["May", 5], ["Jun", 6], ["Jul", 7], ["Aug", 8], ["Sep", 9], ["Oct", 10], ["Nov", 11], ["Dec", 12]]
    months = "date.abbr_month_names_array".translate
    [["display_string.Month".translate, 0]] + (1..12).map{|month| [months[month-1], month]}
  end

  # Returns whether any of the date components of the experience is provided.
  def dates_present?
    self.start_year || self.end_year
  end

  def user
    self.user_answer.user
  end

  def self.column_names_for_question(question)
    question.experience? ? export_column_names.map { |_, name| "#{question.question_text}-#{name}" } : []
  end

  def self.export_column_names
    {
      job_title: "feature.education_and_experience.content.job_title".translate,
      start_year: "feature.education_and_experience.content.start_year".translate,
      end_year: "feature.education_and_experience.content.end_year".translate,
      company: "feature.education_and_experience.content.company_institution".translate
    }
  end

  private

  def validate_end_year
    return unless self.start_year && self.end_year
    return if self.current_job?
    errors[:base] << "activerecord.custom_errors.experience.end_year_before_start".translate if self.start_year > self.end_year
  end
end