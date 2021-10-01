class AdminViewColumnExporter < SolutionPack::Exporter

  FileName = 'admin_view_column'
  AssociatedModel = "AdminViewColumn"

  def initialize(program, parent_exporter)
    if parent_exporter.class == AdminViewExporter
      invalid_profile_question_ids = AdminViewColumn.where(admin_view_id: parent_exporter.objs.collect(&:id)).pluck(:profile_question_id).compact.uniq - program.role_questions.includes(:profile_question).pluck(:profile_question_id).uniq
      invalid_admin_view_column_ids = AdminViewColumn.where(profile_question_id: invalid_profile_question_ids).collect(&:id)
      self.objs = AdminViewColumn.where(admin_view_id: parent_exporter.objs.collect(&:id)).where.not(id: invalid_admin_view_column_ids)
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end