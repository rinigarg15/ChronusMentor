$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "chronus_translations/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "chronus_translations"
  s.version     = ChronusTranslations::VERSION
  s.authors     = ["Arun Kumar"]
  s.email       = ["arun@chronus.com"]
  s.homepage    = "http://chronus.com"
  s.summary     = "Handles incoming emails."
  s.description = "Globalization support as an engine."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 5.1.4"
  # s.add_dependency "jquery-rails"
end
