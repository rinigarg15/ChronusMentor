module UserElasticsearchQueries
  extend ActiveSupport::Concern

  MATCH_FIELDS = ["name_only", "last_name", "first_name", "name_only.sort", "member.location_answer.location.full_address", "profile_answer_text.language_*", "last_name.sort", "first_name.sort"]

  module ClassMethods
    include QueryHelper
    include EsComplexQueries

    # Users who were active at any point during the given timeframe
    def get_ids_of_users_active_between(program, start_time, end_time, options = {})
      NestedEsQuery::ActiveUsers.new(program, start_time, end_time, options).get_filtered_ids
    end

    # Users who were active and connected at any point during the given timeframe
    def get_ids_of_connected_users_active_between(program, start_time, end_time, options = {})
      NestedEsQuery::ActiveConnectedUsers.new(program, start_time, end_time, options).get_filtered_ids
    end

    # Users who weren't active or didn't have the specified role(s) at start_time
    # but become active and have the specified role(s) at end_time
    def get_ids_of_new_active_users(program, start_time, end_time, options = {})
      NestedEsQuery::NewRoleStateUsers.new(program, start_time, end_time, options.merge(include_new_role_users: true)).get_filtered_ids
    end

    # Users who weren't suspended or didn't have the specified role(s) at start_time
    # but become suspended and have the specified role(s) at end_time
    def get_ids_of_new_suspended_users(program, start_time, end_time, options = {})
      NestedEsQuery::NewRoleStateUsers.new(program, start_time, end_time, options.merge(user_status: User::Status::SUSPENDED)).get_filtered_ids
    end

    def get_availability_slots_for(user_ids)
      get_filtered_users(nil, with: { id: user_ids }, source_columns: [:id, :availability]).to_a.map { |user| [user.id.to_i, user.availability] }.to_h
    end

    def get_filtered_users(search_query, options = {})
      es_query = construct_filtered_users_es_query(search_query, options)
      query_options = get_query_options(options)

      if options[:source_columns].present? && options[:source_columns] == [:id]
        common_chronus_elasticsearch_query_executor(es_query, query_options)
      elsif options[:source_columns].present?
        common_esearch_query_executor_extract_source(es_query, query_options)
      else
        common_esearch_query_executor_collect_records(es_query, query_options)
      end
    end

    private

    def construct_filtered_users_es_query(search_query, options)
      es_query = get_search_query(search_query, options[:match_fields], options)
      must_terms = get_must_terms(options)
      must_not_terms = QueryHelper::Filter.get_filter_conditions(options[:without] || [])
      if options[:explicit_preference].present?
        must_terms += update_filtered_users_es_query_and_return_additional_must_terms_for_explicit_preferences(es_query, search_query, options)
      end
      es_query[:bool].merge!(filter: QueryHelper::Filter.simple_bool_filter(must_terms, must_not_terms))
      return es_query
    end

    def update_filtered_users_es_query_and_return_additional_must_terms_for_explicit_preferences(es_query, search_query, options)
      # If search query is present we should score/sort it based on that else use explicit preference
      additional_must_terms = []
      if !search_query.present? || options[:sort_by_explicit_preference]
        additional_must_terms << es_query[:bool][:must] if es_query[:bool][:must].present?
        es_query[:bool].merge!({must: options[:explicit_preference]})
      else
        additional_must_terms << options[:explicit_preference]
      end
      return additional_must_terms
    end

    def get_search_query(search_query, match_fields, options = {})
      match_fields = UserElasticsearchQueries::MATCH_FIELDS if match_fields.blank?
      return { bool: {} } if search_query.blank?

      if options[:apply_boost]
        return get_boosted_search_query(search_query, options)
      elsif match_fields.present?
        return QueryHelper::Filter.simple_bool_filter(QueryHelper::Filter.get_multi_match_query(match_fields, search_query, operator: options[:search_operator]), {})
      end
      { bool: {} }
    end
  end

  def get_explicit_user_preferences_should_query
    should_query = []
    explicit_user_preferences.includes(:question_choices, role_question: :profile_question).each do |preference|
      location_preference_string = preference.preference_string
      if !preference.role_question.profile_question.location?
        should_query << {constant_score: {filter: {terms: {profile_answer_choices: preference.question_choices.collect(&:id)}}, boost: preference.preference_weight}}
      else
        should_query << {constant_score: {filter: QueryHelper::Filter.get_match_phrase_query("member.location_answer.location.full_location", location_preference_string), boost: preference.preference_weight}}
      end
    end
    return QueryHelper::Filter.simple_bool_should(should_query)
  end

end