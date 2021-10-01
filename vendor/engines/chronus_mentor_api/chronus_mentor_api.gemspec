$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "chronus_mentor_api/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "chronus_mentor_api"
  s.version     = ChronusMentorApi::VERSION
  s.authors     = [""]
  s.email       = [""]
  s.homepage    = ""
  s.summary     = ""
  s.description = ""

  s.files = Dir["{app,config,lib}/**/*"]
  s.test_files = Dir["test/**/*"]

  # s.add_dependency "rails", "~> 3.2.2"
  # s.add_dependency "jquery-rails"

  # s.add_development_dependency "sqlite3"
end
