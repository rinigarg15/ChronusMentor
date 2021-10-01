class SurveyPopulator < PopulatorTask
  def patch(options = {})
    program_ids = @organization.programs.pluck(:id)
    survey_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, survey_hsh)
  end

  def add_surveys(program_ids, survey_count, options = {})
    self.class.benchmark_wrapper "Surveys" do
      programs = Program.where(id: program_ids)
      programs.each do |program|
        survey_types = program.default_survey_types
        roles = program.roles.non_administrative.to_a
        role_ids = roles.collect(&:id)
        choice_based = [CommonQuestion::Type::MULTI_CHOICE , CommonQuestion::Type::SINGLE_CHOICE]
        other_question = CommonQuestion::Type.all - [CommonQuestion::Type::FILE] - choice_based
        Survey.populate survey_count do |survey|
          name = Populator.words(4..8)

          survey.program_id = program.id
          survey.total_responses = 0
          survey.type = survey_types.sample
          survey.created_at = program.created_at
          survey.updated_at = program.created_at..Time.now

          locales = @translation_locales.dup
          Survey::Translation.populate @translation_locales.count do |survey_translation|
            survey_translation.name = DataPopulator.append_locale_to_string(name, locales.last)
            survey_translation.survey_id = survey.id
            survey_translation.locale = locales.pop
          end
          create_role_reference(Survey, survey.id, role_ids, roles.count)
          self.dot
        end
      end
      self.class.display_populated_count(program_ids.size * survey_count, "Surveys")
    end
  end

  def remove_surveys(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Surveys....." do
      survey_ids = Survey.where(:program_id => program_ids).select("surveys.id, program_id").group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Survey.where(:id => survey_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Surveys")
    end
  end

  def create_role_reference(klass, klass_id, role_ids, role_count = 1)
    raise "Role ids and role_count mismatch" if role_ids.size < role_count
    temp_role_ids = role_ids.dup
    RoleReference.populate role_count do |role_reference|
      role_reference.ref_obj_id = klass_id
      role_reference.ref_obj_type = klass.to_s
      role_reference.role_id = (role_count == 1 ? temp_role_ids.sample : temp_role_ids.shift)
    end
  end
end