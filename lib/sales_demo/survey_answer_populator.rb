module SalesDemo
  class SurveyAnswerPopulator < BasePopulator
    # Not populating feedback response for now.
    # TODO while doing feedbacks
    REQUIRED_FIELDS = SurveyAnswer.attribute_names.map(&:to_sym) - [:id, :feedback_response_id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :meeting_occurrence_time, :attachment_updated_at]
    ASSOCIATED_MODELS = {
      :answer_choices => "SalesDemo::AnswerChoicePopulator"
    }

    attr_accessor :associated_model_reference

    def initialize(master_populator)
      super(master_populator, :survey_answers)
      self.associated_model_reference = group_associated_models
    end

    def copy_data
      referer = {}
      survey_collection = []
      self.reference.each do |ref_object|
        sa = SurveyAnswer.new.tap do |survey_answer|
          assign_data(survey_answer, ref_object)
          survey_answer.common_question_id = master_populator.solution_pack_referer_hash["SurveyQuestion"][ref_object.common_question_id]
          survey_answer.task_id = master_populator.referer_hash[:mentoring_model_task][ref_object.task_id]
          survey_answer.survey_id = master_populator.solution_pack_referer_hash["Survey"][ref_object.survey_id]
          survey_answer.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          survey_answer.user_id = master_populator.referer_hash[:user][ref_object.user_id]
          survey_answer.member_meeting_id = master_populator.referer_hash[:member_meeting][ref_object.member_meeting_id]
        end
        SurveyAnswer.import([sa], validate: false, timestamps: false)
        survey_answer = SurveyAnswer.last
        survey_collection << survey_answer.survey_id
        SurveyQuestion.update_counters(survey_answer.common_question_id, :common_answers_count => 1)
        copy_associated_models(survey_answer, ref_object.id)
        SolutionPack::AttachmentExportImportUtils.handle_attachment_import(SalesPopulator::ATTACHMENT_FOLDER + "survey_answers/", survey_answer, :attachment, survey_answer.attachment_file_name, ref_object.id)
        referer[ref_object.id] = SurveyAnswer.last.id
      end
      Survey.where(:id => survey_collection).each(&:update_total_responses!)
      # update survey responses
      master_populator.referer_hash[:survey_answer] = referer
    end

    def group_associated_models
      return ASSOCIATED_MODELS.keys.inject({}) do |associated_model_reference, key|
        associated_model_reference[key] = filter_and_convert_to_objects(master_populator.parse_file(key), "ref_obj_type", CommonAnswer.name).group_by(&:ref_obj_id)
        associated_model_reference
      end
    end

    def copy_associated_models(survey_answer, ref_object_id)
      ASSOCIATED_MODELS.each do |key, value|
        value.constantize.new(survey_answer, associated_model_reference[key][ref_object_id] || [], master_populator).copy_data
      end
    end
  end
end