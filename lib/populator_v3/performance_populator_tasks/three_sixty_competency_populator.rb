class ThreeSixtyCompetencyPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    organization_ids = [@organization.id]
    three_sixty_competencies_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, organization_ids)
    process_patch(organization_ids, three_sixty_competencies_hsh)
  end

  def add_three_sixty_competencies(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Competencies" do
      temp_organization_ids = organization_ids * count
      ThreeSixty::Competency.populate(organization_ids.size * count) do |competency|
        title = Populator.words(6..10)
        description = Populator.sentences(2..4)

        competency.organization_id = temp_organization_ids.shift

        locales = @translation_locales.dup
        ThreeSixty::Competency::Translation.populate @translation_locales.count do |three_sixty_competency_translation|
          three_sixty_competency_translation.three_sixty_competency_id = competency.id
          three_sixty_competency_translation.title = DataPopulator.append_locale_to_string(title, locales.last)
          three_sixty_competency_translation.description = DataPopulator.append_locale_to_string(description, locales.last)
          three_sixty_competency_translation.locale = locales.pop
        end
        self.dot
      end
      self.class.display_populated_count(organization_ids.size * count, "Three Sixty Competencies")
    end
  end

  def remove_three_sixty_competencies(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Three Sixty Competency................" do
      competency_ids = ThreeSixty::Competency.where(:organization_id => organization_ids).select([:id, :organization_id]).group_by(&:organization_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::Competency.where(:id => competency_ids).destroy_all
      self.class.display_deleted_count(organization_ids.size * count, "Three Sixty Competencies")
    end
  end
end