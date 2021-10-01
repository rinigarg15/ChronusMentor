module GlobalizeActiveRecordAdapterOverrides
  def save_translations!
    # If the record is an end user created record, then create/update translation for the default locale instead of current locale
    if self.record.respond_to?(:custom_entry?) && self.record.custom_entry?
      attrs = self.stash[::Globalize.locale]
      self.stash.clear
      self.stash[I18n.default_locale] = attrs
    elsif self.record.respond_to?(:parent_template) && self.record.parent_template.present?
      locales = self.record.parent_template.translations.pluck(:locale).map(&:to_sym)
      sliced_stash = self.stash.slice(*locales)
      self.stash.clear
      self.stash = sliced_stash
    end
    super
  end

  # Translation object for I18n.default_locale should always exist
  def write(locale, name, value)
    super(locale, name, value)
    if locale != I18n.default_locale && fetch(I18n.default_locale, name).nil?
      super(I18n.default_locale, name, value)
    end
  end
end

# https://github.com/globalize/globalize#fallback-locales-to-each-other
Globalize.module_eval do
  def self.fallbacks(for_locale = self.locale)
    if for_locale != I18n.default_locale
      self.fallbacks = { for_locale => [for_locale, I18n.default_locale] }
    end

    read_fallbacks[for_locale] || default_fallbacks(for_locale)
  end
end

module Globalize::ActiveRecord
  Adapter.prepend(GlobalizeActiveRecordAdapterOverrides)

  Migration::Migrator.class_eval do
    # The following methods ensure that only the translated attributes in model are provisioned with columns in translation table.
    # This might cause error in migrations that added columns to the translation table, when we remove the corresponding attribute(s) from translates list.
    # So, we have nullified the methods.
    def complete_translated_fields
      return
    end

    def validate_translated_fields
      return
    end

    def create_translation_table
      connection.create_table(translations_table_name) do |t|
        t.references table_name.sub(/^#{table_name_prefix}/, '').singularize, null: false, index: false, type: column_type(model.primary_key).to_sym
        t.string :locale, null: false, limit: UTF8MB4_VARCHAR_LIMIT
        t.timestamps null: false
      end
    end
  end

  AdapterDirty.module_eval do
    def _reset_attribute(name)
      record.clear_attribute_changes([name])
    end
  end

  InstanceMethods.module_eval do
    def dup_with_translations
      duplicate = self.dup
      duplicate.translations = self.translations.map(&:dup)
      duplicate
    end

    def translation
      self.is_custom_entry? ? translation_for(I18n.default_locale) : translation_for(::Globalize.locale)
    end

    def save(*)
      locale = self.is_custom_entry? ? ::Globalize.locale : (self.translation.locale || I18n.default_locale)
      result = Globalize.with_locale(locale) do
        without_fallbacks do
          super
        end
      end
      globalize.clear_dirty if result
      result
    end

    def is_custom_entry?
      self.respond_to?(:custom_entry?) && self.custom_entry?
    end

    def saved_changes
      super.merge(self.translation.saved_changes.slice(*self.translated_attribute_names))
    end

    def attribute_before_last_save(attr_name)
      return super unless attr_name.in?(self.translated_attribute_names.map(&:to_s))
      self.translation.attribute_before_last_save(attr_name)
    end
  end

  ClassMethods.module_eval do
    def translation_class
      @translation_class ||= begin
        if self.const_defined?(:Translation, false)
          klass = self.const_get(:Translation, false)
        elsif self.base_class.const_defined?(:Translation, false)
          klass = self.base_class.const_get(:Translation, false)
        else
          klass = self.const_set(:Translation, Class.new(Globalize::ActiveRecord::Translation))
        end

        klass.belongs_to :globalized_model,
          class_name: self.name,
          foreign_key: translation_options[:foreign_key],
          inverse_of: :translations,
          touch: translation_options.fetch(:touch, false)
        klass
      end
    end
  end
end