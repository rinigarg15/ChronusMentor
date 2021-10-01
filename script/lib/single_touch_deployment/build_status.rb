require 'nokogiri'
require_relative './deployment_constants'
require_relative './deployment_module_helper'
require_relative './deployment_helper'

class BuildStatus
  include DeploymentConstants
  include DeploymentModuleHelper

  def current_build_status(branch_name)
    status_develop = retry_when_exception("Build Check Website is Down. Check the build manually"){
      build_doc = Nokogiri::XML(open(ENV["BUILD_CHECK_API"]))
      build_doc.xpath("//Project[@name='ChronusMentor (#{branch_name})']").first
    }
    status_develop = {} unless status_develop
    if status_develop['lastBuildStatus'] == "Success" and status_develop['activity'] == "Sleeping"
      return true
    end
    return false
  end

  #check build of all branches and return true false corresponding to it.
  def check_build_passed(git_branches) #git_branches = ["develop", "nch_develop", "general_electric_develop"]
    puts "Build Check for Branches: #{git_branches.join(",")}"
    count_check = 0
    built_status = Array.new(git_branches.size){ |i| false }
    while(count_check < BUILD_RETRY_COUNT) do
      (0...built_status.size).each do |i|
        built_status[i] = self.current_build_status(git_branches[i]) unless built_status[i]
        puts "Current Build Status of #{git_branches[i]}: #{built_status[i]}"
      end
      return built_status if built_status.all?{ |elem| elem == true }
      sleep BUILD_SLEEP_TIME
      count_check += 1
    end
    return built_status
  end
end