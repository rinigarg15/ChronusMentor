class RoleReferenceSurveyExporter < SolutionPack::Exporter
  
  AssociatedExporters = []
  FileName = "role_reference"
  AssociatedModel = "RoleReference"

  def initialize(program, parent_exporter)
    if (parent_exporter.class == SurveyExporter)
      self.objs = RoleReference.joins(:role).where(roles: { program_id: program.id }).select{|rr| rr.ref_obj_type == "Survey"}
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName + '_' + parent_exporter.class::FileName
    self.solution_pack = parent_exporter.solution_pack
  end
end