require_relative './../../test_helper.rb'

class DJUtilsTest < ActiveSupport::TestCase
  def setup
    super
    Delayed::Worker.delay_jobs = true
  end

  def teardown
    super
    Delayed::Worker.delay_jobs = false
  end

  def test_enqueue_unless_duplicates
    albers_program_id = programs(:albers).id
    psg_program_id = programs(:psg).id
    handler = Delayed::PerformableMethod.new(Matching, :perform_program_delta_index_and_refresh_later, [albers_program_id]).to_yaml

    assert_difference "Delayed::Job.count", 1 do
      enqueue_delayed_job(albers_program_id)
    end
    assert_equal handler, Delayed::Job.last.handler

    assert_no_difference "Delayed::Job.count" do
      enqueue_delayed_job(albers_program_id)
    end

    enqueued_job = Delayed::Job.last
    enqueued_job.update_attribute(:locked_at, 5.minutes.ago)
    assert_difference "Delayed::Job.count", 1 do
      enqueue_delayed_job(albers_program_id)
    end

    enqueued_job = Delayed::Job.last
    enqueued_job.update_attribute(:failed_at, 5.minutes.ago)
    assert_difference "Delayed::Job.count", 1 do
      enqueue_delayed_job(albers_program_id)
    end

    assert_difference "Delayed::Job.count", 1 do
      enqueue_delayed_job(psg_program_id)
    end
  end

  def test_create_elasticsearch_indexer_job
    handler = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3], :bulk_index_es_documents, nil , []).to_yaml

    assert_difference "Delayed::Job.count", 1 do
      DJUtils.enqueue_unless_duplicates(queue: DjQueues::ES_DELTA).create_elasticsearch_indexer_job(Meeting, [1, 2, 3], :bulk_index_es_documents, nil, [])
    end
    assert_equal handler, Delayed::Job.last.handler

    assert_difference "Delayed::Job.count", 0 do
      DJUtils.enqueue_unless_duplicates(queue: DjQueues::ES_DELTA).create_elasticsearch_indexer_job(Meeting, [1, 2, 3], :bulk_index_es_documents, nil, [])
    end
    assert_equal handler, Delayed::Job.last.handler
  end

  private

  def enqueue_delayed_job(args)
    DJUtils.enqueue_unless_duplicates({ queue: DjQueues::MONGO_CACHE })
      .perform_program_delta_index_and_refresh_later(Matching, args)
  end
end