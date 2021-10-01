class ThreeSixtySurveyReviewerPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    @program.three_sixty_surveys.includes(:survey_assessees).each do |three_sixty_survey|
      @options[:three_sixty_survey] = three_sixty_survey
      three_sixty_survey_assessee_ids = three_sixty_survey.survey_assessees.pluck(:id)
      three_sixty_survey_reviewers_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, three_sixty_survey_assessee_ids)
      process_patch(three_sixty_survey_assessee_ids, three_sixty_survey_reviewers_hsh) 
    end
  end

  def add_three_sixty_survey_reviewers(three_sixty_survey_assessee_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Survey reviewers" do
      temp_three_sixty_survey_assessee_ids = three_sixty_survey_assessee_ids * count
      three_sixty_survey_reviewer_group_ids = options[:three_sixty_survey].survey_reviewer_groups.pluck(:id)
      temp_three_sixty_survey_reviewer_group_ids = three_sixty_survey_reviewer_group_ids.dup 
      ThreeSixty::SurveyReviewer.populate(three_sixty_survey_assessee_ids.size * count, :per_query => 10_000) do |survey_reviewer|
        temp_three_sixty_survey_reviewer_group_ids = three_sixty_survey_reviewer_group_ids.dup if temp_three_sixty_survey_reviewer_group_ids.blank?
        survey_reviewer.three_sixty_survey_assessee_id = temp_three_sixty_survey_assessee_ids.shift
        survey_reviewer.three_sixty_survey_reviewer_group_id = temp_three_sixty_survey_reviewer_group_ids.shift
        survey_reviewer.name = Faker::Name.name
        survey_reviewer.email = "reviewer_#{self.class.random_string}+minimal@chronus.com"
        survey_reviewer.invitation_code = Populator.words(2..6)
        survey_reviewer.invite_sent = [true, false].sample
        self.dot
      end
      self.class.display_populated_count(three_sixty_survey_assessee_ids.size * count, "Three Sixty Survey reviewers")
    end
  end

  def remove_three_sixty_survey_reviewers(three_sixty_survey_assessee_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Three Sixty Survey Reviewer................" do
      survey_reviewer_ids = ThreeSixty::SurveyReviewer.where(:three_sixty_survey_assessee_id => three_sixty_survey_assessee_ids).select([:id, :three_sixty_survey_assessee_id]).group_by(&:three_sixty_survey_assessee_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::SurveyReviewer.where(:id => survey_reviewer_ids).destroy_all
      self.class.display_deleted_count(three_sixty_survey_assessee_ids.size * count, "Three Sixty Survey ReviewerGroup")
    end
  end
end