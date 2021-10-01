class MentoringModelTemplatesExporter < SolutionPack::Exporter

  FolderName = 'mentoring_model/'
  FileName = 'mentoring_model_'
  AssociatedModel = "MentoringModel"

  def initialize(program, parent_exporter)
    self.objs = program.mentoring_models
    self.program = program
    self.parent_exporter = parent_exporter
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

  def export
    CSV.open(solution_pack.base_path+FileName+".csv", "wb")
    SolutionPack.create_if_not_exist_with_permission(solution_pack.base_path+FolderName, 0777)

    self.objs.each do |mentoring_model|
      unless mentoring_model.hybrid?
        MentoringModel::Exporter.new.export(mentoring_model, solution_pack.base_path+FolderName+FileName+mentoring_model.id.to_s)
        export_ck_editor_columns(mentoring_model) if self.solution_pack.is_sales_demo
      end
    end
  end

  def export_ck_editor_columns(mentoring_model)
    mentoring_model.mentoring_model_milestone_templates.each do |milestone_template|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, milestone_template.description, self.solution_pack)
    end
    mentoring_model.mentoring_model_goal_templates.each do |goal_template|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, goal_template.description, self.solution_pack)
    end
    mentoring_model.mentoring_model_task_templates.each do |task_template|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, task_template.description, self.solution_pack)
    end
    mentoring_model.mentoring_model_facilitation_templates.each do |facilitation_template|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, facilitation_template.message, self.solution_pack)
    end
  end

end