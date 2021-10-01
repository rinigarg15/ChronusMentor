class MatchConfigImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["mentor_question_id", "student_question_id", "program_id", "matching_details_for_display", "matching_details_for_matching"]

  AssociatedModel = "MatchConfig"
  FileName = 'match_config'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_mentor_question_id(mentor_question_id, obj)
    obj.mentor_question_id = self.solution_pack.id_mappings[RoleQuestionImporter::AssociatedModel][mentor_question_id.to_i]
  end

  def process_student_question_id(student_question_id, obj)
    obj.student_question_id = self.solution_pack.id_mappings[RoleQuestionImporter::AssociatedModel][student_question_id.to_i]
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def process_matching_details_for_display(matching_details_for_display, obj)
    obj.matching_details_for_display = (matching_details_for_display.nil? ? nil : (JSON.parse matching_details_for_display.gsub('=>', ':')))
  end

  def process_matching_details_for_matching(matching_details_for_matching, obj)
    obj.matching_details_for_matching = (matching_details_for_matching.nil? ? nil : (JSON.parse matching_details_for_matching.gsub('=>', ':')))
  end

  def handle_object_creation(obj, old_id, column_names, row)
    match_config = MatchConfig.where(program_id: obj.program_id, mentor_question_id: obj.mentor_question_id, student_question_id: obj.student_question_id)
    obj.save! if match_config.blank? && obj.mentor_question_id.present? && obj.student_question_id.present?
    obj
  end
end