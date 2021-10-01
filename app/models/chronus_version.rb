class ChronusVersion < PaperTrail::Version
  self.table_name = :chronus_versions

  module Events
    UPDATE = "update"
  end

  def modifications
    YAML.load(self.object_changes)
  end
end