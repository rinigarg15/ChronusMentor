class ProfileQuestionImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["section_id", "organization_id", "profile_answers_count"]

  AssociatedModel = "ProfileQuestion"
  FileName = 'profile_question'
  AssociatedImporters = ["RoleQuestionImporter", "QuestionChoiceImporter", "ConditionalMatchChoiceImporter"]

  def initialize(parent_importer)
    @imported_profile_question_ids = {}
    super parent_importer
  end

  def process_organization_id(organization_id, obj)
    obj.organization_id = self.solution_pack.program.organization.id
  end

  def process_section_id(section_id, obj)
    obj.section_id = self.solution_pack.id_mappings[self.parent_importer.class::AssociatedModel][section_id.to_i]
  end

  def set_position(obj)
    section = obj.section
    if section.default_field?
      if obj.question_type == ProfileQuestion::Type::NAME
        obj.position = 1
      elsif obj.question_type == ProfileQuestion::Type::EMAIL
        #act_as_list automatically updates positions
        obj.position = section.profile_questions.where(question_type: ProfileQuestion::Type::NAME).present? ? 2 : 1
      else
        obj.position = (section.profile_questions.collect(&:position).push(0).max) + 1
      end
    else
      obj.position = section.profile_questions.collect(&:position).push(0).max + 1
      end
  end

  def process_profile_answers_count(profile_answers_count, obj)
    obj.profile_answers_count = 0
  end

  def handle_object_creation(obj, old_id, column_names, row)
    same_question = self.solution_pack.program.organization.profile_questions_with_email_and_name.where(question_text: obj.question_text, question_type: obj.question_type).first
    if same_question.present? && !from_same_solution_pack(same_question)
      obj = same_question
    else
      loc_question = self.solution_pack.program.organization.profile_questions_with_email_and_name.location_questions.first
      manager_question = self.solution_pack.program.organization.profile_questions_with_email_and_name.manager_questions.first
      set_position(obj)
      if obj.location? && loc_question.present?
        obj = loc_question
      elsif obj.manager?
        if manager_question.present?
          obj = manager_question
        else
          self.solution_pack.program.organization.enable_feature(FeatureName::MANAGER)
          obj.save!
        end
      else
        obj.save!
      end
      @imported_profile_question_ids[obj.id] = true
    end
    obj
  end

  def postprocess_import
    handle_conditional_profile_questions
  end

  def handle_conditional_profile_questions
    self.solution_pack.id_mappings[AssociatedModel].each do |key, value|
      new_conditional_profile_question_id = nil
      if value.present?
        new_profile_question = self.solution_pack.program.organization.profile_questions_with_email_and_name.find(value)
        if new_profile_question.conditional_question_id.present?
          new_conditional_profile_question_id = self.solution_pack.id_mappings[AssociatedModel][new_profile_question.conditional_question_id]
        end
        if new_conditional_profile_question_id.present?
          new_profile_question.conditional_question_id = new_conditional_profile_question_id
          new_profile_question.save!
        else
          new_profile_question.conditional_question_id = nil
          new_profile_question.save!
        end
      end
    end
  end

  def from_same_solution_pack(profile_question)
    @imported_profile_question_ids[profile_question.id].present?
  end
end