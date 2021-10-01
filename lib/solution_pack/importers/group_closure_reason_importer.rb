class GroupClosureReasonImporter < SolutionPack::Importer

  NoImportAttributes = ["updated_at", "created_at"]
  CustomAttributes = ["program_id"]

  AssociatedModel = "GroupClosureReason"
  FileName = 'group_closure_reason'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end
end