module SalesDemo
  class ProgramPopulator < BasePopulator
    REQUIRED_FIELDS = Program.attribute_names.map(&:to_sym) - Program::ORGANIZATION_ATTRIBUTES - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :programs)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        program = Program.new
        assign_data(program, ref_object)
        program.parent_id = master_populator.referer_hash[:organization][ref_object.parent_id]
        program.mentoring_period = ref_object.mentoring_period.to_i
        program.creation_way = Program::CreationWay::SOLUTION_PACK
        program.created_for_sales_demo = true
        program.save_without_timestamping!
        program.reload
        referer[ref_object.id] = program.id
      end
      master_populator.referer_hash[:program] = referer
    end
  end
end