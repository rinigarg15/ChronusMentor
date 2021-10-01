class ElasticsearchDeploymentSettings
  # To facilitate delta indexing of records created during the elasticsearch full indexing.
  include Mongoid::Document
  # Name of the currently reindexing model
  field :reindexing_model, :type => String
  # Time when index creation starts
  field :index_start_time, :type => Time
  validates_presence_of :reindexing_model
end
