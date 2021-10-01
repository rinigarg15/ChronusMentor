class MatchConfigObserver < ActiveRecord::Observer
  def after_save(match_config)
    create_match_config_discrepancy_cache(match_config)
  end

  def after_update(match_config)
    return unless match_config.update_match_config_discrepancy_cache?
    create_match_config_discrepancy_cache(match_config)
  end

  private

  def create_match_config_discrepancy_cache(match_config)
    return unless match_config.present?
    match_config.delay(queue: DjQueues::HIGH_PRIORITY).refresh_match_config_discrepancy_cache if match_config.can_create_match_config_discrepancy_cache?
  end
end