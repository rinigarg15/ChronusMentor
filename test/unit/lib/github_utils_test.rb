require_relative './../../test_helper.rb'

class GithubUtilsTest < ActiveSupport::TestCase

  def setup
    super
    @local_branch = "test_branch_for_github_utils_test"
    @remote_branch = "origin/#{@local_branch}"
  end

  def test_delete_remote_branches_if_not_ahead
    GithubUtils.stubs(:get_remote_branches).returns([@remote_branch])
    assert_equal ["origin/test_branch_for_github_utils_test"], GithubUtils.get_remote_branches
    GithubUtils.stubs(:get_commits_ahead).with(@remote_branch).returns(0)
    GithubUtils.stubs(:get_commits_differences).with(@remote_branch).returns([])
    GithubUtils.stubs(:delete_remote_branch).with(@local_branch).returns(true)
    GithubUtils.delete_remote_branches_if_not_ahead
    assert GithubUtils.is_branch_deleted?
  end

  def test_do_not_delete_remote_branches_if_ahead
    GithubUtils.stubs(:get_remote_branches).returns([@remote_branch])
    assert_equal ["origin/test_branch_for_github_utils_test"], GithubUtils.get_remote_branches
    GithubUtils.stubs(:get_commits_ahead).with(@remote_branch).returns(1)
    GithubUtils.stubs(:get_commits_differences).with(@remote_branch).returns(["c26eb20", "Script for github utils"])
    GithubUtils.stubs(:delete_remote_branch).with(@local_branch).returns(true)
    GithubUtils.delete_remote_branches_if_not_ahead
    assert_false GithubUtils.is_branch_deleted?
  end

  def test_do_not_delete_remote_branches_if_deploy_branch
    @remote_branch = "origin/nch_staging"
    GithubUtils.stubs(:get_remote_branches).returns([@remote_branch])
    assert_equal ["origin/nch_staging"], GithubUtils.get_remote_branches
    GithubUtils.stubs(:get_commits_ahead).with(@remote_branch).returns(0)
    GithubUtils.stubs(:get_commits_differences).with(@remote_branch).returns([])
    GithubUtils.stubs(:delete_remote_branch).with(@local_branch).returns(true)
    GithubUtils.delete_remote_branches_if_not_ahead
    assert_false GithubUtils.is_branch_deleted?
  end

  def test_delete_remote_branches_if_latest_committer_not_present
    GithubUtils.stubs(:get_remote_branches_with_committers).returns([@remote_branch])
    assert_equal ["origin/test_branch_for_github_utils_test"], GithubUtils.get_remote_branches_with_committers
    GithubUtils.stubs(:get_commits_ahead).with(@remote_branch).returns(1)
    GithubUtils.stubs(:get_commits_differences).with(@remote_branch).returns(["c26eb20", "Script for github utils"])
    GithubUtils.stubs(:get_branches_grouped_by_developer).with([@remote_branch]).returns({"Manju" => ["origin/test_branch_for_github_utils_test"]})
    GithubUtils.stubs(:delete_remote_branch).with(@local_branch).returns(true)
    GithubUtils.delete_remote_branches_if_latest_committer_not_present
    assert GithubUtils.is_branch_deleted?
  end

  def test_do_not_delete_remote_branches_if_latest_committer_present
    GithubUtils.stubs(:get_remote_branches_with_committers).returns([@remote_branch])
    assert_equal ["origin/test_branch_for_github_utils_test"], GithubUtils.get_remote_branches_with_committers
    GithubUtils.stubs(:get_commits_ahead).with(@remote_branch).returns(0)
    GithubUtils.stubs(:get_commits_differences).with(@remote_branch).returns([])
    GithubUtils.stubs(:get_branches_grouped_by_developer).with([@remote_branch]).returns({"Sabarish" => ["origin/test_branch_for_github_utils_test"]})
    GithubUtils.stubs(:delete_remote_branch).with(@local_branch).returns(true)
    GithubUtils.delete_remote_branches_if_latest_committer_not_present
    assert_false GithubUtils.is_branch_deleted?
  end

  def test_delete_local_and_remote_branches_with_name
    GithubUtils.stubs(:get_commits_ahead).with(@remote_branch).returns(1)
    GithubUtils.stubs(:get_commits_differences).with(@remote_branch).returns(["c26eb20", "Script for github utils"])
    GithubUtils.stubs(:delete_local_branch).with(@local_branch).returns(true)
    GithubUtils.stubs(:delete_remote_branch).with(@local_branch).returns(true)
    GithubUtils.delete_local_and_remote_branches_with_name(@local_branch)
    assert GithubUtils.is_branch_deleted?
  end

end