class ProgramEventPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["program_event_enabled?"]
    program_ids = @organization.programs.pluck(:id)
    program_events_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, program_events_hsh)
  end

  def add_program_events(program_ids, count, options = {})
    self.class.benchmark_wrapper "Program Events" do
      randomizer = [*1..100]
      programs = Program.where(id: program_ids).to_a
      temp_programs = programs * count
      ProgramEvent.populate(program_ids.size * count, :per_query => 10_000) do |program_event|
        program = temp_programs.shift
        admin_user = program.admin_users.first
        start_time = program.created_at
        admin_view_ids = program.admin_views.pluck(:id)
        event_start_time = (start_time + randomizer.sample.days).beginning_of_day + 8.hours
        title = Populator.words(10..16)
        description = Populator.sentences(4..8)
        program_event.status = [ProgramEvent::Status::PUBLISHED, ProgramEvent::Status::PUBLISHED, ProgramEvent::Status::DRAFT].sample
        program_event.start_time = event_start_time
        program_event.end_time = event_start_time + 2.hours
        program_event.user_id = admin_user.id
        program_event.email_notification = false
        program_event.location = Populator.words(6..9),
        program_event.admin_view_id = admin_view_ids.sample
        program_event.program_id = program.id
        locales = @translation_locales.dup
        ProgramEvent::Translation.populate @translation_locales.count do |translation|
          translation.program_event_id = program_event.id
          translation.title = DataPopulator.append_locale_to_string(title, locales.last)
          translation.description = DataPopulator.append_locale_to_string(description, locales.last)
          translation.locale = locales.pop
        end
        self.dot
      end
      ProgramEvent.last(program_ids.size * count).each{|program_event|
        program_event.set_users_from_admin_view!
        Delayed::Job.enqueue ProgramEventCreateJob.new(program_event.id)
      }
      self.class.display_populated_count(program_ids.size * count, "Program Events")
    end
  end

  def remove_program_events(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Program Events................" do
      program_event_ids = ProgramEvent.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ProgramEvent.where(:id => program_event_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Program Events")
    end
  end
end