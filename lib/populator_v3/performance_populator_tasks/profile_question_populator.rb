class ProfileQuestionPopulator < PopulatorTask
  def patch(options = {})
    organization_ids = [@organization.id]
    profile_question_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, organization_ids)
    process_patch(organization_ids, profile_question_hsh)
  end

  def add_profile_questions(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Profile questions" do
      organizations = Organization.where(:id => organization_ids).includes([:sections, :profile_questions])
      allowed_question_types = ProfileQuestion::Type.all - [ProfileQuestion::Type::NAME, ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::SKYPE_ID, ProfileQuestion::Type::RATING_SCALE, ProfileQuestion::Type::LOCATION, ProfileQuestion::Type::MANAGER, ProfileQuestion::Type::DATE]
      temp_question_types = allowed_question_types.dup
      organizations.each do |organization|
        temp_section_ids = organization.sections.pluck(:id) * count
        max_position = organization.profile_questions.maximum(:position).to_i
        ProfileQuestion.populate count do |pq|
          temp_question_types = allowed_question_types.dup  if temp_question_types.size.zero?
          question_text = Populator.words(4)
          help_text = Populator.words(3..5)

          pq.question_type = temp_question_types.shift
          pq.organization_id = organization.id
          pq.section_id = temp_section_ids.shift
          random_options_number = 3..10
          if pq.question_type == ProfileQuestion::Type::ORDERED_OPTIONS
            pq.options_count = [*3..5].sample
            random_options_number = pq.options_count + 5
          end
          pq.position = (max_position += 1)

          locales = @translation_locales.dup
          ProfileQuestion::Translation.populate @translation_locales.count do |translation|
            translation.profile_question_id = pq.id
            translation.question_text = DataPopulator.append_locale_to_string(question_text, locales.last)
            translation.help_text = DataPopulator.append_locale_to_string(help_text, locales.last)
            translation.locale = locales.pop
          end
          populate_question_choices(pq, ProfileQuestion.name, @translation_locales)
          self.dot
        end
      end
      self.class.display_populated_count(organization_ids.size * count, "Profile Question")
    end
  end

  def remove_profile_questions(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Profile questions....." do
      profile_question_ids = ProfileQuestion.where(:organization_id => organization_ids).select("profile_questions.id, organization_id").group_by(&:organization_id).map{|a| a[1].first(count)}.flatten.collect(&:id)
      ProfileQuestion.where(:id => profile_question_ids).destroy_all
      self.class.display_deleted_count(organization_ids.size * count, "Profile Question")
    end
  end
end