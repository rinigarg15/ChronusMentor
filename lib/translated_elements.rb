module TranslatedElements
  include LocalizableContent

  def generate_translations_csv(current_organization, level_obj, second_locale)
    second_lang = Language.find_by(language_name: second_locale)
    csv_headers = ["feature.translations.label.english".translate, second_lang.title]
    export_attributes = get_attributes_to_export(level_obj, second_locale)
    return csv_headers, export_attributes
  end

  def get_attributes_to_export(prog_or_org, locale)
    total_elements = []
    total_elements += get_prog_or_org_elements(prog_or_org, locale) || []
    if prog_or_org.standalone?
      total_elements += get_prog_or_org_elements(prog_or_org.programs.first, locale) || []
    elsif prog_or_org.is_a?(Organization)
      prog_or_org.programs.each do |prog|
        total_elements += get_prog_or_org_elements(prog, locale) || []
      end
    end
    total_elements
  end

  def get_prog_or_org_elements(prog_or_org, locale)
    categories = LocalizableContent.send(prog_or_org.is_a?(Organization) ? :org_level : :program_level)
    category_elements = []
    categories.each do |category|
      if can_show_category?(category, prog_or_org)
        category_elements_hash_array = get_category_elements(category, prog_or_org, locale) || []
        category_elements_hash_array.each do |attributes_hash|
            category_elements += attributes_hash
        end
      end
    end
    return category_elements
  end

  def get_category_elements(category, current_object, second_locale)
    if category == LocalizableContent::PROGRAM_SETTINGS
      return get_program_settings_elements(current_object, second_locale)
    else
      tree = LocalizableContent.relations[category]
      return get_category_tree_elements(tree, [current_object.id], second_locale, current_object.class)
    end
  end

  def get_category_tree_elements(tree, obj_ids, locale, obj_class)
    return [] if obj_ids.empty?
    current_node, lower_tree = tree.is_a?(Hash) ? tree.first : tree
    klass, foreign_key_column_name = klass_with_parent_foreign_key[current_node]
    if tree != LocalizableContent.relations[LocalizableContent::USER_PROFILE]
      ids = get_object_ids_for_node(klass, obj_ids, foreign_key_column_name, obj_class) 
    else
      ids = Section.where(program_id: obj_ids).pluck(:id)
    end
    return [] if ids.empty?
    total_elements = get_klass_elements(klass, ids, locale)
    lower_tree.each {|lower_relation| total_elements +=  get_category_tree_elements(lower_relation, ids, locale, klass)} if lower_tree
    return total_elements
  end

  def get_klass_elements(klass, ids, locale)
    foreign_key_in_translatable_class = klass.reflect_on_all_associations.detect{|k| k.name == :translations}.options[:foreign_key]
    translation_klass_parent = klass
    until translation_klass_parent.superclass == ActiveRecord::Base do
      translation_klass_parent = translation_klass_parent.superclass
    end
    translation_klass = "#{translation_klass_parent.to_s}::Translation".constantize
    attributes = LocalizableContent.attributes_for_model[klass]
    overall_table_elements = []
    attributes.each do |attribute|
      overall_table_elements += [ get_klass_elements_by_column(translation_klass, attribute, ids, foreign_key_in_translatable_class, locale)]
    end
    return overall_table_elements
  end

  def get_klass_elements_by_column(translation_klass, translation_column, ids, foreign_key_in_translatable_class, locale)
    en_translated_ids_and_attr = translation_klass.where(foreign_key_in_translatable_class => ids,locale: 'en').where.not(translation_column => nil).pluck(foreign_key_in_translatable_class, translation_column)
    return [] if en_translated_ids_and_attr == []
    en_hash = Hash[en_translated_ids_and_attr.map {|key, value| [key, value]}]
    en_translated_ids = en_hash.keys()
    other_locale_ids_and_attr = translation_klass.where(foreign_key_in_translatable_class => en_translated_ids, locale: locale).where.not(translation_column => nil).pluck(foreign_key_in_translatable_class, translation_column)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    
    keys = [en_hash, other_locale_hash].flat_map(&:keys).uniq
    total_elements = keys.map do |k| 
      [ en_hash[k] || "", other_locale_hash[k] || ""]
    end
    return total_elements
  end

  def get_program_settings_elements(prog_or_org, locale)
    total_elements = []
    prog_or_org.translation_settings_sub_categories.each do |sub_category|
      items = get_translatable_objects_program_settings(sub_category[:id], prog_or_org)
      items.each do |item|
        total_elements += get_translation_score_or_elements_for_object(item, locale, prog_or_org.standalone?, LocalizableContent::PROGRAM_SETTINGS, sub_category[:id], nil, false)
      end
    end
    return [total_elements]
  end

end