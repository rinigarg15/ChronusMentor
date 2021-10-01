# == Schema Information
#
# Table name: survey_response_columns
#
#  id                  :integer          not null, primary key
#  survey_id           :integer
#  profile_question_id :integer
#  column_key          :string(255)
#  position            :integer
#  survey_question_id  :integer
#  ref_obj_type        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class SurveyResponseColumn < ActiveRecord::Base

  module Columns
    SenderName = "name"
    ResponseDate = "date"
    SurveySpecific = "surveySpecific"
    Roles = "roles"
    Program = "program"

    def self.default_columns
      [SenderName, ResponseDate, SurveySpecific, Roles]
    end

    def self.survey_specific
      [SurveySpecific]
    end
  end

  module ColumnType
    DEFAULT = 0
    USER = 1
    SURVEY = 2

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  belongs_to :survey
  belongs_to :profile_question
  belongs_to :survey_question

  validates :survey, :presence => true
  validates :ref_obj_type, inclusion: {in: ColumnType.all}

  scope :of_default_columns, -> { where(:ref_obj_type => ColumnType::DEFAULT)}
  scope :of_survey_questions, -> { where(:ref_obj_type => ColumnType::SURVEY)}
  scope :of_profile_questions, -> { where(:ref_obj_type => ColumnType::USER)}

  validate :check_valid_column_type

  def key
    self.column_key || (self.profile_question_id.presence ? self.profile_question_id.to_s : self.survey_question_id.to_s)
  end

  def kendo_column_field
    if self.column_key.present?
      return self.column_key
    elsif self.profile_question_id.present?
      return "column#{self.profile_question_id}"
    elsif self.survey_question_id.present?
      return "answers#{self.survey_question_id}"
    end
  end

  def kendo_field_header
    if self.column_key == Columns::SenderName
      "feature.survey.responses.fields.name".translate
    elsif self.column_key == Columns::ResponseDate
      "feature.survey.responses.fields.date".translate
    elsif self.column_key == Columns::Roles
      "feature.survey.survey_report.filters.header.user_role".translate
    elsif self.column_key == Columns::SurveySpecific
      self.survey.engagement_survey? ? self.survey.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term : self.survey.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term
    end
  end

  def self.date_range_columns(survey)
    fields = [SurveyResponseColumn::Columns::ResponseDate]
    return fields unless survey
    fields += survey.survey_response_columns.joins(:profile_question).where("profile_questions.question_type = ?", ProfileQuestion::Type::DATE).collect(&:kendo_column_field)
    fields
  end

  def self.get_default_title(key, survey)
    case key
    when Columns::SenderName
      "feature.survey.responses.fields.name".translate
    when Columns::ResponseDate
      "feature.survey.responses.fields.date".translate
    when Columns::Roles
      "feature.survey.survey_report.filters.header.user_role".translate
    when Columns::SurveySpecific
      survey.engagement_survey? ? survey.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term : survey.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term
    end
  end

  def self.find_object(column_object_array, key, ref_obj_type)
    case ref_obj_type
    when ColumnType::DEFAULT
      column_object_array.find{|column| column.column_key == key}
    when ColumnType::USER
      column_object_array.find{|column| column.profile_question_id == key.to_i}
    when ColumnType::SURVEY
      column_object_array.find{|column| column.survey_question_id == key.to_i}
    end
  end

  protected

  def check_valid_column_type
    is_valid_column = true
    case self.ref_obj_type
    when ColumnType::DEFAULT
      is_valid_column = self.column_key.present? && Columns.default_columns.include?(self.column_key) && self.profile_question_id.blank? && self.survey_question_id.blank?
    when ColumnType::USER
      is_valid_column = self.column_key.blank? && self.profile_question_id.present? && self.survey_question_id.blank?
    when ColumnType::SURVEY
      is_valid_column = self.column_key.blank? && self.profile_question_id.blank? && self.survey_question_id.present?
    else
      is_valid_column = false
    end
    self.errors.add(:base, "activerecord.custom_errors.survey_response_column.invalid_column".translate) unless is_valid_column
  end
  
end
