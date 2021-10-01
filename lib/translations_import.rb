module TranslationsImport
  include LocalizableContent

  NokogiriObj_ERROR = -1

  def read_and_save_translations_csv(current_organization, prog_or_org, csv_file_path)
    data = CSV.read(csv_file_path)
    valid_data, errors = get_valid_data(data)
    data = [data.first] + valid_data
    if data.count > 1
      header = data.first
      data = data[1..-1].reverse
      data = Hash[data.map {|en_element, locale_element| [en_element, locale_element]}]
      lang = Language.find_by(title: header[1])
      return {lang_error: true}, nil if lang.nil?
      second_locale = lang.language_name.to_sym
      set_translations(prog_or_org, data, second_locale)
    end
    errors_hash = {}
    error1 = TranslationImport::ErrorOption::Interpolation_key_error
    error2 = TranslationImport::ErrorOption::HTML_tag_error
    errors_hash[error1] = errors[error1].uniq.join(", ") if errors[error1] != []
    errors_hash[error2] = errors[error2].uniq.join(", ") if errors[error2] != []
    return errors_hash, second_locale
  end

  def get_valid_data(data)
    errors = [[],[]]
    valid_data = []
    data[1..-1].each_with_index do |data_arr, index|
      valid, error_group = is_valid_translation?(data_arr.first, data_arr.second)
      if valid
        valid_data << data_arr
      else
        error_group.each do |error_category|
          errors[error_category] << index+2
        end
      end
    end
    return valid_data, errors
  end

  def is_valid_translation?(en_element, locale_element)
    return false, [] if en_element.nil? || en_element == "" || locale_element.nil? || locale_element == ""
    valid = true
    error_group = []
    if !Globalization::PhraseappUtils.validate_interpolation_tags_for_key(en_element, locale_element)
      valid = false
      error_group << TranslationImport::ErrorOption::Interpolation_key_error
    end
    html_tags_valid = Globalization::PhraseappUtils.validate_html_tags_for_key(en_element, locale_element)
    if html_tags_valid == NokogiriObj_ERROR
      valid = false
      error_group << TranslationImport::ErrorOption::HTML_tag_error
    end
    return valid, error_group
  end

  def set_translations(prog_or_org, data, locale)
    set_prog_or_org_translations(prog_or_org, data, locale)
    if prog_or_org.standalone?
      set_prog_or_org_translations(prog_or_org.programs.first, data, locale) || []
    elsif prog_or_org.is_a?(Organization)
      prog_or_org.programs.each do |prog|
        set_prog_or_org_translations(prog, data, locale) || []
      end
    end
  end

  def set_prog_or_org_translations(prog_or_org, data, locale)
    categories = LocalizableContent.send(prog_or_org.is_a?(Organization) ? :org_level : :program_level)
    categories.each do |category|
      if can_show_category?(category, prog_or_org)
        set_category_translations(category, prog_or_org, data, locale) || []
      end
    end
  end

  def set_category_translations(category, current_object, data, second_locale)
    if category == LocalizableContent::PROGRAM_SETTINGS
      set_program_settings_translations(current_object, second_locale, data)
    else
      tree = LocalizableContent.relations[category]
      set_category_tree_translations(tree, [current_object.id], data, second_locale, current_object.class)
    end
  end

  def set_category_tree_translations(tree, obj_ids, data, locale, obj_class)
    if !obj_ids.empty?
      current_node, lower_tree = tree.is_a?(Hash) ? tree.first : tree
      klass, foreign_key_column_name = klass_with_parent_foreign_key[current_node]
      if tree != LocalizableContent.relations[LocalizableContent::USER_PROFILE]
        ids = get_object_ids_for_node(klass, obj_ids, foreign_key_column_name, obj_class) 
      else
        ids = Section.where(program_id: obj_ids).pluck(:id)
      end
      if !ids.empty?
        set_klass_translations(klass, ids, data, locale)
        lower_tree.each {|lower_relation| set_category_tree_translations(lower_relation, ids, data, locale, klass)} if lower_tree
      end
    end
  end

  def set_klass_translations(klass, ids, data, locale)
    foreign_key_in_translatable_class = klass.reflect_on_all_associations.detect{|k| k.name == :translations}.options[:foreign_key]
    translation_klass_parent = klass
    until translation_klass_parent.superclass == ActiveRecord::Base do
      translation_klass_parent = translation_klass_parent.superclass
    end
    translation_klass = "#{translation_klass_parent.to_s}::Translation".constantize
    attributes = LocalizableContent.attributes_for_model[klass]

    set_klass_translations_by_columns(translation_klass, attributes, ids, foreign_key_in_translatable_class, locale, data)
  end

  def set_klass_translations_by_columns(translation_klass, translation_columns, ids, foreign_key_in_translatable_class, locale, data)
    return if data == {}
    columns = [foreign_key_in_translatable_class] + translation_columns
    en_translated_ids_and_attr = translation_klass.where(foreign_key_in_translatable_class => ids, locale: 'en').pluck(*columns)
    return if en_translated_ids_and_attr == []
    
    en_hash = Hash[en_translated_ids_and_attr.map {|x| [x[0], x]}]
    en_translated_ids = en_hash.keys()
    
    columns2 = [:id]+columns
    other_locale_ids_and_attr = translation_klass.where(foreign_key_in_translatable_class => en_translated_ids, locale: locale).pluck(*columns2)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|x| [x[1], x]}]
    new_locale_array = []
    update_array = []
    en_hash.each do |key, _value|
      modify = false
      locale_data = [key, locale]
      translation_columns.each_with_index do |_column, index|
        if data[en_hash[key][index+1]].present?
          data_value = data[en_hash[key][index+1]]
          locale_data << data_value
          modify = true if other_locale_hash[key].nil? || data_value != other_locale_hash[key][index+2]
        else
          if !other_locale_hash[key].nil?
            locale_data << other_locale_hash[key][index+2]
          else
            locale_data << nil
          end
        end
      end
      index_s = translation_columns.count+1
      if modify
        if other_locale_hash[key].nil?
          new_locale_array << locale_data
        else
          update_array << [other_locale_hash[key].first] + locale_data
        end
      end
    end
    columns = [foreign_key_in_translatable_class, :locale] + translation_columns
    translation_klass.import columns, new_locale_array, validate: true
    translation_klass.import [:id]+columns, update_array, validate: true, on_duplicate_key_update: translation_columns
  end

  def set_program_settings_translations(current_object, locale, data)
    current_object.translation_settings_sub_categories.each do |sub_category|
      items = get_translatable_objects_program_settings(sub_category[:id], current_object)
      items.each do |item|
        set_program_settings_objects_translations(item, locale, current_object.standalone?, LocalizableContent::PROGRAM_SETTINGS, sub_category[:id], data)
      end
    end
  end

  def set_program_settings_objects_translations(item, locale, standalone_case, category, tab, data)
    if can_item_be_edited?(item)
      attributes_by_model = LocalizableContent.attributes_for_model(category: category, tab: tab)
      attributes = (attributes_by_model[item.class] - (LocalizableContent.attribute_for_heading[item.class] || []))
      attributes = attributes_by_model[AbstractProgram] + attributes if item.is_a?(Organization)
      locale_object = item.translations.select{|t| t.locale == locale.to_sym}.first || {}
      en_object = item.translations.select{|t| t.locale == :en}.first || {}
      modify = false
      if en_object != {}
        translation_klass = en_object.class
        modify, insert_locale_array, insert_locale_columns = get_insert_locale_array(item, attributes, en_object, locale_object, data, locale)
      end
      if modify
        translation_klass.import insert_locale_columns, [insert_locale_array], validate: true, on_duplicate_key_update: attributes
      end
      if standalone_case && category == LocalizableContent::PROGRAM_SETTINGS && tab.present? && tab == ProgramsController::SettingsTabs::GENERAL && item.is_a?(Program)
        en_object = item.organization.translations.select{|t| t.locale == :en}.first || {}
        return if en_object == {}
        translation_klass = en_object.class
        locale_object = item.organization.translations.select{|t| t.locale == locale.to_sym}.first || {}
        modify, insert_locale_array, insert_locale_columns = get_insert_locale_array(item.organization, attributes_by_model[Organization], en_object, locale_object, data, locale)
        if modify
          translation_klass.import insert_locale_columns, [insert_locale_array], validate: true, on_duplicate_key_update: attributes
        end
      end
    end
  end

  def get_insert_locale_array(item, attributes, en_object, locale_object, data, locale)
    foreign_key_in_translatable_class = item.class.reflect_on_all_associations.detect{|k| k.name == :translations}.options[:foreign_key]
    insert_locale_columns = [foreign_key_in_translatable_class, :locale] + attributes
    insert_locale_columns = [:id] + insert_locale_columns if locale_object != {}
    insert_locale_array = [item[:id], locale]
    insert_locale_array = [locale_object[:id]] + insert_locale_array if locale_object != {}
    modify = false
    attributes.each do |attribute|
      locale_element = locale_object[attribute]
      if en_object[attribute].present?
        en_element = en_object[attribute]
        if data[en_element].present?
          insert_locale_array << data[en_element]
          modify = true if data[en_element] != locale_element
        else
          insert_locale_array << locale_element
        end
      else
        insert_locale_array << locale_object[attribute]
      end
    end
    return modify, insert_locale_array, insert_locale_columns
  end
end