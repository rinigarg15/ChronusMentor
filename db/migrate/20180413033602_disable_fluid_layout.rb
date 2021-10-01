class DisableFluidLayout < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      change_column_default :programs, :fluid_layout, false
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      change_column_default :programs, :fluid_layout, true
    end
  end
end
