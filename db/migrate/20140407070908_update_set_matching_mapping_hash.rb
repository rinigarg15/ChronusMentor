class UpdateSetMatchingMappingHash< ActiveRecord::Migration[4.2]
  def change
    MatchConfig.where(matching_type: MatchConfig::MatchingType::SET_MATCHING).each do |mc|
      matching_hash = mc.matching_details_for_matching 
      new_matching_hash = {}
      matching_hash.each do |mentee_choice, mentor_choices|
      	new_matching_hash[mentee_choice.remove_braces_and_downcase] = mentor_choices.map{|choice| choice.remove_braces_and_downcase}
      end
      mc.matching_details_for_matching = new_matching_hash
      mc.save!
    end
  end
end
