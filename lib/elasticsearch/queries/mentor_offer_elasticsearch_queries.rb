module MentorOfferElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_filtered_mentor_offers(action_params)
      filter_conditions = build_search_filters(action_params)
      es_query = { bool: {filter: QueryHelper::Filter.get_filter_conditions(filter_conditions)} }
      options = { source: ["id", "mentor_id", "student_id"] }
      common_esearch_query_executor_extract_source(es_query, options)
    end

    private

    def build_search_filters(action_params)
      status = action_params[:status] || MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING]

      search_filters = {
        program_id: action_params[:program_id],
        status: MentorOffer::Status::STRING_TO_STATE[status].to_s
      }
      search_filters
    end
  end
end