module PaperTrail
  class VersionAssociation < ActiveRecord::Base
    # we have a check to not add version association in paper trail version class when associations is disabled, but the belongs to association doesn't have any check in version association class. Adding this to ensure no issue is caused because of it.
    self.abstract_class = true
  end

  # Overriding the method to handle translated attributes
  RecordTrail.class_eval do
    def attributes_before_change
      klass = @record.class
      column_names_and_translated_attribute_names = klass.column_names
      column_names_and_translated_attribute_names += klass.translated_attribute_names.map(&:to_s) if klass.translates?

      Hash[@record.attributes.map do |k, v|
        if column_names_and_translated_attribute_names.include?(k)
          [k, attribute_in_previous_version(k)]
        else
          [k, v]
        end
      end]
    end
  end
end