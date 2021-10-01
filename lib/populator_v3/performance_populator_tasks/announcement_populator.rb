class AnnouncementPopulator < PopulatorTask

  def patch(options = {})
    program_ids = @organization.programs.pluck(:id)
    annoucements_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, annoucements_hsh)
  end

  def add_announcements(program_ids, count, options = {})
    self.class.benchmark_wrapper "Announcements" do
      announcement_status = [Announcement::Status::PUBLISHED, Announcement::Status::PUBLISHED, Announcement::Status::PUBLISHED, Announcement::Status::PUBLISHED, Announcement::Status::DRAFTED]
      Program.where(id: program_ids).each do |program|
        role_ids = program.roles.non_administrative.pluck(:id)
        admin_user = program.admin_users.first
        Announcement.populate(count, :per_query => 10_000) do |announcement|
          title = Populator.words(10..16)
          body = Populator.sentences(4..8)
          announcement.user_id = admin_user.id
          announcement.status = announcement_status.sample
          announcement.program_id = program.id
          announcement.created_at = program.created_at + rand(1..10).days
          announcement.updated_at = announcement.created_at..Time.now
          announcement.email_notification = UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND
          announcement.expiration_date = Time.now + rand(1..200).days
          RoleReference.populate 1 do |role_reference|
            role_reference.ref_obj_id = announcement.id
            role_reference.ref_obj_type = Announcement.to_s
            role_reference.role_id = role_ids.sample
          end

          locales = @translation_locales.dup
          Announcement::Translation.populate @translation_locales.count do |translation|
            translation.announcement_id = announcement.id
            translation.title = DataPopulator.append_locale_to_string(title, locales.last)
            translation.body = DataPopulator.append_locale_to_string(body, locales.last)
            translation.locale = locales.pop
          end
          self.dot
        end
      end
      self.class.display_populated_count(program_ids.size * count, "Announcements")
    end
  end

  def remove_announcements(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing announcement................" do
      annoucement_ids = Announcement.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Announcement.where(:id => annoucement_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Announcements")
    end
  end
end