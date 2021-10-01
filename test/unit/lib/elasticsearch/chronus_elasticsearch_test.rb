require_relative './../../../test_helper'

class ChronusElasticsearchTest < ActiveSupport::TestCase
  def test_models_with_es
    models_with_es = ChronusElasticsearch.models_with_es
    assert models_with_es.include?(GroupStateChange)
    assert models_with_es.include?(Group)
    assert models_with_es.include?(UserStateChange)
    assert models_with_es.include?(User)
  end

  def test_create_all_indexes
    GroupStateChange.stubs(:eimport).returns(true)
    UserStateChange.stubs(:eimport).returns(true)
    Group.stubs(:eimport).returns(true)
    User.stubs(:eimport).returns(true)
    ChronusElasticsearch.stubs(:models_with_es).returns([User, UserStateChange, Group, GroupStateChange])
    ElasticsearchReindexing.stubs(:verify_es_document_count!).returns(true)
    ChronusElasticsearch.create_all_indexes
  end
end