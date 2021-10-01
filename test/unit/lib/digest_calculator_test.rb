require_relative './../../test_helper.rb'

class CalculateDigestTest < ActiveSupport::TestCase
  include DigestCalculator

  def test_compute_es_indexes_digest_of_versions
    ChronusElasticsearch.stubs(:models_with_es).returns([User, UserStateChange, Group, GroupStateChange])
    models_with_es = ChronusElasticsearch.models_with_es
    DigestCalculator.expects(:convert_to_yaml).at_least_once.returns(true)
    manifest = DigestCalculator.compute_es_indexes_digest_of_versions
    assert_equal_unordered models_with_es.collect(&:name), manifest.keys
  end

  def test_md5_hash
    version1 = "common: &common\n  #Increment the reindex_version key by 1 if you want complete reindexing of elasticsearch\n  #THIS IS JUST A DUMMY KEY USED TO CHECK IF COMPLETE REINDEXING IS NEEDED OR NOT\n  reindex_version: 1\n  port: '9243'\n  user: 'readwrite'\n  password: <%= ENV['ELASTICSEARCH_PASSWORD'] %>\n  scheme: 'https'\n  index_suffix: <%= Rails.env %>"

    version2 = "common: &common\n  #Increment the reindex_version key by 1 if you want complete reindexing of elasticsearch\n  #THIS IS JUST A DUMMY KEY USED TO CHECK IF COMPLETE REINDEXING IS NEEDED OR NOT\n  reindex_version: 2\n  port: '9243'\n  user: 'readwrite'\n  password: <%= ENV['ELASTICSEARCH_PASSWORD'] %>\n  scheme: 'https'\n  index_suffix: <%= Rails.env %>"
    assert_not_equal get_md5sum(version1), get_md5sum(version2)
  end

  def test_if_version_constant_is_present_in_es_index_file
    ChronusElasticsearch.stubs(:models_with_es).returns([User, UserStateChange, Group, GroupStateChange])
    models_with_es = ChronusElasticsearch.models_with_es
    models_with_es.each do |model|
      assert model.const_defined?("REINDEX_VERSION")
    end
  end
end