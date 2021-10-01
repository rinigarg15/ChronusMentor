#TODO Removed after the migration
class DataMigrationHelper
  def self.org_prog_map
    @@map ||= Program.select("id, parent_id").group_by(&:parent_id)
  end
end
