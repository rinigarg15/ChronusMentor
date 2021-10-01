$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mobile_v2/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mobile_v2"
  s.version     = MobileV2::VERSION
  s.authors     = ["Chronus"]
  s.email       = ["apollodev@chronus.com"]
  s.homepage    = "http://chronus.com"
  s.summary     = "Mobile App V2"
  s.description = "Mobile App V2 Code"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 5.1.4"
  # s.add_dependency "jquery-rails"

end
