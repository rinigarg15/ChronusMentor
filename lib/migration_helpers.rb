module MigrationHelpers
  def add_translation_column(model, field, sql_field_type)
    translation_model = model.translation_class
    unless translation_model.column_names.include?(field.to_s)
      ChronusMigrate.ddl_migration do
        Lhm.change_table model.translations_table_name do |t|
          t.add_column field, sql_field_type
        end
      end
      ChronusMigrate.data_migration do
        translation_model.reset_column_information
        model.unscoped.find_each do |record|
          translation = record.translation_for(I18n.default_locale) || record.translations.build(locale: I18n.default_locale)
          translation[field] = record.read_attribute(field, { translated: false } )
          translation.save!
        end
      end
    end
  end

  def add_translation_values_for_non_default_locale(locale, record, field, content)
    translation = record.translation_for(locale) || record.translations.build(locale: locale)
    translation[field] = content
    translation.save!
  end
end