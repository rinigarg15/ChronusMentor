module SalesDemo
  class EducationPopulator
    include PopulatorUtils
    REQUIRED_FIELDS = Education.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    attr_accessor :parent_object, :reference, :master_populator

    def initialize(parent_object, reference, master_populator)
      self.parent_object = parent_object
      self.reference = reference
      self.master_populator = master_populator
    end

    def copy_data
      parent_object.send("educations=", self.reference.collect do |ref_object|
        Education.new.tap do |education|
          assign_data(education, ref_object)
          education.profile_answer = parent_object
          education
        end
      end)
    end
  end
end

