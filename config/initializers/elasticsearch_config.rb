require 'faraday_middleware/aws_signers_v4'
ES_CONFIG ||= YAML::load(ERB.new(File.read("#{Rails.root}/config/elasticsearch_settings.yml")).result)[Rails.env].symbolize_keys
ES_INDEX_SUFFIX = ES_CONFIG[:index_suffix]
ChronusElasticsearch.skip_es_index = Rails.env.test?

Elasticsearch::Model.settings[:inheritance_enabled] = true

if ENV['TDDIUM']
  ES_CONFIG[:host] = ENV['TDDIUM_ES_HOST']
  ES_CONFIG[:port] = ENV['TDDIUM_ES_HTTP_PORT']
end

if Rails.env.test? || Rails.env.development?
  ES_HOST_OPTIONS = { host: ES_CONFIG[:host], port: ES_CONFIG[:port], user: ES_CONFIG[:user], password: ES_CONFIG[:password], scheme: ES_CONFIG[:scheme] }
else
  AWS_ES_OPTIONS = { url: ES_CONFIG[:aws_es_endpoint], es_region: ES_CONFIG[:es_region], s3_bucket: ES_CONFIG[:s3_bucket], s3_region: ES_CONFIG[:s3_region], s3_access_role: ES_CONFIG[:s3_access_role], s3_repository: ES_CONFIG[:s3_repository] }
end

es_client = ElasticsearchReindexing.configure_client
Elasticsearch::Model.client = es_client
ChronusElasticsearch.client = es_client