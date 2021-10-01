module TranslatedCounts
  include LocalizableContent
  include TranslatedCounts::ProgramSettings

  def get_score_for_prog_or_org(prog_or_org, locale)
    total_score = {}
    total_score[prog_or_org.id] = get_category_wise_score(prog_or_org, locale)
    if prog_or_org.standalone?
      total_score[prog_or_org.id].merge!(get_category_wise_score(prog_or_org.programs.first, locale)) do |category, score1, score2|
        (category == LocalizableContent::PROGRAM_SETTINGS) ? score1.merge(score2) { |tab_id, tab_score1, tab_score2| tab_score1 } : [score1, score2].transpose.map{|a| a.sum}
      end
      total_score[prog_or_org.id] = Hash[total_score[prog_or_org.id].sort_by{|category, _| LocalizableContent.all.index(category)}] # Preserving category order
    elsif prog_or_org.is_a?(Organization)
      prog_or_org.programs.each {|prog| total_score[prog.id] = get_category_wise_score(prog, locale) }
    end
    total_score.each do |id, _|
      total_score[id][LocalizableContent::PROGRAM_SETTINGS] = total_score[id][LocalizableContent::PROGRAM_SETTINGS].values.transpose.map{|a| a.sum} if total_score[id][LocalizableContent::PROGRAM_SETTINGS]
    end
    total_score
  end

  def get_category_wise_score(prog_or_org, locale)
    categories = LocalizableContent.send(prog_or_org.is_a?(Organization) ? :org_level : :program_level)
    total_score = {}
    categories.each do |category|
      if can_show_category?(category, prog_or_org)
        category_score = get_score_of_category(category, prog_or_org, locale)
        total_score[category] = category_score unless category_score == [0, 0]
      end
    end
    return total_score
  end

  def get_score_of_category(category, parent_obj, locale)
    return get_score_for_program_settings(parent_obj, locale) if category == LocalizableContent::PROGRAM_SETTINGS
    tree = LocalizableContent.relations[category]
    return get_score_by_tree_in_category(tree, [parent_obj.id], locale, parent_obj.class)
  end

  def get_score_by_tree_in_category(tree, parent_obj_ids, locale, parent_obj_class)
    return [0, 0] if parent_obj_ids.empty?
    current_node, lower_tree = tree.is_a?(Hash) ? tree.first : tree
    klass, foreign_key_column_name = klass_with_parent_foreign_key[current_node]
    ids = get_object_ids_for_node(klass, parent_obj_ids, foreign_key_column_name, parent_obj_class)
    return [0, 0] if ids.empty?
    overall = get_score_for_klass(klass, ids, locale)
    lower_tree.each {|lower_relation| overall = [overall, get_score_by_tree_in_category(lower_relation, ids, locale, klass)].transpose.map{|a| a.sum} } if lower_tree
    return overall
  end

  def get_score_for_klass(klass, ids, locale)
    foreign_key_in_translatable_class = klass.reflect_on_all_associations.detect{|k| k.name == :translations}.options[:foreign_key]
    translation_klass_parent = klass
    until translation_klass_parent.superclass == ActiveRecord::Base do
      translation_klass_parent = translation_klass_parent.superclass
    end
    translation_klass = "#{translation_klass_parent.to_s}::Translation".constantize
    attributes = LocalizableContent.attributes_for_model[klass]
    overall_table_counts = [0, 0]
    attributes.each do |attribute|
      overall_table_counts = [overall_table_counts, get_score_for_klass_by_column(translation_klass, attribute, ids, foreign_key_in_translatable_class, locale)].transpose.map{|a| a.sum}
    end
    return [overall_table_counts, [0, 0]].transpose.map{|a| a.sum}
  end

  def get_score_for_klass_by_column(translation_klass, translation_column, ids, foreign_key_in_translatable_class, locale)
    other_locale_count, en_locale_count = 0, 0
    en_translated_ids = translation_klass.where("#{foreign_key_in_translatable_class} IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(#{translation_column},'') <> ''").pluck(foreign_key_in_translatable_class)
    en_locale_count = en_translated_ids.size
    other_locale_count = translation_klass.where("#{foreign_key_in_translatable_class} IN (#{en_translated_ids.join(',')}) AND locale = '#{locale}' AND ifnull(#{translation_column},'') <> ''").count if en_locale_count > 0
    return other_locale_count, en_locale_count
  end

  def get_translation_score_or_elements_for_object(item, second_locale, standalone_case, category, tab = nil, attachment = nil, score = true)
    if can_item_be_edited?(item)
      attributes_by_model = LocalizableContent.attributes_for_model(category: category, tab: tab)
      attributes = (attributes_by_model[item.class] - (LocalizableContent.attribute_for_heading[item.class] || []))
      attributes = attributes_by_model[AbstractProgram] + attributes if item.is_a?(Organization)
      attributes = attributes.select{|attribute| attribute.match(/#{attachment}/)}
      locale_translation = item.translations.select{|t| t.locale == second_locale.to_sym}.first || {}
      en_translation =  item.translations.select{|t| t.locale == :en}.first || {}
      english_count = 0
      locale_count = 0
      en_elements, locale_elements = [], []

      attributes.each do |attribute|
        if en_translation[attribute].present?
          en_elements += [en_translation[attribute]]
          locale_elements += (locale_translation[attribute].present? ? [locale_translation[attribute]] : [""])
          english_count += 1
          locale_count += locale_translation[attribute].present? ? 1 : 0
        end
      end
      if standalone_case && category == LocalizableContent::PROGRAM_SETTINGS && tab.present? && tab == ProgramsController::SettingsTabs::GENERAL && item.is_a?(Program)
        attributes_by_model[Organization].each do |attribute|
          next unless (en_element = item.organization.translations.select{|t| t.locale == :en}.first || {})[attribute].present?
          en_elements += [en_element[attribute]]
          english_count += 1
          locale_element = item.organization.translations.select{|t| t.locale == second_locale.to_sym}.first || {}
          locale_count += (locale_element[attribute].present? ? 1 : 0)
          locale_elements += (locale_element[attribute].present? ? [locale_element[attribute]] : [""])
        end
      end
      return score ? [locale_count, english_count] : en_elements.zip(locale_elements)
    else
      return score ? [0,0] : []
    end
  end

  def get_object_ids_for_node(klass, parent_obj_ids, column_name, parent_obj_class)
    if get_object_ids_for_custom_classes[klass]
      return send(get_object_ids_for_custom_classes[klass], parent_obj_ids)
    else
      columns = Array(column_name)
      conditions = {columns[0] => parent_obj_ids}
      conditions[columns[1]] = parent_obj_class.base_class if columns[1].present?
      klass.where(conditions).pluck(:id)
    end
  end

  def get_email_templates_from_abstract_campaigns(campaign_ids)
    campaign_message_ids = CampaignManagement::AbstractCampaignMessage.where(campaign_id: campaign_ids).pluck(:id)
    return Mailer::Template.where(campaign_message_id: campaign_message_ids).pluck(:id)
  end

  def get_visible_surveys_from_program(program_ids)
    survey_ids = []
    program_ids.each do |program_id| 
      survey_ids += Program.find(program_id).visible_surveys.pluck(:id)
    end
    expired_survey_ids = ProgramSurvey.where(id: survey_ids).expired.pluck(:id)
    return survey_ids - expired_survey_ids
  end

  def get_sections_from_organization(org_ids)
    Section.where(program_id: org_ids).where("default_field IS NULL OR default_field = 0").pluck(:id)
  end

  def get_profile_questions_from_section(org_ids)
    ProfileQuestion.where(section_id: get_sections_from_organization(org_ids)).pluck(:id)
  end

  def get_survey_questions_from_surveys(program_ids)
    SurveyQuestion.where(survey_id: get_visible_surveys_from_program(program_ids)).pluck(:id)
  end

  [:goal_templates, :facilitation_templates, :task_templates, :milestone_templates].each do |method|
    define_method "get_#{method}_without_handle_hybrid_templates_from_mentoring_models" do |mentoring_model_ids|
      return [] if mentoring_model_ids.empty?
      basic_mentoring_model_ids = MentoringModel.where(id: mentoring_model_ids, mentoring_model_type: MentoringModel::Type::BASE).pluck(:id)
      case method
      when :task_templates
        MentoringModel::TaskTemplate.where(mentoring_model_id: basic_mentoring_model_ids).pluck(:id)
      when :goal_templates
        MentoringModel::GoalTemplate.joins('LEFT JOIN mentoring_models ON mentoring_model_goal_templates.mentoring_model_id = mentoring_models.id').where("mentoring_model_id IN (#{mentoring_model_ids.join(',')}) AND (mentoring_models.goal_progress_type = #{MentoringModel::GoalProgressType::AUTO})").pluck(:id)
      when :milestone_templates
        MentoringModel::MilestoneTemplate.where(mentoring_model_id: basic_mentoring_model_ids).pluck(:id)
      when :facilitation_templates
        MentoringModel::FacilitationTemplate.where(mentoring_model_id: basic_mentoring_model_ids).pluck(:id)
      end
    end
  end

  def can_item_be_edited?(obj)
    object_condition = LocalizableContent.get_editable_condition[obj.class]
    val = true
    object_condition.each{|cond| val &&= !obj.send(cond)} if object_condition
    return val
  end

  def can_show_category?(category, level_obj)
    feature = LocalizableContent.feature_dependency[category]
    organization = level_obj.is_a?(Organization) ? level_obj : level_obj.organization
    return feature.nil? ||
      (level_obj.standalone? ? (org_category?(category) && organization.has_feature?(feature)) || (prog_category?(category) && organization.programs.first.has_feature?(feature)) :
         level_obj.has_feature?(feature))
  end

  def get_object_ids_for_custom_classes
    {
      Mailer::Template => :get_email_templates_from_abstract_campaigns,
      Survey => :get_visible_surveys_from_program,
      SurveyQuestion => :get_survey_questions_from_surveys,
      Section => :get_sections_from_organization,
      ProfileQuestion => :get_profile_questions_from_section,
      MentoringModel::GoalTemplate => :get_goal_templates_without_handle_hybrid_templates_from_mentoring_models,
      MentoringModel::MilestoneTemplate => :get_milestone_templates_without_handle_hybrid_templates_from_mentoring_models,
      MentoringModel::TaskTemplate => :get_task_templates_without_handle_hybrid_templates_from_mentoring_models,
      MentoringModel::FacilitationTemplate => :get_facilitation_templates_without_handle_hybrid_templates_from_mentoring_models
    }
  end

  def klass_with_parent_foreign_key
    {
      :announcements => [Announcement, :program_id],
      :abstract_campaigns => [CampaignManagement::AbstractCampaign, :program_id],
      :email_templates => [Mailer::Template, :program_id],
      :abstract_instructions => [AbstractInstruction, :program_id],
      :contact_admin_setting => [ContactAdminSetting, :program_id],
      :connection_questions => [Connection::Question, :program_id],
      :mentoring_models => [MentoringModel, :program_id],
      :mentoring_model_goal_templates_without_handle_hybrid_templates => [MentoringModel::GoalTemplate, :mentoring_model_id],
      :mentoring_model_milestone_templates_without_handle_hybrid_templates => [MentoringModel::MilestoneTemplate, :mentoring_model_id],
      :mentoring_model_task_templates_without_handle_hybrid_templates => [MentoringModel::TaskTemplate, :mentoring_model_id],
      :mentoring_model_facilitation_templates_without_handle_hybrid_templates => [MentoringModel::FacilitationTemplate, :mentoring_model_id],
      :program_asset => [ProgramAsset, :program_id],
      :program_events => [ProgramEvent, :program_id],
      :pages => [Page, :program_id],
      :resources => [Resource, :program_id],
      :visible_surveys => [Survey, :program_id],
      :survey_questions => [SurveyQuestion, :program_id],
      :sections => [Section, :program_id],
      :profile_questions => [ProfileQuestion, :organization_id],
      :default_question_choices => [QuestionChoice, [:ref_obj_id, :ref_obj_type]] # Use an array with 2 elements only for polymorphic associations
    }
  end
end