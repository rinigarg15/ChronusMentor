class AdminViewImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["program_id", "filter_params", "favourited_at"]

  AssociatedImporters = ["AdminViewColumnImporter"]

  AssociatedModel = "AdminView"
  FileName = 'admin_view'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def process_favourited_at(favourited_at, obj)
    obj.favourited_at = Time.now if favourited_at.present?
  end

  def process_filter_params(filter_params, obj)
    obj.filter_params = filter_params
    filter_params_hash = obj.filter_params_hash
    if filter_params_hash["profile"].present? && filter_params_hash["profile"]["questions"].present?
      questions = filter_params_hash["profile"]["questions"]
      questions.each do |key, val|
        val["question"] = self.solution_pack.id_mappings["ProfileQuestion"][val["question"].to_i].to_s
        val["choice"] = get_new_question_choice_ids(val["choice"].split(",")) if val["choice"].present?
      end
      filter_params_hash["profile"]["questions"] = questions
    end

    if filter_params_hash["survey"].present? 
      filter_params_hash = process_survey_filter_params(filter_params_hash)
    end

    obj.filter_params = AdminView.convert_to_yaml(filter_params_hash)
  end

  def process_survey_filter_params(filter_params_hash)
    if filter_params_hash["survey"]["survey_questions"].present?
      filters = filter_params_hash["survey"]["survey_questions"]
      filters.each do |key, val|
        val["survey_id"] = self.solution_pack.id_mappings[SurveyImporter::AssociatedModel][val["survey_id"].to_i].to_s
        question_id = self.solution_pack.id_mappings[SurveyQuestionImporter::AssociatedModel][val["question"].split("answers").last.to_i].to_s
        val["question"] = "answers#{question_id}"
        val["choice"] = get_new_question_choice_ids(val["choice"].split(",")) if val["choice"].present?
      end
      filter_params_hash["survey"]["survey_questions"] = filters
    end

    filter_params_hash["survey"]["user"]["survey_id"] = self.solution_pack.id_mappings[SurveyImporter::AssociatedModel][filter_params_hash["survey"]["user"]["survey_id"].to_i].to_s if filter_params_hash["survey"]["user"].present?  

    return filter_params_hash
  end

  def handle_object_creation(obj, old_id, column_names, row)
    same_view = self.solution_pack.program.admin_views.where("title = ? OR default_view = ?", obj.title, obj.default_view).first
    if same_view.present?
      same_view.filter_params = obj.filter_params
      same_view.description = obj.description
      same_view.favourite = obj.favourite
      same_view.favourited_at = obj.favourited_at unless same_view.favourited_at.present?
      obj = same_view
    end
    obj.save!
    obj
  end

  def get_new_question_choice_ids(old_choice_ids)
    old_choice_ids.collect do |old_qc_id|
      self.solution_pack.id_mappings["QuestionChoice"][old_qc_id.to_i]
    end.compact.join(",")
  end
end