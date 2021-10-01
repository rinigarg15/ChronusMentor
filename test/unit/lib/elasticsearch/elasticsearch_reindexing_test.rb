require_relative './../../../test_helper.rb'

class ElasticsearchReindexingTest < ActiveSupport::TestCase

  def test_configure_client_for_non_development_env
    Object.const_set("AWS_ES_OPTIONS", { url: "es-url", es_region: "es-region" } )
    Rails.env.stubs(:test?).returns(false)
    Rails.env.stubs(:development?).returns(false)

    Elasticsearch::Client.expects(:new).with(log: false, url: "es-url").once
    ElasticsearchReindexing.configure_client
    Object.send(:remove_const, "AWS_ES_OPTIONS")
  end

  def test_reindexing_models
    ElasticsearchReindexing.expects(:reindex_or_delete).with(["Group", "User"], "eimport").returns(true)
    ElasticsearchReindexing.reindexing_models(["Group", "User"])
  end

  def test_reindex_or_delete
    ElasticsearchReindexing.expects(:reindex_or_delete_indexes_individually).times(2)
    ElasticsearchReindexing.reindex_or_delete(["Group", "User"], "eimport")
  end

  def test_reindex_or_delete_indexes_individually_reindex
    ElasticsearchReindexing.stubs(:get_index_list).returns(["group-#{ES_INDEX_SUFFIX}"])
    ElasticsearchReindexing.stubs(:get_old_and_new_indexname).returns({ "new_index" => "group-#{ES_INDEX_SUFFIX}-v0", "old_index" => "group-#{ES_INDEX_SUFFIX}-v1"})
    Group.expects(:eimport).with(index_modified: "group-#{ES_INDEX_SUFFIX}-v0", parallel_processing: true, includes_list: '')
    ElasticsearchReindexing.instance_variable_set("@models_with_index_name", {"Group" => "group-#{ES_INDEX_SUFFIX}-v0"})
    ElasticsearchReindexing.reindex_or_delete_indexes_individually("Group", "", "eimport")
  end

  def test_reindex_or_delete_indexes_individually_delete
    ElasticsearchReindexing.stubs(:get_index_list).returns(["group-#{ES_INDEX_SUFFIX}", "user-#{ES_INDEX_SUFFIX}"])
    ElasticsearchReindexing.stubs(:get_old_and_new_indexname).returns({ "new_index" => "group-#{ES_INDEX_SUFFIX}-v0", "old_index" => "group-#{ES_INDEX_SUFFIX}-v1"})
    ElasticsearchReindexing.stubs(:get_list_of_indexes).returns(["group-#{ES_INDEX_SUFFIX}-v0", "user-#{ES_INDEX_SUFFIX}-v0"])
    Group.expects(:delete_indexes).with(index_modified: "group-#{ES_INDEX_SUFFIX}-v0")
    ElasticsearchReindexing.instance_variable_set("@models_with_index_name", {"Group" => "group-#{ES_INDEX_SUFFIX}-v0"})
    ElasticsearchReindexing.reindex_or_delete_indexes_individually("Group", "", "delete_indexes")
  end

  def test_reindex_or_delete_indexes_individually_new_index
    ElasticsearchReindexing.stubs(:get_index_list).returns([])
    ElasticsearchReindexing.expects(:create_index_and_alias).with("Group", "", "eimport")
    ElasticsearchReindexing.instance_variable_set("@models_with_index_name", {"Group" => "group-#{ES_INDEX_SUFFIX}-v0"})
    ElasticsearchReindexing.reindex_or_delete_indexes_individually("Group", "", "eimport")
  end

  def test_exists_alias
    assert_equal true, ElasticsearchReindexing.exists_alias?("User")
    assert_equal false, ElasticsearchReindexing.exists_alias?("testing_12345")
  end

  def test_get_index_list
    ElasticsearchReindexing.stubs(:get_list_of_indexes).returns(["group_state_change-#{ES_INDEX_SUFFIX}-v0","user-#{ES_INDEX_SUFFIX}-v1"])
    assert_equal ["group_state_change-#{ES_INDEX_SUFFIX}","user-#{ES_INDEX_SUFFIX}"], ElasticsearchReindexing.get_index_list
  end

  def test_create_index_and_alias
    Group.expects(:eimport).with(index_modified: "group-#{ES_INDEX_SUFFIX}-v1", parallel_processing: true, includes_list: '')
    ElasticsearchReindexing.instance_variable_set("@models_with_index_name", {})
    ElasticsearchReindexing.instance_variable_set("@new_index_list", [])

    ElasticsearchReindexing.expects(:create_individual_alias).with("group-#{ES_INDEX_SUFFIX}")
    ElasticsearchReindexing.create_index_and_alias("Group", "", "eimport")
  end

  def test_flip_indexes
    ElasticsearchReindexing.expects(:atomic_update_alias).times(2)
    ElasticsearchReindexing.stubs(:get_index_alias_details).returns({})
    ElasticsearchReindexing.stubs(:get_list_of_indexes).returns(["user-#{ES_INDEX_SUFFIX}-v1", "user-#{ES_INDEX_SUFFIX}-v0", "group-#{ES_INDEX_SUFFIX}-v0", "group-#{ES_INDEX_SUFFIX}-v1"])
    ElasticsearchReindexing.flip_indexes(["Group", "User"])
  end

  def test_verify_es_document_count_for_flipping_with_new_index
    Location.update_all(created_at: 1.week.ago.utc)
    ElasticsearchReindexing.instance_variable_set("@models_with_index_name", {})
    ElasticsearchReindexing.instance_variable_set("@new_index_list", [])
    reindex_documents(deleted: Location.reliable.to_a)
    ElasticsearchReindexing.stubs(:current_indexing_models).returns([Location.name])
    ElasticsearchReindexing.stubs(:get_list_of_indexes).returns([Location.index_name])
    ElasticsearchReindexing.stubs(:get_old_and_new_indexname).returns({"new_index" => Location.index_name})
    Airbrake.expects(:notify).once
    e = assert_raise RuntimeError do
      ElasticsearchReindexing.verify_es_document_count!(["Location"])
      expected_hash = {"Location" => Location.index_name}
      assert_equal expected_hash, ElasticsearchReindexing.instance_variable_get("@models_with_index_name")
      assert_equal [Location.index_name], ElasticsearchReindexing.instance_variable_get("@new_index_list")
    end
    assert_equal "Elasticsearch document count mismatched models: [\"Location\"]", e.message
  end

  def test_verify_es_document_count_for_flipping_with_old_index
    Location.update_all(created_at: 1.week.ago.utc)
    reindex_documents(deleted: Location.reliable.to_a)
    ElasticsearchReindexing.instance_variable_set("@models_with_index_name", {})
    ElasticsearchReindexing.instance_variable_set("@new_index_list", [])
    ElasticsearchReindexing.stubs(:current_indexing_models).returns([Location.name])
    ElasticsearchReindexing.stubs(:get_list_of_indexes).returns([Location.index_name])
    ElasticsearchReindexing.stubs(:get_old_and_new_indexname).returns({"old_index" => Location.index_name})
    Airbrake.expects(:notify).once
    e = assert_raise RuntimeError do
      ElasticsearchReindexing.verify_es_document_count!(["Location"])
      expected_hash = {"Location" => Location.index_name}
      assert_equal expected_hash, ElasticsearchReindexing.instance_variable_get("@models_with_index_name")
      assert_equal [Location.index_name], ElasticsearchReindexing.instance_variable_get("@new_index_list")
    end
    assert_equal "Elasticsearch document count mismatched models: [\"Location\"]", e.message
  end

  def test_verify_es_document_count_for_flipping_with_new_and_old_index
    reindex_documents(deleted: Location.reliable.to_a)
    ElasticsearchReindexing.instance_variable_set("@models_with_index_name", {})
    ElasticsearchReindexing.instance_variable_set("@new_index_list", [])
    ElasticsearchReindexing.stubs(:current_indexing_models).returns([Location.name])
    ElasticsearchReindexing.stubs(:get_list_of_indexes).returns([Location.index_name])
    ElasticsearchReindexing.stubs(:get_old_and_new_indexname).returns({"old_index" => Location.index_name, "new_index" => Location.index_name})
    Airbrake.expects(:notify).once
    e = assert_raise RuntimeError do
      ElasticsearchReindexing.verify_es_document_count!(["Location"])
      expected_hash = {"Location" => Location.index_name}
      assert_equal expected_hash, ElasticsearchReindexing.instance_variable_get("@models_with_index_name")
      assert_empty ElasticsearchReindexing.instance_variable_get("@new_index_list")
    end
    assert_equal "Elasticsearch document count mismatched models: [\"Location\"]", e.message
  end
end