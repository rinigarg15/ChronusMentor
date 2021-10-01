class RoleQuestionImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["role_id", "profile_question_id"]

  AssociatedModel = "RoleQuestion"
  FileName = 'role_question'
  AssociatedImporters = ["RoleQuestionPrivacySettingImporter","MatchConfigImporter"]
  CareerDevAssociatedImporters = ["RoleQuestionPrivacySettingImporter"]

  def initialize(parent_importer)
    self.file_name = FileName
    self.parent_importer = parent_importer
    self.solution_pack = parent_importer.solution_pack
    self.solution_pack.id_mappings[self.class::AssociatedModel] = {}
  end

  def process_role_id(role_id, obj)
    obj.role_id = self.solution_pack.id_mappings["Role"][role_id.to_i]
  end

  def process_profile_question_id(profile_question_id, obj)
    obj.profile_question_id = self.solution_pack.id_mappings["ProfileQuestion"][profile_question_id.to_i]
  end

  def handle_object_creation(obj, old_id, column_names, row)
    role_question = self.solution_pack.program.role_questions.where(role_id: obj.role_id, profile_question_id: obj.profile_question_id).first
    if role_question.present?
      role_question.required = obj.required
      role_question.private = obj.private
      role_question.filterable = obj.filterable
      role_question.in_summary = obj.in_summary
      role_question.available_for = obj.available_for
      role_question.admin_only_editable = obj.admin_only_editable
      role_question.privacy_settings.destroy_all
      obj = role_question
    end
    obj.save!
    obj
  end

end