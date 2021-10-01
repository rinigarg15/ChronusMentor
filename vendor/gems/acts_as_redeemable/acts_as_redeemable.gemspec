$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "acts_as_redeemable/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "acts_as_redeemable"
  s.version     = ActsAsRedeemable::VERSION
  s.authors     = "ApolloDev"
  s.email       = "apollodev@chronus.com"
  s.homepage    = ""
  s.summary     = "Summary of ActsAsRedeemable."
  s.description = "Description of ActsAsRedeemable."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails"
  s.add_dependency "activerecord"

  s.add_development_dependency "sqlite3"
end
