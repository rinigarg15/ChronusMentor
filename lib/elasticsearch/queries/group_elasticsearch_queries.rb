module GroupElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper
    include EsComplexQueries

    # Groups which were active at any point during the given timeframe
    def get_ids_of_groups_active_between(program, start_time, end_time, options = {})
      NestedEsQuery::ActiveGroups.new(program, start_time, end_time, options).get_filtered_ids
    end

    def get_filtered_group_ids(es_options = {})
      get_filtered_ids(es_options)
    end

    def get_filtered_groups(es_options = {})
      get_filtered_objects(es_options)
    end

    def get_filtered_groups_count(es_options = {})
      get_filtered_count(es_options)
    end

    # Grouped filters
    def group_not_started
      { activity_count: 0, status: GroupsController::StatusFilters::MAP[GroupsController::StatusFilters::Code::ONGOING] }
    end

    def group_started_active
      { activity_count: { gt: 0 }, status: Group::Status::ACTIVE }
    end

    def group_started_inactive
      { activity_count: { gt: 0 }, status: Group::Status::INACTIVE }
    end

    def group_draft
      { status: Group::Status::DRAFTED }
    end
  end
end