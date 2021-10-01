class QuestionChoiceImporter < SolutionPack::Importer
  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["ref_obj_id", "ref_obj_type"]
  AssociatedModel = "QuestionChoice"
  FileName = 'question_choice'
  AssociatedImporters = []

  def initialize(parent_importer)
    super parent_importer
    self.file_name = FileName + '_' + parent_importer.class::FileName
  end

  def process_ref_obj_id(ref_obj_id, obj)
    obj.ref_obj_id = ref_obj_id
    populate_ref_obj(obj)
  end

  def process_ref_obj_type(ref_obj_type, obj)
    obj.ref_obj_type = ref_obj_type
    populate_ref_obj(obj)
  end

  def handle_object_creation(obj, _old_id, _column_names, _row)
    question_choice = QuestionChoice.find_by(text: obj.text, ref_obj_id: obj.ref_obj_id, ref_obj_type: obj.ref_obj_type)
    unless question_choice.present?
      obj.save!
    end
    return question_choice || obj
  end

  def populate_ref_obj(obj)
    return if obj.ref_obj_id.blank? || obj.ref_obj_type.blank?

    parent_importer_klass = self.parent_importer.class::AssociatedModel
    obj.ref_obj_id = self.solution_pack.id_mappings[parent_importer_klass][obj.ref_obj_id.to_i]
  end

  def postprocess_import
    return true unless self.parent_importer.is_a?(SurveyQuestionImporter)
    self.solution_pack.id_mappings[SurveyQuestionImporter::AssociatedModel].each do |_old_id, new_id|
      survey_question = SurveyQuestion.find(new_id)
      next if survey_question.positive_outcome_options.blank? && survey_question.positive_outcome_options_management_report.blank?
      survey_question.positive_outcome_options = get_updated_positive_outcome_options(survey_question)
      survey_question.positive_outcome_options_management_report = get_updated_positive_outcome_options(survey_question, true)
      survey_question.save!
    end
  end

  def get_updated_positive_outcome_options(survey_question, for_management_report = false)
    outcome_options = survey_question.positive_choices(for_management_report).reject(&:blank?).map(&:to_i)
    return if outcome_options.blank?
    outcome_options.collect{|old_qc_id| self.solution_pack.id_mappings["QuestionChoice"][old_qc_id]}.compact.join(",").presence
  end
end