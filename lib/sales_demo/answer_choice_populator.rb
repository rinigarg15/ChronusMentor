module SalesDemo
  class AnswerChoicePopulator < BasePopulator
    include PopulatorUtils
    REQUIRED_FIELDS = AnswerChoice.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    attr_accessor :parent_object, :reference, :master_populator

    def initialize(parent_object, reference, master_populator)
      self.parent_object = parent_object
      self.reference = reference
      self.master_populator = master_populator
    end

    def copy_data
      parent_object.send("answer_choices=", self.reference.collect do |ref_object|
        AnswerChoice.new.tap do |answer_choice|
          assign_data(answer_choice, ref_object)
          answer_choice.question_choice_id = master_populator.solution_pack_referer_hash["QuestionChoice"][ref_object.question_choice_id]
          answer_choice.ref_obj = parent_object
          answer_choice
        end
      end)
    end
  end
end
