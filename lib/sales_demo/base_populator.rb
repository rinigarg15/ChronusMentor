module SalesDemo
  class BasePopulator
    include PopulatorUtils

    attr_accessor :reference, :master_populator

    def initialize(master_populator, filename)
      self.reference = convert_to_objects(master_populator.parse_file(filename))
      self.master_populator = master_populator
    end
  end
end