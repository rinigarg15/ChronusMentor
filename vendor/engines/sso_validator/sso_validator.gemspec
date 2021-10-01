$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "sso_validator/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "sso_validator"
  s.version     = SsoValidator::VERSION
  s.authors     = ["Arun Kumar"]
  s.email       = ["arun@chronus.com"]
  s.homepage    = "http://chronus.com"
  s.summary     = "SSO Validators."
  s.description = "SSO Validators."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 5.1.4"
  # s.add_dependency "jquery-rails"
end
