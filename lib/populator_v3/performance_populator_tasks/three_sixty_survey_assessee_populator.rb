class ThreeSixtySurveyAssesseePopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    member_ids = @program.users.active.pluck(:member_id)
    three_sixty_survey_assessees_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, member_ids)
    process_patch(member_ids, three_sixty_survey_assessees_hsh) 
  end

  def add_three_sixty_survey_assessees(member_ids, count, options = {})
    program = options[:program]
    three_sixty_survey_ids = program.three_sixty_surveys.pluck(:id)
    return if three_sixty_survey_ids.blank?
    self.class.benchmark_wrapper "Three Sixty Survey Assessees" do
      temp_member_ids = member_ids * count
      temp_three_sixty_survey_ids = three_sixty_survey_ids.dup
      ThreeSixty::SurveyAssessee.populate(member_ids.size * count, :per_query => 50_000) do |survey_assessee|
        temp_three_sixty_survey_ids = three_sixty_survey_ids.dup if temp_three_sixty_survey_ids.blank?
        temp_member_ids = member_ids.dup if temp_member_ids.blank?
        survey_assessee.three_sixty_survey_id = temp_three_sixty_survey_ids.shift
        survey_assessee.member_id = temp_member_ids.shift
        self.dot
      end
      self.class.display_populated_count(member_ids.size * count, "three Sixty Survey Assessees")
    end
  end

  def remove_three_sixty_survey_assessees(member_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Three Sixty Survey Assessee................" do
      survey_assessee_ids = ThreeSixty::SurveyAssessee.where(:member_id => member_ids).select([:id, :member_id]).group_by(&:member_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::SurveyAssessee.where(:id => survey_assessee_ids).destroy_all
      self.class.display_deleted_count(member_ids.size * count, "three Sixty Survey Assessees")
    end
  end
end