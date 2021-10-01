class ForumPopulator < PopulatorTask
  def patch(options = {})
    program_ids = @organization.programs.pluck(:id)
    forum_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, forum_hsh) 
  end

  def add_forums(program_ids, forum_count, options = {})
    self.class.benchmark_wrapper "Forums" do
      programs = Program.where(id: program_ids)
      programs.each do |program|
        Forum.populate(forum_count) do |forum|
          roles = program.roles.non_administrative
          forum.program_id = program.id
          forum.name = Populator.words(8..12)
          forum.description = Populator.sentences(3..5)
          forum.topics_count = 0
          RoleReference.populate 1 do |role_reference|
            role_reference.role_id = roles.sample.id
            role_reference.ref_obj_type = Forum.to_s
            role_reference.ref_obj_id = forum.id
            self.dot
          end
        end
      end
      self.class.display_populated_count(program_ids.size * forum_count, "forum")
    end
  end

  def remove_forums(program_ids, count, options = {})
    program_ids = Program.where(id: program_ids)
    self.class.benchmark_wrapper "Removing Forums....." do
      forum_ids = Forum.where(:program_id => program_ids).select("forums.id, program_id").group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Forum.where(:id => forum_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "forum")
    end
  end
end