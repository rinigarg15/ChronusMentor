$:.push File.expand_path("../lib", __FILE__)

require "campaign_management/version"

Gem::Specification.new do |s|
  s.name        = "campaign_management"
  s.version     = CampaignManagement::VERSION
  s.authors     = [""]
  s.email       = [""]
  s.homepage    = ""
  s.summary     = ""
  s.description = ""

  s.files = Dir["{app,config,lib}/**/*"]
  s.test_files = Dir["test/**/*"]
end
