require 'httparty'
require 'json'
require_relative './deployment_constants'
require_relative './deployment_module_helper'
require_relative './deployment_helper'

class CodeReview
  include DeploymentConstants
  include DeploymentModuleHelper

  def get_diff_text(timestamp)
    File.read("/tmp/#{MASTER_BRANCH}_#{DEVELOP_BRANCH}_diff_#{timestamp}.txt")
  end

  def auth_credentials
    {:username => ENV["CRUCIBLE_ADMIN_ID"], :password => ENV["CRUCIBLE_ADMIN_PASSWORD"]}
  end

  def get_reviewers_userids_hash
    reviewers_hash = {}
    user_list = self.retry_when_exception("Unable to get Crucible Users. Retry it manually or check if Crucible is down"){
      HTTParty.get("#{CRUCIBLE_API_URL}/users-v1", :basic_auth => self.auth_credentials)["users"]["userData"]
    }
    user_list.each do |user|
      retry_when_exception("Unable to get users profile details User Id: #{user}. Check if user exits in Crucible or Crucible is down"){
        user_info = HTTParty.get("#{CRUCIBLE_API_URL}/users-v1/#{user["userName"]}", :basic_auth => self.auth_credentials)
        reviewers_hash[user_info["restUserProfileData"]["email"]] = user["userName"]
      }
    end
    reviewers_hash
  end

  def get_emailids_from_commits
    result, stderr, status = Open3.capture3("git log #{MASTER_BRANCH}..#{DEVELOP_BRANCH} | grep Author | sort -u")
    result.scan(/\<([^\>]+)\>/).uniq
  end

  def send_reviewer_emails(review_id)
    get_emailids_from_commits.each do |email_arr|
      DeploymentHelper.send_developer_email("Add CRUCIBLE comments: For RELEASES NOTES", "Link: https://chronus-corp.innoscale.net/cru/#{review_id}", email_arr[0])
    end
  end

  def get_reviewers
    reviewer_hash = self.get_reviewers_userids_hash
    get_emailids_from_commits.map { |elem| reviewer_hash[elem.first] }.compact.join(",")
  end

  def abort_deployment_checking_diff(diff_text)
    #Abort deployment if the diff contains both ES reindex and not ZDT data migration changes
    if !!(diff_text =~ /reindex_version/i) && (!!(diff_text =~ /ChronusMigrate\.data_migration(\s|\(\)\s)do/i) || !!(diff_text =~ /ChronusMigrate.data_migration\((:|)has_downtime.{,5}true\)/i))
      DeploymentHelper.send_developer_email("Aborting deployment since both ES Reindex and Data Migration is present", "Contact Ops Team.")
      abort("Aborting Deployment since both ES Reindex and non-ZDT Data Migration is present".colorize(:color => :red))
    end
  end

  def create_review(timestamp, skip_abort_deployment)
    diff_text = get_diff_text(timestamp)
    abort_deployment_checking_diff(diff_text) unless skip_abort_deployment
    puts "putting for crucible_review"
    review_data = { "reviewData" => { "projectKey" => "CR-AP", "name" => "Master Develop Diff #{Time.now}", "description" => "Review this and Add RELEASE NOTES here as comments.", "author" => {"userName" => CRUCIBLE_AUTHOR_USERNAME, "displayName" => CRUCIBLE_AUTHOR_DISPLAYNAME, "avatarUrl" => CRUCIBLE_AUTHOR_AVATARURL}, "moderator" => { "userName" => CRUCIBLE_AUTHOR_USERNAME,"displayName" => CRUCIBLE_AUTHOR_DISPLAYNAME,"avatarUrl" => CRUCIBLE_AUTHOR_AVATARURL},"summary" => "Review Summary.","state" => "Review","type" => "REVIEW", "allowReviewersToJoin" => true}, "patch" => "Index: /tmp/#{MASTER_BRANCH}_#{DEVELOP_BRANCH}_diff_#{timestamp}.txt\n===================================================================\n#{diff_text}" }
    reviewers_email = get_emailids_from_commits.join(",")
    puts reviewers_email
    #Create Review
    review_id = retry_when_exception("Crucible Website is Down. Check it manually and create a review with diff present in /tmp/<timestamp>. Reviewers Email: #{reviewers_email}"){
      response = HTTParty.post("#{CRUCIBLE_API_URL}/reviews-v1", :body => review_data.to_json, :basic_auth => self.auth_credentials, :headers => { 'Content-Type' => 'application/json', 'Accept' => 'application/json'})
      response["permaId"]["id"]
    }

     #Add Reviewers
    retry_when_exception("Enable to put reviewers for review: Review ID: #{review_id}. Add Reviewers manually. Reviewers Email: #{reviewers_email}"){
      HTTParty.post("#{CRUCIBLE_API_URL}/reviews-v1/#{review_id}/reviewers", :body => get_reviewers, :basic_auth => self.auth_credentials, :headers => { 'Content-Type' => 'application/json', 'Accept' => 'application/json'})
      send_reviewer_emails(review_id)
    }
    return true
  end
end