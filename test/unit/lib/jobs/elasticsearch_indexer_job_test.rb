require_relative './../../../test_helper.rb'

class SampleTest
  def self.index_name
    "SampleIndexName"
  end

  def self.document_type
    "SampleDocumentType"
  end

  def self.find(id)
    return SampleTest.new
  end

  def self.find_by(id)
    return SampleTest.new
  end

  def some_method
  end

  def delete_es_document
  end

  def wrong_method
    raise 'TEST EXCEPTION'
  end
end

class ElasticsearchIndexerJobTest < ActiveSupport::TestCase
  def setup
    super
    ChronusElasticsearch.skip_es_index = false
  end

  def teardown
    super
    ChronusElasticsearch.skip_es_index = true
    ChronusElasticsearch.reindex_list = []
  end

  def test_elasticsearch_indexer_job_skip_index
    ChronusElasticsearch.skip_es_index = true
    SampleTest.any_instance.stubs(:some_method).at_most(0)
    JobLog.stubs(:log_info).with("**some_method for SampleTest with id 1 SUCCESSFUL**").at_most(0)
    job = ElasticsearchIndexerJob.new(SampleTest, 1, :some_method)
    job.perform
  end

  def test_elasticsearch_indexer_job_success
    SampleTest.any_instance.stubs(:some_method).at_least(1)
    JobLog.stubs(:log_info).with("**some_method for SampleTest with id 1 SUCCESSFUL**").at_least(1)
    job = ElasticsearchIndexerJob.new(SampleTest, 1, :some_method)
    job.perform
  end

  def test_elasticsearch_indexer_job_failure
    Airbrake.expects(:notify).once
    JobLog.stubs(:log_info).with("**wrong_method for SampleTest with id 1 FAILED with exception 'TEST EXCEPTION'**").at_least(1)
    job = ElasticsearchIndexerJob.new(SampleTest, 1, :wrong_method)
    job.perform
  end

  def test_elasticsearch_indexer_job_delete_es_document
    Elasticsearch::Model.client.stubs(:delete).with(index: "SampleIndexName", type: "SampleDocumentType", id: 1).returns(true)
    JobLog.stubs(:log_info).with("**delete_es_document for SampleTest with id 1 SUCCESSFUL**").at_least(1)
    job = ElasticsearchIndexerJob.new(SampleTest, 1, :delete_es_document)
    job.perform
  end

  def test_elasticsearch_indexer_job_bulk_update_es_documents
    Elasticsearch::Model.client.stubs(:bulk).with(index: "meeting-test#{ENV['TEST_ENV_NUMBER']}", type: "meeting", body: [{:index => {:_id => 1, :data => {'id' => 1, 'topic' => 'Arbit Topic', 'program_id' => programs(:albers).id, 'active' => true, 'not_cancelled' => true, 'attendees' => [{'id' => members(:f_mentor).id, 'name_only' => 'Good unique name'}, {'id' => members(:mkr_student).id, 'name_only' => 'mkr_student madankumarrajan'}]}}}, {:index => {:_id => 2, :data => {'id' => 2, 'topic' => 'Arbit Topic2', 'program_id' => programs(:albers).id, 'active' => true, 'not_cancelled' => true, 'attendees' => [{'id' => members(:student_2).id, 'name_only' => 'student_c example'}, {'id' => members(:not_requestable_mentor).id, 'name_only' => 'Non requestable mentor'}]}}}, {:index => {:_id => 3, :data => {'id' => 3, 'topic' => 'Sample Meeting', 'program_id' => programs(:psg).id, 'active' => true, 'not_cancelled' => true, 'attendees' => [{'id' => members(:psg_mentor1).id, 'name_only' => 'PSG mentora'}, {'id' => members(:psg_student1).id, 'name_only' => 'studa psg'}]}}}]).returns(true)
    JobLog.stubs(:log_info).with("**bulk_update_es_documents for Meeting with id [1, 2, 3] SUCCESSFUL**").at_least(1)
    job = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3], :bulk_update_es_documents)
    job.perform
  end

  def test_elasticsearch_indexer_job_bulk_partial_update_es_documents
    Elasticsearch::Model.client.stubs(:bulk).with(index: "user-test#{ENV['TEST_ENV_NUMBER']}", type: "user", body: [{:update=>{:_id=>1, :data=>{:doc=>{"profile_score_sum"=>15}}}}, {:update=>{:_id=>2, :data=>{:doc=>{"profile_score_sum"=>15}}}}, {:update=>{:_id=>3, :data=>{:doc=>{"profile_score_sum"=>59}}}}]).returns(true)
    JobLog.stubs(:log_info).with("**bulk_partial_update_es_documents for User with id [1, 2, 3] SUCCESSFUL**").at_least(1)
    job = ElasticsearchIndexerJob.new(User, [1, 2, 3], :bulk_partial_update_es_documents, User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list])
    job.perform
  end

  def test_elasticsearch_indexer_job_delete_es_document_transport_error
    Elasticsearch::Model.client.expects(:delete).with(index: "SampleIndexName", type: "SampleDocumentType", id: 1).raises(Elasticsearch::Transport::Transport::Errors::NotFound)
    JobLog.stubs(:log_info).with("**delete_es_document for SampleTest with id 1 FAILED with exception 'Elasticsearch::Transport::Transport::Errors::NotFound'**").at_least(1)
    Airbrake.expects(:notify).never
    job = ElasticsearchIndexerJob.new(SampleTest, 1, :delete_es_document)
    job.perform
  end

  def test_elasticsearch_indexer_job_failure_ar_not_found
    SampleTest.expects(:find_by).with({id: 1 }).raises(ActiveRecord::RecordNotFound)
    Airbrake.expects(:notify).never
    JobLog.stubs(:log_info).with("**some_method for SampleTest with id 1 FAILED with exception 'ActiveRecord::RecordNotFound'**").at_least(1)
    job = ElasticsearchIndexerJob.new(SampleTest, 1, :some_method)
    job.perform
  end

  def test_elasticsearch_indexer_job_with_scope_for_non_bulk
    locations(:invalid_geo).update_attributes!(reliable: false)
    ElasticsearchIndexerJob.any_instance.expects(:invoke_delete_document).with(Location, locations(:invalid_geo).id, true).once
    job = ElasticsearchIndexerJob.new(Location, locations(:invalid_geo).id, :update_es_document)
    job.perform
  end

  def test_elasticsearch_indexer_job_with_scope_for_bulk
    locations(:invalid_geo).update_attributes!(reliable: false)
    ElasticsearchIndexerJob.any_instance.expects(:invoke_bulk_api).with(Location, [{:delete => {:_id => locations(:invalid_geo).id}}]).once
    ElasticsearchIndexerJob.any_instance.expects(:invoke_bulk_api).with(Location, [{:index => {:_id => 1, :data => {'id' => 1, 'profile_answers_count' => 3, 'full_address' => 'Chennai, Tamil Nadu, India', 'full_address_db' => 'Chennai, Tamil Nadu, India', 'full_state' => 'Tamil Nadu,India', 'full_country' => 'India', 'full_city' => 'Chennai,Tamil Nadu,India'} } }]).once
    job = ElasticsearchIndexerJob.new(Location, locations(:invalid_geo, :chennai).collect(&:id), :bulk_update_es_documents)
    job.perform
  end

  def test_elasticsearch_bulk_delete_es_documents
    job = ElasticsearchIndexerJob.new(Location, [nil], :bulk_delete_es_documents)
    job.perform

    ElasticsearchIndexerJob.any_instance.expects(:invoke_bulk_api).with(Location, [{:delete => {:_id => locations(:invalid_geo).id}}]).once
    job = ElasticsearchIndexerJob.new(Location,  [locations(:invalid_geo).id], :bulk_delete_es_documents)
    job.perform
  end
end