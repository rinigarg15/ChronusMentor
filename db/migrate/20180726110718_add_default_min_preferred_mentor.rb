class AddDefaultMinPreferredMentor < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      change_column_default :programs, :min_preferred_mentors, DEFAULT_MIN_PREFERRED_MENTORS
    end

    ChronusMigrate.data_migration(has_downtime: false) do
      Program.where.not(mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN).update_all(min_preferred_mentors: DEFAULT_MIN_PREFERRED_MENTORS)
    end
  end

  def down
    # Nothing
  end
end
