class RoleQuestionPrivacySettingExporter < SolutionPack::Exporter

  FileName = 'role_question_privacy_setting'
  AssociatedModel = "RoleQuestionPrivacySetting"

  def initialize(program, parent_exporter)
    self.objs = program.role_questions.includes(:privacy_settings).collect(&:privacy_settings).flatten
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end