class MentoringModelImporter < SolutionPack::Importer

  NoImportAttributes = ["updated_at", "created_at"]
  CustomAttributes = ["program_id", "version", "mentoring_model_type"]

  AssociatedImporters = ["MentoringModelLinkImporter", "MentoringModelTemplatesImporter", "ObjectRolePermissionImporter"]

  AssociatedModel = "MentoringModel"
  FileName = 'mentoring_model'

  def initialize(parent_importer)
    super parent_importer
  end

  def preprocess_import
    self.solution_pack.program.mentoring_models.destroy_all
  end

  def handle_object_creation(obj, old_id, column_names, row)
    obj.prevent_default_setting = true
    obj.save!
    self.solution_pack.program.reload
    obj
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def process_version(version, obj)
    obj.version = 1
  end

  def process_mentoring_model_type(mentoring_model_type, obj)
    if mentoring_model_type == "hybrid"
      self.solution_pack.program.hybrid_templates_enabled = true
      self.solution_pack.program.save!
    end
    obj.mentoring_model_type = mentoring_model_type
  end
end