class ResourcePopulator < PopulatorTask

  def patch(options = {})
    program_ids = @organization.programs.pluck(:id)
    resources_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, resources_hsh)
  end

  def add_resources(program_ids, count, options = {})
    self.class.benchmark_wrapper "Resources" do
      programs = Program.where(id: program_ids)
      program_role_hash = {}
      programs.each do |program|
        program_role_hash[program.id] = program.roles.non_administrative.collect(&:id)
      end
      programs.each do |program|
        Resource.populate(count) do |resource|
          program_id = program.id
          title = Populator.words(3..5)
          content = Populator.paragraphs(2..5)

          resource.program_id = program_id
          resource.created_at = program.created_at
          resource.updated_at = program.created_at..Time.now
          resource.default = [false, true].sample

          locales = @translation_locales.dup
          Resource::Translation.populate @translation_locales.count do |resource_translation|
            resource_translation.title = DataPopulator.append_locale_to_string(title, locales.last)
            resource_translation.content = DataPopulator.append_locale_to_string(content, locales.last)
            resource_translation.resource_id = resource.id
            resource_translation.locale = locales.pop
          end
          ResourcePublication.populate 1 do |resource_publication|
            resource_publication.resource_id = resource.id
            resource_publication.program_id = program_id
            temp_role_ids = program_role_hash[program_id]
            RoleResource.populate 1..2 do |role_resource|
              role_resource.role_id = temp_role_ids.sample
              role_resource.resource_publication_id = resource_publication.id
            end
          end
          self.dot
        end
      end
      self.class.display_populated_count(program_ids.size * count, "Resources")
    end
  end

  def remove_resources(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Resources................" do
      resource_ids = Resource.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Resource.where(:id => resource_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Resources")
    end
  end
end