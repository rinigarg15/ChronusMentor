class ThreeSixtyQuestionPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    organization_ids = [@organization.id]
    three_sixty_questions_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, organization_ids)
    process_patch(organization_ids, three_sixty_questions_hsh)
  end

  def add_three_sixty_questions(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Questions" do
      organizations = Organization.where(id: organization_ids)
      question_type = [ThreeSixty::Question::Type::RATING, ThreeSixty::Question::Type::TEXT]
      organizations.each do |org|
        temp_competency_ids = org.three_sixty_competencies.pluck(:id) * count
        ThreeSixty::Question.populate count do |question|
          title = Populator.words(3..6)
          question.organization_id = org.id
          question.question_type = question_type.sample
          question.three_sixty_competency_id = temp_competency_ids.shift
          question.three_sixty_competency_id = [nil, question.three_sixty_competency_id].sample if question.question_type == ThreeSixty::Question::Type::TEXT

          locales = @translation_locales.dup
          ThreeSixty::Question::Translation.populate @translation_locales.count do |three_sixty_question_translation|
            three_sixty_question_translation.title = DataPopulator.append_locale_to_string(title, locales.last)
            three_sixty_question_translation.three_sixty_question_id = question.id
            three_sixty_question_translation.locale = locales.pop
          end
          self.dot
        end
      end
      self.class.display_populated_count(organization_ids.size * count, "Three Sixty Question")
    end
  end

  def remove_three_sixty_questions(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Three Sixty Question................" do
      question_ids = ThreeSixty::Question.where(:organization_id => organization_ids).select([:id, :organization_id]).group_by(&:organization_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::Question.where(:id => question_ids).destroy_all
      self.class.display_deleted_count(organization_ids.size * count, "Three Sixty Question")
    end
  end
end