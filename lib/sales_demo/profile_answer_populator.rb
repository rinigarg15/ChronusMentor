module SalesDemo
  class ProfileAnswerPopulator < BasePopulator
    REQUIRED_FIELDS = ProfileAnswer.attribute_names.map(&:to_sym) - [:id, :location_id]
    MODIFIABLE_DATE_FIELDS = [:attachment_updated_at, :created_at, :updated_at]

    ASSOCIATED_MODELS = {
      :educations => "SalesDemo::EducationPopulator",
      :publications => "SalesDemo::PublicationPopulator",
      :experiences => "SalesDemo::ExperiencePopulator",
      :managers => "SalesDemo::ManagerPopulator",
      :answer_choices => "SalesDemo::AnswerChoicePopulator"
    }

    attr_accessor :associated_model_reference

    def initialize(master_populator)
      super(master_populator, :profile_answers)
      self.associated_model_reference = group_associated_models
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        profile_answer = ProfileAnswer.new.tap do |profile_answer|
          
          assign_data(profile_answer, ref_object)
          
          profile_answer.ref_obj_id = master_populator.referer_hash[:member][ref_object.ref_obj_id]
          profile_answer.profile_question_id = master_populator.solution_pack_referer_hash["ProfileQuestion"][ref_object.profile_question_id.to_i]
          if profile_answer.profile_question.question_type == 8
            location = Location.find_or_create_by_full_address(ref_object.answer_text)
            profile_answer.location = location
          end
          profile_answer.handle_date_answer(profile_answer.profile_question, ref_object.answer_text)
          profile_answer.skip_observer = true
          
          copy_associated_models(profile_answer, ref_object.id)
          # Attachment will be saved inside  handle_attachment_import
          SolutionPack::AttachmentExportImportUtils.handle_attachment_import(SalesPopulator::ATTACHMENT_FOLDER + "profile_answers/", profile_answer, :attachment, profile_answer.attachment_file_name, ref_object.id)
          profile_answer
        end
        # There might be invalid profile answers from the demo site
        next unless profile_answer.id
        referer[ref_object.id] = profile_answer.reload.id
      end
      self.master_populator.referer_hash[:profile_answers] = referer
    end

    def group_associated_models
      return ASSOCIATED_MODELS.keys.inject({}) do |associated_model_reference, key|
        if key == :answer_choices
          associated_model_reference[key] = filter_and_convert_to_objects(master_populator.parse_file(key), "ref_obj_type", ProfileAnswer.name).group_by(&:ref_obj_id)
        else
          associated_model_reference[key] = convert_to_objects(master_populator.parse_file(key)).group_by(&:profile_answer_id)
        end
        associated_model_reference
      end
    end

    def copy_associated_models(profile_answer, ref_object_id)
      ASSOCIATED_MODELS.each do |key, value|
        value.constantize.new(profile_answer, associated_model_reference[key][ref_object_id] || [], master_populator).copy_data
      end
    end
  end
end