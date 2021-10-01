module SalesDemo
  class MentoringModelMilestoneTemplatePopulator < BasePopulator
    def initialize(master_populator)
      super master_populator, :mentoring_model_milestone_templates
    end

    def copy_data
      referer = {}
      # Group by title and description
      grouped_hash = self.reference.group_by{|r| [r.mentoring_model_id, r.title.strip, r.description.strip]}
      grouped_hash.each do |key, values|
        intial_query = MentoringModel::MilestoneTemplate.where(mentoring_model_id: self.master_populator.solution_pack_referer_hash["MentoringModel"][key[0]])
        database_records = MentoringModel::MilestoneTemplate::Translation.
          where(mentoring_model_milestone_template_id: intial_query.pluck(:id)).
          where(locale: I18n.default_locale).
          where("BINARY (title = ?) and description = ?", *key[1..-1]).
          pluck(:mentoring_model_milestone_template_id)
        raise Exception.new("Mismatch in count") if database_records.count != values.count
        values.each_with_index do |element, index|
          referer[element.id] = database_records[index]
        end
      end
      master_populator.referer_hash[:mentoring_model_milestone_template] = referer
    end
  end
end