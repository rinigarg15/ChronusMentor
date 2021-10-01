require_relative './../../../../test_helper'

class CronTasks::Elasticsearch::DocumentCountCheckerTest < ActiveSupport::TestCase

  def test_perform
    ChronusElasticsearch.expects(:models_with_es).once.returns([User, Group])
    EsDocumentCountChecker.expects(:check_and_fix_document_counts).once.with( { "User" => "user-test#{ENV['TEST_ENV_NUMBER']}", "Group" => "group-test#{ENV['TEST_ENV_NUMBER']}" }, count_only: false, for_deployment: false)
    CronTasks::Elasticsearch::DocumentCountChecker.new.perform
  end
end