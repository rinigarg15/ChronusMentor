require_relative './../../../test_helper'

class DelayedEsDocumentTest < ActiveSupport::TestCase
  def setup
    super
    dj_setup
  end

  def teardown
    super
    dj_teardown
  end

  def test_delayed_bulk_update_es_documents
    handler = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3], :bulk_update_es_documents, nil , []).to_yaml
    assert_difference "Delayed::Job.count", 2 do
      DelayedEsDocument.delayed_bulk_update_es_documents(Meeting, [1, 2, 3])
    end
    assert_equal handler, Delayed::Job.last.handler
    assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last.queue
    assert_equal handler, Delayed::Job.last(2).first.handler
    assert_equal "es_delta", Delayed::Job.last(2).first.queue

    # prevent duplicates
    assert_difference "Delayed::Job.count", 0 do
      DelayedEsDocument.delayed_bulk_update_es_documents(Meeting, [1, 2, 3])
    end

    handler = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3, 4], :bulk_update_es_documents, nil , []).to_yaml
    current_time = Time.zone.now
    Timecop.freeze(current_time) do
      DelayedEsDocument.expects(:is_model_reindexing?).with(Meeting).returns(true)
      assert_difference "Delayed::Job.count", 3 do
        DelayedEsDocument.delayed_bulk_update_es_documents(Meeting, [1, 2, 3, 4])
      end

      assert_equal "es_delta", Delayed::Job.last.queue
      assert_equal (current_time + 12.hours).to_i, Delayed::Job.last.run_at.to_i
      assert_equal handler, Delayed::Job.last(2).first.handler
      assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last(2).first.queue
      assert_equal handler, Delayed::Job.last(3).first.handler
      assert_equal "es_delta", Delayed::Job.last(3).first.queue
      assert_equal handler, Delayed::Job.last.handler
    end
  end

  def test_delayed_bulk_delete_es_documents
    handler = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3], :bulk_delete_es_documents, nil , []).to_yaml
    assert_difference "Delayed::Job.count", 2 do
      DelayedEsDocument.delayed_bulk_delete_es_documents(Meeting, [1, 2, 3])
    end
    assert_equal handler, Delayed::Job.last.handler
    assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last.queue
    assert_equal handler, Delayed::Job.last(2).first.handler
    assert_equal "es_delta", Delayed::Job.last(2).first.queue

    # prevent duplicates
    assert_difference "Delayed::Job.count", 0 do
      DelayedEsDocument.delayed_bulk_delete_es_documents(Meeting, [1, 2, 3])
    end

    handler = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3, 4], :bulk_delete_es_documents, nil , []).to_yaml
    current_time = Time.zone.now
    Timecop.freeze(current_time) do
      DelayedEsDocument.expects(:is_model_reindexing?).with(Meeting).returns(true)

      assert_difference "Delayed::Job.count", 3 do
        DelayedEsDocument.delayed_bulk_delete_es_documents(Meeting, [1, 2, 3, 4])
      end

      assert_equal "es_delta", Delayed::Job.last.queue
      assert_equal (current_time + 12.hours).to_i, Delayed::Job.last.run_at.to_i
      assert_equal handler, Delayed::Job.last(2).first.handler
      assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last(2).first.queue
      assert_equal handler, Delayed::Job.last(3).first.handler
      assert_equal "es_delta", Delayed::Job.last(3).first.queue
      assert_equal handler, Delayed::Job.last.handler
    end
  end

  def test_delayed_bulk_index_es_documents
    handler = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3], :bulk_index_es_documents, nil , []).to_yaml
    assert_difference "Delayed::Job.count", 2 do
      DelayedEsDocument.delayed_bulk_index_es_documents(Meeting, [1, 2, 3])
    end
    assert_equal handler, Delayed::Job.last.handler
    assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last.queue
    assert_equal handler, Delayed::Job.last(2).first.handler
    assert_equal "es_delta", Delayed::Job.last(2).first.queue

    # prevent duplicates
    assert_difference "Delayed::Job.count", 0 do
      DelayedEsDocument.delayed_bulk_index_es_documents(Meeting, [1, 2, 3])
    end

    handler = ElasticsearchIndexerJob.new(Meeting, [1, 2, 3, 4], :bulk_index_es_documents, nil , []).to_yaml
    current_time = Time.zone.now
    Timecop.freeze(current_time) do
      DelayedEsDocument.expects(:is_model_reindexing?).with(Meeting).returns(true).times(2)
      assert_difference "Delayed::Job.count", 3 do
        DelayedEsDocument.delayed_bulk_index_es_documents(Meeting, [1, 2, 3, 4])
      end

      assert_equal "es_delta", Delayed::Job.last.queue
      assert_equal (current_time + 12.hours).to_i, Delayed::Job.last.run_at.to_i
      assert_equal handler, Delayed::Job.last(2).first.handler
      assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last(2).first.queue
      assert_equal handler, Delayed::Job.last(3).first.handler
      assert_equal "es_delta", Delayed::Job.last(3).first.queue
      assert_equal handler, Delayed::Job.last.handler

      # prevent duplicates
      assert_difference "Delayed::Job.count", 0 do
        DelayedEsDocument.delayed_bulk_index_es_documents(Meeting, [1, 2, 3, 4])
      end
    end
  end

  def test_arel_delta_indexer
    objects = User.where(id: users(:f_student, :f_mentor).collect(&:id))
    # when caller is update_all
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, users(:f_student, :f_mentor).collect(&:id))
    DelayedEsDocument.arel_delta_indexer(User, objects, :update)
    # when caller is delete_all
    DelayedEsDocument.expects(:delayed_bulk_delete_es_documents).with(User, users(:f_student, :f_mentor).collect(&:id))
    DelayedEsDocument.arel_delta_indexer(User, objects, :delete)
  end

  def test_do_delta_indexing
    objects = User.where(id: users(:f_student, :f_mentor).collect(&:id))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, users(:f_student, :f_mentor).collect(&:id))
    DelayedEsDocument.do_delta_indexing(User, objects, :id)

    assert_raise "objects must be an ActiveRecord Relation/Array, so that delta indexing for update_all/delete_all will be taken care." do
      DelayedEsDocument.do_delta_indexing(User, users(:f_student).id, :id)
    end
  end

  def test_skip_es_delta_indexing
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Message, [messages(:first_message).id]).never
    DelayedEsDocument.skip_es_delta_indexing do
      messages(:first_message).update_attributes!(updated_at: Time.now)
    end

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Message, [messages(:first_message).id]).once
    DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
      messages(:first_message).update_attributes!(updated_at: Time.now)
    end

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Message, [messages(:first_message).id]).never
    DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true, skip_dj_creation: true) do
      messages(:first_message).update_attributes!(updated_at: Time.now)
    end

    DelayedEsDocument.expects(:delayed_update_es_document).with(Message, messages(:first_message).id).once
    messages(:first_message).update_attributes!(updated_at: Time.now)
  end

  def test_skip_es_delta_indexing_exception_raised

    assert_raise "Exception raised" do
      assert_difference "Delayed::Job.count", 2 do
        DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
          messages(:first_message).update_attributes!(updated_at: Time.now)
          raise "Exception raised"
        end
      end
    end

    assert_raise "Exception raised" do
      assert_no_difference "Delayed::Job.count" do
        ActiveRecord::Base.transaction do
          DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
            messages(:first_message).update_attributes!(updated_at: Time.now)
            raise "Exception raised"
          end
        end
      end
    end
  end

  def test_delayed_bulk_partial_update_es_documents
    handler = ElasticsearchIndexerJob.new(User, [1, 2, 3], :bulk_partial_update_es_documents, User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list]).to_yaml
    assert_difference "Delayed::Job.count", 2 do
      DelayedEsDocument.delayed_bulk_partial_update_es_documents(User, [1, 2, 3], User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list])
    end
    assert_equal handler, Delayed::Job.last.handler
    assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last.queue
    assert_equal handler, Delayed::Job.last(2).first.handler
    assert_equal "es_delta", Delayed::Job.last(2).first.queue

    # prevent duplicates
    assert_difference "Delayed::Job.count", 0 do
      DelayedEsDocument.delayed_bulk_partial_update_es_documents(User, [1, 2, 3], User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list])
    end

    handler = ElasticsearchIndexerJob.new(User, [1, 2, 3, 4], :bulk_partial_update_es_documents, User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list]).to_yaml

    current_time = Time.zone.now
    Timecop.freeze(current_time) do
      DelayedEsDocument.expects(:is_model_reindexing?).with(User).returns(true)
      assert_difference "Delayed::Job.count", 3 do
        DelayedEsDocument.delayed_bulk_partial_update_es_documents(User, [1, 2, 3, 4], User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list])
      end

      assert_equal "es_delta", Delayed::Job.last.queue
      assert_equal (current_time + 12.hours).to_i, Delayed::Job.last.run_at.to_i
      assert_equal handler, Delayed::Job.last(2).first.handler
      assert_equal DjQueues::AWS_ELASTICSEARCH_SERVICE, Delayed::Job.last(2).first.queue
      assert_equal handler, Delayed::Job.last(3).first.handler
      assert_equal "es_delta", Delayed::Job.last(3).first.queue
      assert_equal handler, Delayed::Job.last.handler
    end
  end

  def test_slice_es_djs
    assert_difference "Delayed::Job.count", 4 do
      DelayedEsDocument.delayed_bulk_update_es_documents(User, (1..1200).to_a)
    end
  end
end