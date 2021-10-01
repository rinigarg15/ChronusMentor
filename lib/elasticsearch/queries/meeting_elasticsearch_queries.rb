module MeetingElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_meeting_ids_by_conditions(conditions)
      query = QueryHelper::Filter.simple_bool_filter({}, {})
      query[:bool].merge!({filter: QueryHelper::Filter.get_filter_conditions(conditions)})

      common_chronus_elasticsearch_query_executor(query)
    end

    def get_meeting_ids_by_topic(topic, conditions)
      match_query = {match: {"topic": QueryHelper::EsUtils.sanitize_es_query(topic)}}

      query = QueryHelper::Filter.simple_bool_filter(match_query, {})
      query[:bool].merge!({filter: QueryHelper::Filter.get_filter_conditions(conditions)})

      common_chronus_elasticsearch_query_executor(query)
    end

  end
end