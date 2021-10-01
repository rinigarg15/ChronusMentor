module MentorRecommendationElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper
    include EsComplexQueries
  end
end