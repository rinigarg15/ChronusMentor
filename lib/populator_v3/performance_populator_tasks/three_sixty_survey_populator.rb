class ThreeSixtySurveyPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    program_ids = @organization.programs.pluck(:id)
    three_sixty_surveys_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, three_sixty_surveys_hsh) 
  end

  def add_three_sixty_surveys(program_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Surveys" do
      temp_program_ids = program_ids * count
      organization = options[:organization]
      ThreeSixty::Survey.populate(program_ids.size * count) do |survey|
        title = Populator.words(3..6)
        description = Populator.sentences(2..4)

        survey.organization_id = organization.id
        survey.program_id = temp_program_ids.shift
        survey.title = DataPopulator.append_locale_to_string(title, I18n.default_locale)
        survey.description = DataPopulator.append_locale_to_string(description, I18n.default_locale)
        survey.state = [ThreeSixty::Survey::PUBLISHED, ThreeSixty::Survey::DRAFTED, ThreeSixty::Survey::PUBLISHED, ThreeSixty::Survey::PUBLISHED, ThreeSixty::Survey::PUBLISHED].sample
        survey.created_at = rand(100).days.ago
        survey.expiry_date = (Time.now + rand(100).days).to_date
        survey.reviewers_addition_type = 0

        self.dot
      end
      self.class.display_populated_count(program_ids.size * count, "Three Sixty Survey")
    end
  end

  def remove_three_sixty_surveys(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing three_sixty_surveys................" do
      survey_ids = ThreeSixty::Survey.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::Survey.where(:id => survey_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Three Sixty Survey")
    end
  end
end