require_relative './../../../test_helper.rb'

class SearchableTest < ActiveSupport::TestCase
  def test_index_name
    assert_equal "location-test"+ENV['TEST_ENV_NUMBER'].to_s, Location.index_name
  end

  def test_after_create
    location_id = ActiveRecord::Base.connection.execute("SELECT auto_increment FROM information_schema.tables WHERE table_schema = '#{Rails.configuration.database_configuration[Rails.env]["database"]}' AND table_name = '#{Location.table_name}'").first[0]
    Delayed::Job.stubs(:enqueue).with(ElasticsearchIndexerJob.new(Location, location_id, :index_es_document, nil, []), {queue: 'es_delta'}).at_least(1).returns(true)
    Delayed::Job.stubs(:enqueue).with(ElasticsearchIndexerJob.new(Location, location_id, :index_es_document, nil, []), {:queue => DjQueues::AWS_ELASTICSEARCH_SERVICE}).at_least(1).returns(true)
    Location.create!(full_address: "Random address 1")
  end

  def test_after_update
    Location.any_instance.stubs(:index_es_document).returns(true)
    sfs = Location.create!(full_address: "Random address 2")
    Delayed::Job.stubs(:enqueue).with(ElasticsearchIndexerJob.new(Location, sfs.id, :update_es_document, nil, []), {queue: 'es_delta'}).at_least(1).returns(true)
    Delayed::Job.stubs(:enqueue).with(ElasticsearchIndexerJob.new(Location, sfs.id, :update_es_document, nil, []), {:queue => DjQueues::AWS_ELASTICSEARCH_SERVICE}).at_least(1).returns(true)
    sfs.update_attributes(full_address: "2")
  end

  def test_after_destroy
    Location.any_instance.stubs(:index_es_document).returns(true)
    sfs = Location.create!(full_address: "Random address 3")
    Delayed::Job.stubs(:enqueue).with(ElasticsearchIndexerJob.new(Location, sfs.id, :delete_es_document, nil, []), {queue: 'es_delta'}).at_least(1).returns(true)
    Delayed::Job.stubs(:enqueue).with(ElasticsearchIndexerJob.new(Location, sfs.id, :delete_es_document, nil, []), {:queue => DjQueues::AWS_ELASTICSEARCH_SERVICE}).at_least(1).returns(true)
    sfs.destroy
  end

  def test_chronus_elasticsearch
    ChronusElasticsearch.client.stubs(:search).with(index: "location-test"+ENV['TEST_ENV_NUMBER'].to_s, body: "body").returns(true)
    Location.chronus_elasticsearch("body")
  end

  def test_esearch
    Location.__elasticsearch__.stubs(:search).with("query").returns(true)
    Location.esearch("query")
  end

  def test_eimport
    Location.__elasticsearch__.expects(:import).returns(true)
    Location.eimport
  end

  def test_force_create_ex_index
    ElasticsearchReindexing.stubs(:create_individual_alias).returns(true)
    Location.__elasticsearch__.expects(:create_index!).once.with(index: "location-test#{ENV['TEST_ENV_NUMBER']}-v1", force: true)
    Location.force_create_ex_index
  end

  def test_refresh_es_index
    Location.__elasticsearch__.stubs(:refresh_index!).returns(true)
    Location.refresh_es_index
  end

  def test_as_partial_indexed_json
    expected_hash = {"id" => locations(:chennai).id, "full_address_db"=>"Chennai, Tamil Nadu, India"}
    assert_equal expected_hash, locations(:chennai).as_partial_indexed_json([:id, :full_address_db])

    expected_hash = {"id" => articles(:economy).id, "role_ids"=>programs(:albers).role_ids, "publications"=>[{"program_id"=>programs(:albers).id}]}
    assert_equal expected_hash, articles(:economy).as_partial_indexed_json([:id, :role_ids, :publications])
  end
end