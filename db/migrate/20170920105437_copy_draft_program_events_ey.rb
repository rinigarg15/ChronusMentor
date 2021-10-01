class CopyDraftProgramEventsEy< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        Common::RakeModule::Utils.execute_task do
          programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization("chronus.com", "eycollegemap", "p1")
          source_program = programs[0]
          target_programs = organization.programs.where.not(id: source_program.id)
          source_program_events = source_program.program_events.drafted
          title_admin_views_map = AdminView.where(program_id: target_programs.map(&:id)).includes(:admin_view_columns).group_by(&:title)

          target_programs.each do |target_program|
            copy_program_events(target_program, source_program_events, title_admin_views_map)
          end
        end
      end
    end
  end

  def down
    # Do Nothing
  end

  private

  def copy_program_events(target_program, source_program_events, title_admin_views_map)
    source_program_events.each do |source_program_event|
      program_event = source_program_event.dup
      program_event.program_id = target_program.id
      program_event.user_id = source_program_event.user.member.get_and_cache_user_in_program(target_program).id
      program_event.admin_view = find_or_create_admin_view(target_program.id, source_program_event.admin_view, title_admin_views_map)
      program_event.save!
    end
  end

  def find_or_create_admin_view(target_program_id, source_admin_view, title_admin_views_map)
    target_admin_view = (title_admin_views_map[source_admin_view.title] || []).index_by(&:program_id)[target_program_id]
    if target_admin_view.blank?
      target_admin_view = source_admin_view.dup
      target_admin_view.program_id = target_program_id
      target_admin_view.save_admin_view_columns!(source_admin_view.admin_view_columns.map(&:column_key))
    end
    target_admin_view
  end
end