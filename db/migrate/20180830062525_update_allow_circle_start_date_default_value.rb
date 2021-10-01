class UpdateAllowCircleStartDateDefaultValue < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      change_column_default :programs, :allow_circle_start_date, true
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      change_column_default :programs, :allow_circle_start_date, false
    end
  end
end
