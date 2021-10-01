class MatchConfigDiscrepancyCache < ActiveRecord::Base
  belongs_to :match_config
  validates :match_config, presence: true
  validate :check_match_config_question_choice_based_or_location?

  serialize :top_discrepancy

  def self.refresh_top_discrepancies
    BlockExecutor.iterate_fail_safe(MatchConfigDiscrepancyCache.includes(:match_config)) do |match_config_discrepancy_cache|
      match_config = match_config_discrepancy_cache.match_config
      top_discrepancy = MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.new(match_config.program, {match_config: match_config}).calculate_data_discrepancy.first(MatchReport::MentorDistribution::CATEGORIES_SIZE)
      current_time = DateTime.now.utc
      match_config_discrepancy_cache.update_columns(top_discrepancy: top_discrepancy, updated_at: current_time)
    end
  end

  private

  def check_match_config_question_choice_based_or_location?
    if self.match_config.present?
      unless (self.match_config.questions_choice_based?)
        self.errors.add(:match_config, "activerecord.custom_errors.match_config_discrepancy_cache.cant_be_cached".translate)
      end
    end
  end
end