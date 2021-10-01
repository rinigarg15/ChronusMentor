class ThreeSixtySurveyReviewerGroupPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    three_sixty_survey_ids = @program.three_sixty_surveys.pluck(:id)
    three_sixty_survey_reviewer_groups_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, three_sixty_survey_ids)
    process_patch(three_sixty_survey_ids, three_sixty_survey_reviewer_groups_hsh) 
  end

  def add_three_sixty_survey_reviewer_groups(three_sixty_survey_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Survey ReviewerGroup" do
      program = options[:program]
      three_sixty_reviewer_group_ids = program.organization.three_sixty_reviewer_groups.pluck(:id)
      ThreeSixty::Survey.where(id: three_sixty_survey_ids).each do |survey|
        three_sixty_reviewer_group_ids = three_sixty_reviewer_group_ids - survey.reviewer_groups.pluck(:id)
        next if three_sixty_reviewer_group_ids.blank?
        ThreeSixty::SurveyReviewerGroup.populate count do |survey_reviewer_group|
          survey_reviewer_group.three_sixty_survey_id = survey.id
          survey_reviewer_group.three_sixty_reviewer_group_id = three_sixty_reviewer_group_ids.first
          three_sixty_reviewer_group_ids = three_sixty_reviewer_group_ids.rotate
          self.dot
        end
      end
      self.class.display_populated_count(three_sixty_survey_ids.size * count, "Three Sixty Survey ReviewerGroup")
    end
  end

  def remove_three_sixty_survey_reviewer_groups(three_sixty_survey_ids, count, options = {})
    self.class.benchmark_wrapper "Removing three_sixty_survey_reviewer_groups................" do
      three_sixty_survey_reviewer_group_ids = ThreeSixty::SurveyReviewerGroup.where(:three_sixty_survey_id => three_sixty_survey_ids).select([:id, :three_sixty_survey_id]).group_by(&:three_sixty_survey_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::SurveyReviewerGroup.where(:id => three_sixty_survey_reviewer_group_ids).destroy_all
      self.class.display_deleted_count(three_sixty_survey_ids.size * count, "Three Sixty Survey ReviewerGroup")
    end
  end
end