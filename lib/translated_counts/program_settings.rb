module TranslatedCounts::ProgramSettings
  def get_score_for_program_settings(prog_or_org, locale)
    total_score = {}
    prog_or_org.translation_settings_sub_categories.each do |sub_category|
      items = get_translatable_objects_program_settings(sub_category[:id], prog_or_org)
      tab_score = [0, 0]
      items.each do |item|
        score = get_translation_score_or_elements_for_object(item, locale, prog_or_org.standalone?, LocalizableContent::PROGRAM_SETTINGS, sub_category[:id])
        tab_score = [tab_score, score].transpose.map{|a| a.sum} unless score.nil? && score.empty?
      end
      total_score[sub_category[:id]] = tab_score
    end
    return total_score
  end

  def get_translatable_objects_program_settings(tab_id, level_obj)
    organization = level_obj.is_a?(Organization) ? level_obj : level_obj.organization
    objects = case tab_id
      when ProgramsController::SettingsTabs::GENERAL, ProgramsController::SettingsTabs::MATCHING
        level_obj.standalone? ? [organization.programs.first] : [level_obj]
      when ProgramsController::SettingsTabs::TERMINOLOGY
        relation = LocalizableContent.tab_relations[tab_id]
        level_obj.send(relation)
      when ProgramsController::SettingsTabs::MEMBERSHIP, ProgramsController::SettingsTabs::CONNECTION
        relation = LocalizableContent.tab_relations[tab_id]
        (level_obj.standalone? ? organization.programs.first : level_obj).send(relation).includes(:translations)
      end
    return objects
  end
end