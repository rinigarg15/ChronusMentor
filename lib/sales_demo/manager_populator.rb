module SalesDemo
  class ManagerPopulator
    include PopulatorUtils
    REQUIRED_FIELDS = Manager.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    attr_accessor :parent_object, :reference, :master_populator

    def initialize(parent_object, reference, master_populator)
      self.parent_object = parent_object
      self.reference = reference
      self.master_populator = master_populator
    end

    def copy_data
      return if reference.blank?
      parent_object.send("manager=", Manager.new.tap do |manager|
        assign_data(manager, reference.first)
        manager.profile_answer = parent_object
        manager
      end)
    end
  end
end

