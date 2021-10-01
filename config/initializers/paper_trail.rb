PaperTrail.config.track_associations = false

PaperTrail::Version.module_eval do
  self.abstract_class = true
end