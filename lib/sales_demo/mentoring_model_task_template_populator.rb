module SalesDemo
  class MentoringModelTaskTemplatePopulator
    include PopulatorUtils

    attr_accessor :master_populator, :reference
    def initialize(master_populator)
      self.master_populator = master_populator
      self.reference = convert_to_objects(master_populator.parse_file(:mentoring_model_task_templates))
    end

    def copy_data
      referer = {}
      # Group by title and description
      grouped_hash = self.reference.group_by{|r| [r.mentoring_model_id, r.title.strip]}
      grouped_hash.each do |key, values|
        intial_query = MentoringModel::TaskTemplate.where(mentoring_model_id: self.master_populator.solution_pack_referer_hash["MentoringModel"][key[0]])
        database_records = MentoringModel::TaskTemplate::Translation.
          where(mentoring_model_task_template_id: intial_query.pluck(:id)).
          where(locale: I18n.default_locale).
          where("BINARY title = ?", *key[1..-1]).
          pluck(:mentoring_model_task_template_id)
        raise Exception.new("Mismatch in count") if database_records.count != values.count
        values.each_with_index do |element, index|
          referer[element.id] = database_records[index]
        end
      end
      master_populator.referer_hash[:mentoring_model_task_template] = referer
    end
  end
end