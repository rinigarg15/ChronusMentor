module SalesDemo
  class PageTranslationPopulator < BasePopulator
    REQUIRED_FIELDS = Page::Translation.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :page_translations)
    end

    def copy_data
      organization = Organization.find(master_populator.referer_hash[:organization].first[1])
      self.reference.each do |ref_object|
        pt = Page::Translation.new.tap do |page_translation|
          assign_data(page_translation, ref_object)
          page_translation.content = self.master_populator.handle_ck_editor_import(ref_object.content)
          page_translation.page_id = master_populator.referer_hash[:page][ref_object.page_id]
        end
        Page::Translation.import([pt], validate: false, timestamps: false)
      end
    end
  end
end