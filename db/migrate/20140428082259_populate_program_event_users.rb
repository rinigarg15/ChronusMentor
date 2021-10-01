class PopulateProgramEventUsers< ActiveRecord::Migration[4.2]
  def up
    ActionMailer::Base.perform_deliveries = false
    Program.active.each do |program|
      Program.transaction do
        if program.program_events.any?
          puts "Program: #{program.id}"
          all_user_view = program.admin_views.where(:default_view => AbstractView::DefaultType::ALL_USERS).first
          mentor_view = program.admin_views.where(:default_view => AbstractView::DefaultType::MENTORS).first
          mentee_view = program.admin_views.where(:default_view => AbstractView::DefaultType::MENTEES).first
          program.program_events.each do |program_event|
            admin_view = case program_event.role_names
              when [RoleConstants::MENTOR_NAME] then mentor_view
              when [RoleConstants::STUDENT_NAME] then mentee_view
              else all_user_view
            end
            program_event.update_column(:admin_view_id, admin_view.id)
            program_event.update_column(:admin_view_title, admin_view.title)
            program_event.set_users_from_admin_view!
          end
        end
      end
    end    
  end
end
