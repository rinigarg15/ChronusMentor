module SalesDemo
  class ExperiencePopulator
    include PopulatorUtils
    REQUIRED_FIELDS = Experience.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    attr_accessor :parent_object, :reference, :master_populator

    def initialize(parent_object, reference, master_populator)
      self.parent_object = parent_object
      self.reference = reference
      self.master_populator = master_populator
    end

    def copy_data
      parent_object.send("experiences=", self.reference.collect do |ref_object|
        Experience.new.tap do |experience|
          assign_data(experience, ref_object)
          experience.profile_answer = parent_object
          experience
        end
      end)
    end
  end
end