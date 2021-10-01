module STIAttributeRestriction
  extend ActiveSupport::Concern

  included do
    private

    def ensure_restricted_sti_attribute_not_changed
      self.class.get_restricted_sti_attributes.each do |attribute|
        if self.send("#{attribute}_changed?")
          self.errors.add(attribute, "errors.messages.invalid".translate)
        end
      end
    end
  end

  class_methods do
    attr_accessor :restricted_sti_attributes

    def restrict_sti_attributes(attributes)
      self.restricted_sti_attributes = attributes.map(&:to_s)
      validate :ensure_restricted_sti_attribute_not_changed
    end

    def get_restricted_sti_attributes
      all_restricted_sti_attributes = []
      klass = self
      until klass.superclass == ActiveRecord::Base
        all_restricted_sti_attributes += Array(klass.restricted_sti_attributes)
        klass = klass.superclass
      end
      all_restricted_sti_attributes
    end
  end
end