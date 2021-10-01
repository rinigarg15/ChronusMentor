# == Schema Information
#
# Table name: bulk_matches
#
#  id                   :integer          not null, primary key
#  mentor_view_id       :integer
#  mentee_view_id       :integer
#  program_id           :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  show_drafted         :boolean          default(TRUE)
#  show_published       :boolean          default(TRUE)
#  sort_value           :string(255)
#  sort_order           :boolean          default(TRUE)
#  request_notes        :boolean          default(TRUE)
#  max_pickable_slots   :integer
#  type                 :string(255)      default("BulkMatch")
#  max_suggestion_count :integer
#  default              :integer          default(0)
#

class AbstractBulkMatch < ActiveRecord::Base
  self.table_name = 'bulk_matches'

  module Src
    BULK_RECOMMENDATION = "bulk_recommendation"
    MENTEE_TO_MENTOR_BULK_MATCH = "mentee_to_mentor_bulk_match"
    MENTOR_TO_MENTEE_BULK_MATCH = "mentor_to_mentee_bulk_match"
  end

  module StepConstants
    SELECT_USERS = 1
    FIND_MATCHES = 2
  end

  module UpdateType
    DRAFT = 'draft'
    PUBLISH = 'publish'
    DISCARD = 'discard'
  end

  DEFAULT_SUGGESTION_LENGTH = 10
  MATCH_CONFIG_SEPARATOR = "||"
  DEFAULT_MENTEE_PICKABLE_SLOTS = 1

  belongs_to :program
  belongs_to :mentor_view, :class_name => 'AdminView', :foreign_key => 'mentor_view_id'
  belongs_to :mentee_view, :class_name => 'AdminView', :foreign_key => 'mentee_view_id'

  validates :program, :mentor_view, :mentee_view, :presence => true
  validates :program_id, uniqueness: {scope: [:type, :orientation_type]}

  def self.valid_bulk_match_types
    [BulkMatch.name, BulkRecommendation.name]
  end

  def self.fetch_settings_paths
    ["fetch_settings_bulk_matches_path", "fetch_settings_bulk_recommendations_path"]
  end

  def self.refresh_results_paths
    ["refresh_results_bulk_matches_path", "refresh_results_bulk_recommendations_path"]
  end

  def update_bulk_entry(mentor_view_id, mentee_view_id)
    if self.new_record?
      is_recommendation = self.is_a?(BulkRecommendation)
      self.max_pickable_slots = self.get_default_pickable_slots
      self.max_suggestion_count = BulkRecommendation::DEFAULT_MAX_RECOMMENDATION_COUNT if is_recommendation
      self.request_notes = !is_recommendation
    end
    if mentor_view_id.present? && mentee_view_id.present?
      self.update_attributes!(mentor_view_id: mentor_view_id, mentee_view_id: mentee_view_id, default: 1)
    end
  end

  def get_default_pickable_slots
    self.orientation_type ==  BulkMatch::OrientationType::MENTOR_TO_MENTEE ? DEFAULT_MENTEE_PICKABLE_SLOTS : self.program.default_max_connections_limit
  end

  private

  def get_globalized_answer(answers, question_id)
    answer = answers[question_id]
    return "" if answer.nil? || answer.answer_text.nil?
    return answer.answer_text unless answer.profile_question.choice_or_select_type?
    answer.selected_choices_to_str
  end

end
