# == Schema Information
#
# Table name: publications
#
#  id                :integer          not null, primary key
#  title             :string(255)
#  publisher         :string(255)
#  url               :string(255)
#  authors           :text(16777215)
#  description       :text(16777215)
#  profile_answer_id :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  day               :integer
#  month             :integer
#  year              :integer
#

class Publication < ActiveRecord::Base
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  belongs_to :profile_answer

  validates :title, :profile_answer, :presence => true
  before_validation :add_url_protocol

  include MaxAnswersCalculator

  def self.max_count_for_single_answer(profile_answer_ids)
    self.count_by_sql([%Q[
      SELECT MAX(publication_count)
      FROM (
        SELECT COUNT(*)
        AS publication_count
        FROM publications
        WHERE profile_answer_id IN (?)
        GROUP BY profile_answer_id) publication_count
      ], profile_answer_ids])
  end

  def user
    self.profile_answer.member
  end
  
  def formatted_date
    return "" if year.blank?
    fixed_day, fixed_month = self.prepare_day_and_month
    date = Date.civil(year, fixed_month, fixed_day)
    if year && month && day
      DateTime.localize(date, format: :short)
    elsif year && month
      DateTime.localize(date, format: :month_year)
    elsif year
      DateTime.localize(date, format: :year_only)
    end
  end

  def prepare_day_and_month
    fixed_day = day || 1
    fixed_month = month || 1
    # Hadle wrong day in month(e.g February), like linkedin does
    if year && month && day
      days_in_month = Time.days_in_month(month, year)
      if day > days_in_month
        fixed_month += 1
        fixed_day -= days_in_month
      end
    end
    [fixed_day, fixed_month]
  end

  def self.column_names_for_question(question)
    question.publication? ? export_column_names.map { |_, name| "#{question.question_text}-#{name}" } : []
  end

  def self.export_column_names
    {
      title: Publication.human_attribute_name(:title),
      publisher: Publication.human_attribute_name(:publisher),
      date: Publication.human_attribute_name(:date),
      url: Publication.human_attribute_name(:url),
      authors: Publication.human_attribute_name(:authors),
      description: Publication.human_attribute_name(:description)
    }
  end

  protected

  def add_url_protocol
    if self.url.present? && self.url[/^http:\/\//].nil? && self.url[/^https:\/\//].nil?
      self.url = 'http://' + self.url
    end
  end
end
