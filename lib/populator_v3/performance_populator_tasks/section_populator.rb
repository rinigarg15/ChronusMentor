class SectionPopulator < PopulatorTask
  def patch(options = {})
    organization_ids = [@organization.id]
    sections_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, organization_ids)
    process_patch(organization_ids, sections_hsh)
  end

  def add_sections(organization_ids, section_count, options = {})
    self.class.benchmark_wrapper "Sections" do
      organizations = Organization.find(organization_ids)
      organizations.each do |organization|
        max_position = organization.sections.maximum(:position).to_i
        Section.populate section_count do |section|
          title = Populator.words(3..6)
          description = Populator.sentences(2..5)

          section.program_id = organization.id
          section.position = (max_position += 1)
          section.default_field = false

          locales = @translation_locales.dup
          Section::Translation.populate @translation_locales.count do |section_translation|
            section_translation.section_id = section.id
            section_translation.title = DataPopulator.append_locale_to_string(title, locales.last)
            section_translation.description = DataPopulator.append_locale_to_string(description, locales.last)
            section_translation.locale = locales.pop
          end
          self.dot
        end
      end
      self.class.display_populated_count(organization_ids.size * section_count, "Section")
    end
  end

  def remove_sections(org_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Sections....." do
      section_ids = Section.where(:program_id => org_ids, :default_field => false).select("sections.id, program_id").group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Section.where(:id => section_ids).destroy_all
      self.class.display_deleted_count(org_ids.size * count, "Section")
    end
  end
end