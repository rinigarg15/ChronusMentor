$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "chronus_docs/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "chronus_docs"
  s.version     = ChronusDocs::VERSION
  s.authors     = "souman mandal"
  s.email       = ["souman@chronus.com"]
  s.homepage    = ""
  s.summary     = "Summary of ChronusDocs."
  s.description = "Description of ChronusDocs."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]
end
