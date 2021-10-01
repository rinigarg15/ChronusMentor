class ChangeDelimitorForMatchConfig < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      ActiveRecord::Base.transaction do
        MatchConfig.where(matching_type: MatchConfig::MatchingType::SET_MATCHING).find_each do |match_config|
          new_display_hash = get_converted_hashes(match_config.matching_details_for_display)
          match_config.matching_details_for_display = new_display_hash
          match_config.save!
        end
      end
    end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      ActiveRecord::Base.transaction do
        MatchConfig.where(matching_type: MatchConfig::MatchingType::SET_MATCHING).find_each do |match_config|
          new_display_hash = get_converted_hashes(match_config.matching_details_for_display, QuestionChoiceExtensions::SELECT2_SEPARATOR, ",")
          match_config.matching_details_for_display = new_display_hash
          match_config.save!
        end
      end
    end
  end

  def get_converted_hashes(display_hash, old_delimitor = ",", new_delimitor = QuestionChoiceExtensions::SELECT2_SEPARATOR)
    new_display_hash = {}
    display_hash.each do |key, value|
      new_display_hash[key.gsub(old_delimitor, new_delimitor)] = value.gsub(old_delimitor, new_delimitor)
    end
    new_display_hash
  end

end
