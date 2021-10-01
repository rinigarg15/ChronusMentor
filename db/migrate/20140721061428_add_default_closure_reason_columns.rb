class AddDefaultClosureReasonColumns< ActiveRecord::Migration[4.2]
  def up
    Program.includes(:groups).each do |program|
      begin
        tracked_keys = program.create_default_group_closure_columns!
        puts "*** Created default closure columns for #{program.name} ***"
        
        program_groups = program.groups
        program_groups.where("termination_mode = (?)", Group::TerminationMode::INACTIVITY)
        .update_all(closure_reason_id: tracked_keys[GroupClosureReason::DefaultClosureReason::Key::AUTO_TERMINATED].id)
        program_groups.where("termination_mode = (?)", Group::TerminationMode::EXPIRY)
        .update_all(closure_reason_id: tracked_keys[GroupClosureReason::DefaultClosureReason::Key::CONNECTION_ENDED].id)
        program_groups.where("termination_mode is NOT NULL AND termination_mode != (?) AND termination_mode != (?)", Group::TerminationMode::INACTIVITY, Group::TerminationMode::EXPIRY)
        .update_all(closure_reason_id: tracked_keys[GroupClosureReason::DefaultClosureReason::Key::OTHER].id)
        puts "*** Migrated Group closure reason columns for #{program.name} ***"

        program.update_attributes!(auto_terminate_reason_id: tracked_keys[GroupClosureReason::DefaultClosureReason::Key::AUTO_TERMINATED].id) if program.auto_terminate
      rescue => e
        say "Issue: Program name - #{program.name} #{e.message}"
      end
    end
  end

  def down
  end
end