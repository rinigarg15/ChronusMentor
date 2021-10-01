module DigestCalculator
  # :paths are keys in ChronusMentorBase::Application.config.paths
  # :locations can be files or folders
  DataFolder = {
    "MYSQL"   => {:paths => ["db/migrate"], :locations => ["config/database.yml"]},
    "ESINDEX" => {:paths => [], :locations => ["config/elasticsearch_settings.yml"]}
  }

  ES_INDEXES_PATH = "lib/elasticsearch/settings"

  extend self

  def convert_to_yaml(filename, content)
    File.open(File.join(Rails.root.to_s, filename), 'w') {|f| f.write content.to_yaml }
  end

  def get_md5sum(content)
    Digest::MD5.hexdigest(content)
  end

  def compute_overall_digest
    data_manifest = DataFolder.inject({}) do |manifest, (datatype,pls)|
      locations = []
      paths = pls[:paths] || []
      locations += paths.collect{|path| ChronusMentorBase::Application.config.paths[path]}.flatten
      locations += (pls[:locations] || [])
      manifest[datatype] = get_md5sum(`find #{locations.join(" ")} -type f | sort -u | xargs cat`)
      manifest
    end

    convert_to_yaml("data_digest.yml", data_manifest)
    data_manifest
  end

  def compute_es_indexes_digest_of_versions
    manifest = {}
    ChronusElasticsearch.models_with_es.each do |model|
      manifest[model.name] = model.const_get("REINDEX_VERSION") if model.const_defined?("REINDEX_VERSION")
    end
    convert_to_yaml("es_indexes_digest.yml", manifest)
    manifest
  end
end