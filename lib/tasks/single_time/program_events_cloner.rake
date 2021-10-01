# Usage: bundle exec rake program_events_cloner:clone DOMAIN="chronus.com" SUBDOMAIN="walkthru" SOURCE_PROGRAM_ROOT="p1" TARGET_ROOTS="p2,p3"<optional> SOURCE_PROGRAM_EVENT_IDS='1,2' SKIP_ROOTS='p3'<ROOT> ADMIN_VIEW_TITLE='All Mentors' ADMIN_EMAIL=<admin_email>
namespace :program_events_cloner do
  desc "Clone Program events in Master Program to Other Tracks With Drafted status"
  task clone: :environment do
    Common::RakeModule::Utils.execute_task do
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'], ENV['SOURCE_PROGRAM_ROOT'])
      source_program = programs[0]

      target_programs = organization.programs.where.not(id: source_program.id).includes(:translations).select(:id, :root)
      target_programs = target_programs.where(root: ENV["TARGET_ROOTS"].split(",")) if ENV["TARGET_ROOTS"].present?
      target_programs = target_programs.where.not(root: ENV["SKIP_ROOTS"].split(",")) if ENV["SKIP_ROOTS"].present?
      source_program_event_ids = ENV["SOURCE_PROGRAM_EVENT_IDS"].split(",").map(&:to_i)
      source_program_events = source_program.program_events.where(id: source_program_event_ids).includes(:translations)
      if source_program_event_ids.size != source_program_events.size
        raise "Source program events with ids #{source_program_event_ids - source_program_events.collect(&:id)} not present"
      end

      admin_users_hash = organization.members.find_by(email: ENV["ADMIN_EMAIL"].presence || SUPERADMIN_EMAIL).users.select(:id, :program_id).index_by(&:program_id)
      admin_users_missed_programs = (target_programs.collect(&:id) - admin_users_hash.keys)
      raise "Admin users for #{SUPERADMIN_EMAIL} are not found in programs: #{admin_users_missed_programs.join(",")}" if admin_users_missed_programs.present?

      admin_views_hash = AdminView.where(title: ENV["ADMIN_VIEW_TITLE"], program_id: target_programs.collect(&:id)).select(:id, :program_id).index_by(&:program_id)
      admin_view_missed_programs = (target_programs.collect(&:id) - admin_views_hash.keys)
      raise "Admin View with #{ENV['ADMIN_VIEW_TITLE']} is not found in programs: #{admin_view_missed_programs.join(",")}" if admin_view_missed_programs.present?

      source_program_events.each do |source_program_event|
        target_programs.each do |target_program|
          clone_program_event = source_program_event.dup_with_translations
          clone_program_event.program_id = target_program.id
          clone_program_event.user_id = admin_users_hash[target_program.id].id
          clone_program_event.status = ProgramEvent::Status::DRAFT
          clone_program_event.admin_view_id = admin_views_hash[target_program.id].id
          clone_program_event.save!
        end
      end
    end
  end
end