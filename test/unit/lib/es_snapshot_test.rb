require_relative './../../test_helper.rb'

class EsSnapshotTest < ActiveSupport::TestCase

  def startup
    Object.const_set("AWS_ES_OPTIONS", { s3_repository: "s3-repo", s3_bucket: "s3-bucket", s3_region: "s3-region", s3_access_role: "s3-role" } )
  end

  def shutdown
    Object.send(:remove_const, "AWS_ES_OPTIONS")
  end

  def test_flush_aws_dj_entries
    Delayed::Job.create(queue: DjQueues::AWS_ELASTICSEARCH_SERVICE, handler: "a")
    dj1 = Delayed::Job.create(queue: DjQueues::AWS_ELASTICSEARCH_SERVICE, handler: "b")
    Delayed::Job.create(queue: DjQueues::AWS_ELASTICSEARCH_SERVICE, handler: "b")
    dj2 = Delayed::Job.create(queue: DjQueues::ES_DELTA, handler: "b")

    assert_difference "Delayed::Job.count", -2 do
      EsSnapshot.flush_aws_dj_entries
    end
    assert_nothing_raised do
      dj1.reload
      dj2.reload
    end
  end

  def test_run_delta_jobs_in_aws_dj_queue
    Delayed::Job.create(queue: DjQueues::AWS_ELASTICSEARCH_SERVICE, handler: "a")

    Delayed::Job.any_instance.expects(:invoke_job).once
    assert_difference "Delayed::Job.count", -1 do
      EsSnapshot.run_delta_jobs_in_aws_dj_queue
    end
  end

  def test_create_s3_repository
    snapshot_name = "es-snapshot-test-2018-03-08_00:00:00"
    client = ElasticsearchReindexing.configure_client
    options = {
      repository: "s3-repo",
      body: {
        type: "s3",
        settings: {
          bucket: "s3-bucket",
          region: "s3-region",
          role_arn: "s3-role",
          base_path: snapshot_name
        }
      }
    }

    client.snapshot.expects(:create_repository).with(options).once.returns("repository")
    assert_equal "repository", EsSnapshot.create_s3_respository(client, snapshot_name)
  end

  def test_create
    Timecop.freeze("2018-03-08") do
      modify_const("ALLOWED_ENVIRONMENTS", ["test"], EsSnapshot) do
        snapshot_name = "es-snapshot-test-2018-03-08_00:00:00"
        client = ElasticsearchReindexing.configure_client

        client.snapshot.expects(:create).with(repository: "s3-repo", snapshot: snapshot_name).once
        ElasticsearchReindexing.expects(:configure_client).once.returns(client)
        EsSnapshot.expects(:flush_aws_dj_entries).once
        EsSnapshot.expects(:create_s3_respository).with(client, snapshot_name).once
        EsSnapshot.create
      end
    end
  end

  def test_create_when_env_not_allowed
    ElasticsearchReindexing.expects(:configure_client).never
    EsSnapshot.expects(:create_s3_respository).never
    EsSnapshot.expects(:flush_aws_dj_entries).once
    EsSnapshot.create
  end

  def test_restore
    modify_const("ALLOWED_ENVIRONMENTS", ["test"], EsSnapshot) do
      snapshot_name = "es-snapshot-test-2018-03-08_00:00:00"
      client = ElasticsearchReindexing.configure_client

      client.indices.expects(:delete).with(has_key(:index)).once
      client.snapshot.expects(:restore).with(repository: "s3-repo", snapshot: snapshot_name).once
      ElasticsearchReindexing.expects(:configure_client).once.returns(client)
      EsSnapshot.expects(:create_s3_respository).with(client, snapshot_name).once
      EsSnapshot.expects(:run_delta_jobs_in_aws_dj_queue).once
      EsSnapshot.restore(snapshot_name)
    end
  end

  def test_restore_when_env_not_allowed
    ElasticsearchReindexing.expects(:configure_client).never
    EsSnapshot.expects(:create_s3_respository).never
    EsSnapshot.expects(:run_delta_jobs_in_aws_dj_queue).once
    EsSnapshot.restore("es-snapshot-test-2018-03-08_00:00:00")
  end

  def test_restore_when_snapshot_name_not_specified
    modify_const("ALLOWED_ENVIRONMENTS", ["test"], EsSnapshot) do
      ElasticsearchReindexing.expects(:configure_client).never
      EsSnapshot.expects(:create_s3_respository).never
      EsSnapshot.expects(:run_delta_jobs_in_aws_dj_queue).never
      e = assert_raise RuntimeError do
        EsSnapshot.restore(nil)
      end
      assert_equal "SNAPSHOT_NAME is not specified", e.message
    end
  end

  def test_check_status
    snapshot_name = "es-snapshot-test-2018-03-08_00:00:00"
    client = ElasticsearchReindexing.configure_client

    client.snapshot.expects(:status).with(repository: "s3-repo", snapshot: snapshot_name, human: true)
    ElasticsearchReindexing.expects(:configure_client).once.returns(client)
    EsSnapshot.check_status(snapshot_name)
  end

  def test_check_status_when_snapshot_name_not_specified
    ElasticsearchReindexing.expects(:configure_client).never
    e = assert_raise RuntimeError do
      EsSnapshot.check_status(nil)
    end
    assert_equal "SNAPSHOT_NAME is not specified", e.message
  end
end