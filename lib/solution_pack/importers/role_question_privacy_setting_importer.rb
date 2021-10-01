class RoleQuestionPrivacySettingImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["role_question_id", "role_id"]

  AssociatedModel = "RoleQuestionPrivacySetting"
  FileName = 'role_question_privacy_setting'

  def initialize(parent_importer)
    self.file_name = FileName
    self.parent_importer = parent_importer
    self.solution_pack = parent_importer.solution_pack
    self.solution_pack.id_mappings[self.class::AssociatedModel] = {}
  end

  def process_role_id(role_id, obj)
    obj.role_id = self.solution_pack.id_mappings["Role"][role_id.to_i]
  end

  def process_role_question_id(role_question_id, obj)
    obj.role_question_id = self.solution_pack.id_mappings["RoleQuestion"][role_question_id.to_i]
  end

  def handle_object_creation(obj, old_id, column_names, row)
    role_question_privacy_setting = RoleQuestionPrivacySetting.where(role_question_id: obj.role_question_id, setting_type: obj.setting_type, role_id: obj.role_id).first
    if role_question_privacy_setting.present?
      obj = role_question_privacy_setting
    else
      obj.save!
    end
    obj
  end

end