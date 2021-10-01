module SalesDemo
  class PagePopulator < BasePopulator
    REQUIRED_FIELDS = Page.attribute_names.map(&:to_sym) - Page.translated_attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :pages)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        p = Page.new.tap do |page|
          assign_data(page, ref_object)
          page.content = self.master_populator.handle_ck_editor_import(ref_object.content)
          page.program_id = master_populator.referer_hash[:organization][ref_object.program_id]
        end
        Page.import([p], validate: false, timestamps: false)
        referer[ref_object.id] = Page.last.id
      end
      self.master_populator.referer_hash[:page] = referer
    end
  end
end