class ConditionalMatchChoiceImporter < SolutionPack::Importer
  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["profile_question_id", "question_choice_id"]

  AssociatedModel = "ConditionalMatchChoice"
  FileName = 'conditional_match_choice'
  AssociatedImporters = []

  def initialize(parent_importer)
    super parent_importer
  end

  def process_profile_question_id(profile_question_id, obj)
    obj.profile_question_id = self.solution_pack.id_mappings["ProfileQuestion"][profile_question_id.to_i]
  end

  def process_question_choice_id(question_choice_id, obj)
    obj.question_choice_id = self.solution_pack.id_mappings["QuestionChoice"][question_choice_id.to_i]
  end

  def handle_object_creation(obj, _old_id, _column_names, _row)
    conditional_choice = ConditionalMatchChoice.find_by(question_choice_id: obj.question_choice_id, profile_question_id: obj.profile_question_id)
    if conditional_choice.blank? && obj.profile_question.conditional_question_id.present?
      obj.save!
    end
    return conditional_choice || obj
  end

end