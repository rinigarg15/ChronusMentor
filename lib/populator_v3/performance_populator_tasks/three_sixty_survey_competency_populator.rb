class ThreeSixtySurveyCompetencyPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    three_sixty_survey_ids = @program.three_sixty_surveys.pluck(:id)
    three_sixty_survey_competencies_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, three_sixty_survey_ids)
    process_patch(three_sixty_survey_ids, three_sixty_survey_competencies_hsh) 
  end

  def add_three_sixty_survey_competencies(three_sixty_survey_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Survey Competency" do
      program = options[:program]
      three_sixty_competency_ids = program.organization.three_sixty_competencies.pluck(:id)
      temp_three_sixty_competency_ids = three_sixty_competency_ids.dup
      three_sixty_survey_ids.each do |three_sixty_survey_id|
        iterator = ThreeSixty::SurveyCompetency.where(:three_sixty_survey_id => three_sixty_survey_id).pluck(:position).max.to_i + 1
        ThreeSixty::SurveyCompetency.populate(count) do |survey_competency|
          temp_three_sixty_competency_ids = three_sixty_survey_ids.dup if temp_three_sixty_competency_ids.blank?        
          survey_competency.three_sixty_survey_id = three_sixty_survey_id
          survey_competency.three_sixty_competency_id = temp_three_sixty_competency_ids.shift
          survey_competency.position = iterator
          iterator += 1 
          self.dot
        end
      end
      self.class.display_populated_count(three_sixty_survey_ids.size * count, "Three Sixty Survey Competency")
    end
  end

  def remove_three_sixty_survey_competencies(three_sixty_survey_ids, count, options = {})
    self.class.benchmark_wrapper "Removing three_sixty_survey_competencies................" do
      three_sixty_survey_competency_ids = ThreeSixty::SurveyCompetency.where(:three_sixty_survey_id => three_sixty_survey_ids).select([:id, :three_sixty_survey_id]).group_by(&:three_sixty_survey_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::SurveyCompetency.where(:id => three_sixty_survey_competency_ids).destroy_all
      self.class.display_deleted_count(three_sixty_survey_ids.size * count, "Three Sixty Survey Competency")
    end
  end
end