class TranslationUniquenessValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    scopes = options[:scope].is_a?(Array) ? options[:scope] : [options[:scope]]
    klass = record.class
    translation_table_name = klass.reflect_on_all_associations(:has_many).find{|a| a.plural_name == "translations"}.table_name
    query = klass
    scopes.each do |scope|
      query = query.where(scope => record.send(scope))
    end
    query = query.where(klass.arel_table[:id].not_eq(record.id)).joins(:translations).where(translation_table_name.to_sym => {locale: I18n.locale})
    if value.present?
      query = (options[:case_sensitive] == false) ? query.where("lower(#{translation_table_name}.#{attribute}) = ?", value.mb_chars.downcase.to_s) : query.where("#{translation_table_name}.#{attribute} = ?", value.to_s)
    end
    count = query.count
    if count > 0 && value.present?
      record.errors.add attribute, options[:message] || "feature.language.validator.unique_error".translate(attribute: attribute)
    end
  end
end