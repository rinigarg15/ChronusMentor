module SalesDemo
  class PublicationPopulator
    include PopulatorUtils
    REQUIRED_FIELDS = Publication.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    attr_accessor :parent_object, :reference, :master_populator

    def initialize(parent_object, reference, master_populator)
      self.parent_object = parent_object
      self.reference = reference
      self.master_populator = master_populator
    end

    def copy_data
      parent_object.send("publications=", self.reference.collect do |ref_object|
        Publication.new.tap do |publication|
          assign_data(publication, ref_object)
          publication.profile_answer = parent_object
          publication
        end
      end)
    end
  end
end