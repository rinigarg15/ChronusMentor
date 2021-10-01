class CopyAnnouncementsForEy< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization("chronus.com", "eycollegemap", "p1")
        template_program = programs[0]
        template_announcements = template_program.announcements.drafted.includes(:recipient_roles)
        organization_admin = organization.members.admins.find_by(email: "garrett.jensen@ey.com")
        program_id_admin_map = organization_admin.users.index_by(&:program_id)

        programs = organization.programs.where.not(id: template_program.id).includes(:announcements)
        copy_announcements(programs, template_announcements, program_id_admin_map)
      end
    end
  end

  def down
  end

  private

  def copy_announcements(programs, template_announcements, program_id_admin_map)
    template_announcements_with_attachments = template_announcements.select { |template_announcement| template_announcement.attachment.exists? }
    programs.each do |program|
      if program.announcements.any?(&:drafted?)
        puts "Drafted announcements already present in #{program.url}!"
      else
        admin_id = program_id_admin_map[program.id].id
        ActiveRecord::Base.transaction do
          template_announcements.each do |template_announcement|
            copy_announcement(program, template_announcement, admin_id, template_announcement.in?(template_announcements_with_attachments))
          end
        end
      end
    end
  end

  def copy_announcement(program, template_announcement, admin_id, copy_attachment)
    announcement = program.announcements.new
    announcement.title = template_announcement.title
    announcement.body = template_announcement.body
    announcement.status = Announcement::Status::DRAFTED
    announcement.user_id = admin_id
    announcement.recipient_role_names = template_announcement.recipient_roles.map(&:name)
    announcement.expiration_date = template_announcement.expiration_date
    announcement.attachment = AttachmentUtils.get_remote_data(template_announcement.attachment) if copy_attachment
    announcement.save!
  end
end