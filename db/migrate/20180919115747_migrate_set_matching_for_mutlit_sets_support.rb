class MigrateSetMatchingForMutlitSetsSupport < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      ActiveRecord::Base.transaction do
        MatchConfig.where(matching_type: MatchConfig::MatchingType::SET_MATCHING).includes(student_question: :profile_question).find_each do |match_config|
          display_hash = match_config.matching_details_for_display
          if display_hash.keys.any?{|k| k.match(QuestionChoiceExtensions::SELECT2_SEPARATOR).present? }
            match_config.matching_details_for_display = get_display_hash(display_hash)
          end
          match_config.matching_details_for_matching = get_matching_hash(match_config.matching_details_for_matching)
          if match_config.student_question.profile_question.question_type.in?([ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]) && match_config.threshold > 0.0 && match_config.operator == MatchConfig::Operator.lt
            match_config.threshold = [match_config.threshold, (1.to_f/match_config.matching_details_for_matching.keys.count).round(2)].min
          end
          match_config.save!
        end
      end
    end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      ActiveRecord::Base.transaction do
        MatchConfig.where(matching_type: MatchConfig::MatchingType::SET_MATCHING).find_each do |match_config|
          match_config.matching_details_for_matching = get_matching_hash(match_config.matching_details_for_matching, true)
          match_config.save!
        end
      end
    end
  end

  def get_display_hash(display_hash)
    new_display_hash = {}
    display_hash.each do |key, value|
      mentee_choices = key.split(QuestionChoiceExtensions::SELECT2_SEPARATOR)
      mentee_choices.each do |choice|
        new_display_hash[choice] ||= []
        new_display_hash[choice] += value.split(QuestionChoiceExtensions::SELECT2_SEPARATOR)
      end
    end
    new_display_hash.each {|k, v| new_display_hash[k] = v.uniq.join(QuestionChoiceExtensions::SELECT2_SEPARATOR)}
    new_display_hash
  end

  def get_matching_hash(matching_hash = {}, flatten = false)
    matching_hash.each { |k, v|  matching_hash[k] = (flatten ? [v].flatten : [v.uniq]) }
    matching_hash
  end

end
