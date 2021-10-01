class MentoringModelPopulator < PopulatorTask

  def patch(options = {})
    return if @options[:common]["flash_type"]
    program_ids = @organization.programs.select(&:engagement_enabled?).collect(&:id)
    mentoring_models_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, mentoring_models_hsh)
  end

   def add_mentoring_models(program_ids, count, options = {})
    self.class.benchmark_wrapper "Mentoring Model" do
      temp_program_ids = program_ids * count
      MentoringModel.populate (count * program_ids.count) do |mentoring_model|
        title = Populator.words(4..6)
        description = Populator.sentences(2..4)
        mentoring_model.default = false
        mentoring_model.program_id = temp_program_ids.shift
        mentoring_model.mentoring_period = rand(4..12).months.to_i
        mentoring_model.created_at = Time.now
        mentoring_model.version = 1000
        mentoring_model.mentoring_model_type = "base"
        mentoring_model.goal_progress_type = 0
        mentoring_model.should_sync = true
        mentoring_model.allow_messaging = true
        mentoring_model.allow_forum = false
        allow_due_date_edit = [true, false].sample

        locales = @translation_locales.dup
        MentoringModel::Translation.populate @translation_locales.count do |mentoring_model_translation|
          mentoring_model_translation.title = DataPopulator.append_locale_to_string(title, locales.last)
          mentoring_model_translation.description = DataPopulator.append_locale_to_string(description, locales.last)
          mentoring_model_translation.mentoring_model_id = mentoring_model.id
          mentoring_model_translation.locale = locales.pop
        end
        self.dot
      end
      self.class.display_populated_count(program_ids.size * count, "Mentoring Models")
    end
  end

  def remove_mentoring_models(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Mentoring Model................" do
      mentoring_model_ids = MentoringModel.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      MentoringModel.where(:id => mentoring_model_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Mentoring Models")
    end
  end
end