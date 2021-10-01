class SurveyQuestionImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "common_answers_count", "feedback_form_id", "position"]
  CustomAttributes = ["program_id", "survey_id"]
  AssociatedImporters = ["QuestionChoiceImporter"]
  AssociatedModel = "SurveyQuestion"
  FileName = 'survey_question_survey'

  attr_accessor :obj_matrix_question_id_hash

  def initialize(parent_importer)
    self.obj_matrix_question_id_hash = {}
    super parent_importer
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def process_survey_id(survey_id, obj)
    obj.survey_id = self.solution_pack.id_mappings[self.parent_importer.class::AssociatedModel][survey_id.to_i]
  end

  def handle_object_creation(obj, old_id, column_names, row)
    old_matrix_question_id = obj.matrix_question_id
    obj.matrix_question_id = nil
    obj.skip_column_creation = old_matrix_question_id.present?
    obj.save(validate: false)
    self.obj_matrix_question_id_hash[obj] = old_matrix_question_id if old_matrix_question_id.present?
    obj
  end

  def postprocess_import
    populate_matrix_question_id
    validate_survey_questions
  end

  def populate_matrix_question_id
    self.obj_matrix_question_id_hash.each do |obj, old_matrix_question_id|
      obj.matrix_question_id = self.solution_pack.id_mappings[AssociatedModel][old_matrix_question_id]
      obj.save(validate: false)
    end
  end

  def validate_survey_questions
    self.solution_pack.id_mappings[AssociatedModel].each do |old_id, new_id|
      survey_question = SurveyQuestion.find(new_id)
      survey_question.save!
    end
  end
end