module SalesDemo
  class AdminViewPopulator < BasePopulator
    REQUIRED_FIELDS = AdminView.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :favourited_at]

    def initialize(master_populator)
      super(master_populator, :admin_views)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        admin_view = AdminView.new.tap do |admin_view|
          assign_data(admin_view, ref_object)
          admin_view.program_id = master_populator.referer_hash[:organization][ref_object.program_id]
          process_filter_params(admin_view)
          admin_view
        end
        admin_view.save_without_timestamping!
        referer[ref_object.id] = admin_view.id
      end
      master_populator.referer_hash[:admin_view] = referer
    end

    def process_filter_params(admin_view)
      filter_params_hash = admin_view.filter_params_hash
      if filter_params_hash["profile"].present? && filter_params_hash["profile"]["questions"].present?
        questions = filter_params_hash["profile"]["questions"]
        questions.each do |key, val|
          val["question"] = master_populator.solution_pack_referer_hash["ProfileQuestion"][val["question"].to_i].to_s
          val["choice"] = get_new_question_choice_ids(val["choice"].split(",")) if val["choice"].present?
        end
        filter_params_hash["profile"]["questions"] = questions
        admin_view.filter_params = AdminView.convert_to_yaml(filter_params_hash)
      end
    end

    def get_new_question_choice_ids(old_choice_ids)
      old_choice_ids.collect do |old_qc_id|
        master_populator.solution_pack_referer_hash["QuestionChoice"][old_qc_id.to_i]
      end.compact.join(",")
    end
  end
end