class MentoringModelTemplatesImporter < SolutionPack::Importer

  NoImportAttributes = []
  CustomAttributes = []

  AssociatedModel = "MentoringModel"
  FolderName = 'mentoring_model/'
  FileName = 'mentoring_model_'

  def initialize(parent_importer)
    self.file_name = FileName
    self.parent_importer = parent_importer
    self.solution_pack = parent_importer.solution_pack
  end

  def import
    if Dir.exists?(solution_pack.base_path+FolderName)
      program = solution_pack.program
      Dir.foreach(solution_pack.base_path+FolderName) do |file_name|
        next if (file_name == '.' || file_name == '..')
        old_id = file_name.delete(FileName).to_i
        mentoring_model = program.mentoring_models.find(solution_pack.id_mappings[MentoringModelImporter::AssociatedModel][old_id])
        mentoring_model.object_role_permissions.destroy_all
        csv_content = File.read(solution_pack.base_path+FolderName+file_name)
        importer = MentoringModel::Importer.new(mentoring_model, csv_content)
        if(importer.import(true).successful?)
          import_ck_editor_columns(mentoring_model)
          handle_facilitation_template_messages(mentoring_model)
          update_task_template_action_item_ids(mentoring_model)
          mentoring_model.save!
          process_id(old_id, mentoring_model)
        end
      end
    end
  end

  def import_ck_editor_columns(mentoring_model)
    mentoring_model.mentoring_model_milestone_templates.each do |milestone_template|
      updated_description = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(solution_pack.program, solution_pack, milestone_template.description, solution_pack.ck_editor_column_names, solution_pack.ck_editor_rows)
      milestone_template.description = updated_description
      milestone_template.save!
    end
    mentoring_model.mentoring_model_goal_templates.each do |goal_template|
      updated_description = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(solution_pack.program, solution_pack, goal_template.description, solution_pack.ck_editor_column_names, solution_pack.ck_editor_rows)
      goal_template.description = updated_description
      goal_template.save!
    end
    mentoring_model.mentoring_model_task_templates.each do |task_template|
      updated_description = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(solution_pack.program, solution_pack, task_template.description, solution_pack.ck_editor_column_names, solution_pack.ck_editor_rows)
      task_template.description = updated_description
      task_template.skip_survey_validations = true
      task_template.save!
    end
    mentoring_model.mentoring_model_facilitation_templates.each do |facilitation_template|
      updated_message = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(solution_pack.program, solution_pack, facilitation_template.message, solution_pack.ck_editor_column_names, solution_pack.ck_editor_rows)
      facilitation_template.message = updated_message
      facilitation_template.skip_survey_validations = true
      facilitation_template.save!
    end
  end

  def handle_facilitation_template_messages(mentoring_model)
    mentoring_model.mentoring_model_facilitation_templates.each do |facilitation_template|
      updated_message = facilitation_template.message
      engagement_survey_links = facilitation_template.message.scan(/\{\{engagement_survey_link_\d+\}\}/)
      engagement_survey_ids = engagement_survey_links.map{|link| link.scan(/\d+/).first.to_i}
      engagement_survey_ids.each do |engagement_survey_id|
        updated_survey_id = self.solution_pack.id_mappings[SurveyImporter::AssociatedModel][engagement_survey_id]
        updated_message = updated_message.gsub(/\{\{engagement_survey_link_#{engagement_survey_id}}\}/, "{{engagement_survey_link_#{updated_survey_id}}}") if updated_survey_id
      end
      facilitation_template.message = updated_message
      facilitation_template.skip_survey_validations = false
      unless facilitation_template.valid?
        handle_error_case(facilitation_template)
        facilitation_template.destroy
      else      
        facilitation_template.save!
      end
    end
  end

  def update_task_template_action_item_ids(mentoring_model)
    mentoring_model.mentoring_model_task_templates.each do |task_template|
      if(task_template.action_item_type == MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
        old_survey_id = task_template.action_item_id
        task_template.skip_survey_validations = false
        task_template.action_item_id = self.solution_pack.id_mappings[SurveyImporter::AssociatedModel][old_survey_id] || nil
        unless task_template.action_item_id
          handle_error_case(task_template)
          task_template.destroy
        else
          task_template.save!
        end
      end
    end
  end

  def handle_error_case(obj)
    err = ActiveModel::Errors.new(self.solution_pack)
    err.add(:base, "Full Error Message #{obj.errors.full_messages.join(", ")}")
    self.solution_pack.custom_errors << SolutionPack::Error.new(SolutionPack::Error::TYPE::MentoringModel, err)
  end
end