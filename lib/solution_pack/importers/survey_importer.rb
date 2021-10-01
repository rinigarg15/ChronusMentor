class SurveyImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "total_responses"]
  CustomAttributes = ["program_id", "due_date"]
  AssociatedImporters = ["SurveyQuestionImporter"]
  AssociatedModel = "Survey"
  FileName = 'survey'

  def initialize(parent_importer)
    super parent_importer
    @progress_reports_enabled = self.solution_pack.program.share_progress_reports_enabled?
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def process_due_date(program_id, obj)
    obj.due_date = nil
  end

  def preprocess_import
    self.access_role_names_hash = fill_access_role_names_hash
  end

  def handle_object_creation(obj, old_id, column_names, row)
    if obj.type == "ProgramSurvey"
      name = obj.name
      attributes = obj.attributes
      attributes.delete("id")
      attributes.delete("type")
      obj = ProgramSurvey.new(attributes)
      obj.name = name
      obj.recipient_role_names = access_role_names_hash[old_id]
    elsif obj.type == EngagementSurvey.name
      obj.progress_report = false unless @progress_reports_enabled
    end
    obj.from_solution_pack = true
    obj.save!
    return obj
  end
end