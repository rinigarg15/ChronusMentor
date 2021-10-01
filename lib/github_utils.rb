module GithubUtils  

  DEVELOPERS_LIST = ["Manju"]

  # Delete all the remote branches that are already merged with remote master
  def self.delete_remote_branches_if_not_ahead
    remote_branches = self.get_remote_branches
    Rails.logger.info "Branches Size: #{remote_branches.size}"
    Rails.logger.info "Branches: #{remote_branches}"
    remote_deploy_branches = self.get_remote_deploy_branches
    Rails.logger.info "Deploy Branches: #{remote_deploy_branches}"
    branches_to_consider = remote_branches - remote_deploy_branches
    @branch_deleted = false   
    branches_to_consider.each do |remote_branch|
      @branch_deleted = false
      commits_ahead = self.get_commits_ahead(remote_branch)
      Rails.logger.info "Details: #{remote_branch}, #{commits_ahead}"
      self.delete_if_not_ahead(remote_branch, commits_ahead)
    end
  end

  # Delete all the remote branches whose developers are not currently present
  def self.delete_remote_branches_if_latest_committer_not_present
    remote_branch_refs = self.get_remote_branches_with_committers
    branches_grouped_by_developers = self.get_branches_grouped_by_developer(remote_branch_refs)
    remote_deploy_branches = self.get_remote_deploy_branches
    @branch_deleted = false
    DEVELOPERS_LIST.each do |developer_name|
      Rails.logger.info "Developer Name: #{developer_name}"
      branches_to_consider = branches_grouped_by_developers[developer_name] || []
      branches_to_consider = branches_to_consider - remote_deploy_branches
      branches_to_consider.each do |remote_branch|
        @branch_deleted = false
        commits_ahead = self.get_commits_ahead(remote_branch)
        Rails.logger.info "Details: #{remote_branch}, #{commits_ahead}"
        self.delete_if_developer_not_exist(remote_branch, commits_ahead, developer_name)
      end
    end
  end

  # Delete local and remote branches with the given name
  def self.delete_local_and_remote_branches_with_name(branch_name)
    remote_branch = "origin/#{branch_name}"
    @branch_deleted = false
    commits_ahead = self.get_commits_ahead(remote_branch)
    Rails.logger.info "Details:"
    Rails.logger.info "Branch Name: #{branch_name}"
    Rails.logger.info "No of Commit Ahead of Master: #{commits_ahead}"
    commit_differences = self.get_commits_differences(remote_branch)
    Rails.logger.info "Commits Difference: #{commit_differences}"
    self.delete_local_branch(branch_name)
    self.delete_remote_branch(branch_name)
    @branch_deleted = true
  end

  private

  def self.system_call(command)
    `#{command}`
  end

  def self.formatted_output(output)
    output.split("\n").delete_if(&:blank?)
  end

  # Get list of remote branches
  def self.get_remote_branches
    self.formatted_output(self.system_call("git fetch origin"))
    remote_branches = self.formatted_output(self.system_call("git for-each-ref --format '%(refname:short)' refs/remotes")).reject{|branch| branch.match("solano/")}
    return remote_branches
  end

  # Get list of remote branches along with committers name in the reference
  def self.get_remote_branches_with_committers
    self.formatted_output(self.system_call("git fetch origin"))
    remote_branches = self.formatted_output(self.system_call("git for-each-ref --format '%(refname:short) %(authorname)' refs/remotes")).reject{|branch| branch.match("solano/")}
    return remote_branches
  end

  def self.get_commits_ahead(remote_branch)
    commits_ahead = self.formatted_output(self.system_call("git rev-list --count origin/master..#{remote_branch}")).first.to_i
    return commits_ahead
  end

  def self.get_commits_differences(remote_branch)
    commits_differences = self.formatted_output(self.system_call("git log origin/master..#{remote_branch} --oneline"))
    return commits_differences
  end

  # Delete if the given branch is not ahead after secondary check.
  def self.delete_if_not_ahead(remote_branch, commits_ahead)
    if commits_ahead == 0      
      commit_differences = self.get_commits_differences(remote_branch)
      if commit_differences.empty?
        branch_name = remote_branch.split("/")[1]
        Rails.logger.info "Branch - '#{branch_name}' is ready for deletion."
        self.delete_remote_branch(branch_name)
        @branch_deleted = true
      else
        Rails.logger.info "Branch - '#{branch_name}' has commits ahead and is not ready for deletion."
      end
    else
      Rails.logger.info "Branch - '#{remote_branch}' is not ready for deletion."
    end
  end

  # Return remote deploy branches by parsing deploy.yml
  def self.get_remote_deploy_branches
    deploy_branches = YAML.load_file(File.dirname(__FILE__) +'/../config/deploy.yml').values.collect{|val| val["branch"]}
    remote_deploy_branches = deploy_branches.compact.uniq.map{|branch| "origin/#{branch}"} + ["origin/develop", "origin/content_develop", "origin/HEAD", "origin/nciia_deploy", "origin/realogy_deploy", "origin/demo_deploy", "origin/develop_cucumbers", "origin/staging1_cucumbers", "origin/nch_develop_cucumbers", "origin/nch_staging_cucumbers"]
    remote_deploy_branches
  end

  # Returns hash of branches grouped by developers name.
  def self.get_branches_grouped_by_developer(remote_branch_refs)
    developer_branch_hash = {}
    remote_branch_refs.each do |references|
      list = references.split(" ")
      remote_branch = list[0]
      developer = list[1..-1].join(" ")
      developer_branch_hash[developer] ||= []
      developer_branch_hash[developer] << remote_branch
    end
    return developer_branch_hash
  end

  # Delete if the given branch is not ahead after secondary check.
  def self.delete_if_developer_not_exist(remote_branch, commits_ahead, developer_name)
    return unless DEVELOPERS_LIST.include?(developer_name)
    commit_differences = self.get_commits_differences(remote_branch)
    branch_name = remote_branch.split("/")[1]
    Rails.logger.info "Branch - '#{branch_name}' is ready for deletion. Commit Difference: #{commit_differences.size}"
    self.delete_remote_branch(branch_name)
    @branch_deleted = true
  end

  def self.delete_remote_branch(branch_name)
    self.system_call("git push origin --delete #{branch_name}")
  end

  def self.delete_local_branch(branch_name)
    self.system_call("git branch -D #{branch_name} 2>/dev/null")
  end

  def self.is_branch_deleted?
    @branch_deleted
  end
end