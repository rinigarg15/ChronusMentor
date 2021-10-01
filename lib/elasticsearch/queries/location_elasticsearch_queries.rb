module LocationElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_list_of_autocompleted_locations(location_name)
      return [] if location_name.blank?
      es_query = QueryHelper::Filter.get_match_query("full_address", location_name)
      options = {}
      options[:sort] = ["_score", {profile_answers_count: ElasticsearchConstants::SortOrder::DESC }]
      options[:source] = ["full_address_db"]
      options[:size] = LocationElasticsearchSettings::AUTOCOMPLETE_LIMIT
      results = common_esearch_query_executor_extract_source(es_query, options)
      results.collect(&:full_address_db).uniq
    end

    def get_filtered_list_of_autocompleted_locations(location_name, member)
      if location_name.blank?
        return member.location.present? ? [member.location.full_city, member.location.full_state].compact : []
      end
      return [] if location_name.length < Location::LocationFilter::MINIMUM_CHARACTERS_FOR_AUTOCOMPLETE
      results = []
      Location::LocationFilter.indexed_fields.each do |es_field|
        es_query = QueryHelper::Filter.get_match_phrase_prefix_query(es_field, location_name)
        aggs = build_aggregations(es_field)
        results += get_keys_from_aggregated_data(common_esearch_query_executor_with_aggregations(es_query, aggs, size: 0))
      end
      prioritise_location_results(location_name, results.uniq)
    end

    private

    def build_aggregations(field)
      {
        group_by_location: {
          terms: {
            field: get_field_as_keyword(field),
            size: Location::LocationFilter::MAXIMUM_RESULTS_FOR_LOCATION[field],
            order: {
              "sum_count_answers": ElasticsearchConstants::SortOrder::DESC
            }
          },
          aggs: {
            sum_count_answers: {
              sum: {
                field: "profile_answers_count"
              }
            }
          }
        }
      }
    end

    def get_field_as_keyword(field)
      field + ".keyword"
    end

    def get_keys_from_aggregated_data(data)
      data.response.aggregations.group_by_location.buckets.map{|k| k[:key]}
    end

    def prioritise_location_results(location_name, results)
      location_name_downcase = UnicodeUtils.downcase(location_name.split(" ").first.to_s)
      prioritised_results = results.select{|s| !s.downcase.match(/^#{location_name_downcase}/).nil? || s.downcase.match(/,.*#{location_name_downcase}/).nil?}
      prioritised_results + (results - prioritised_results)
    end
  end
end