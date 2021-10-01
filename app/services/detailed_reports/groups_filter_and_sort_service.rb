class DetailedReports::GroupsFilterAndSortService
  DEFULT_PAGE_SIZE = 10
  DEFAULT_PAGE_NUMBER = 1
  DEFAULT_SORT_FIELD = 'name'
  DEFAULT_SORT_ORDER = 'asc'

  module Sort
    module Field
      NAME = 'name'
      MENTORS = 'mentors'
      STUDENTS = 'students'
      STARTED_ON = 'started_on'
    end

    MAP = {
      Field::NAME => 'name.sort',
      Field::MENTORS => 'mentors.name_only.sort',
      Field::STUDENTS => 'students.name_only.sort',
      Field::STARTED_ON => 'published_at'
    }
  end

  module CurrentStatus
    ONGOING = 'ongoing'
    COMPLETED = 'completed'
    DISCARDED = 'discarded'
  end

  def initialize(program, group_ids, options)
    @program = program
    page_size = (options[:page_size] || DEFULT_PAGE_SIZE).to_i
    page_number = (options[:page_number] || DEFAULT_PAGE_NUMBER).to_i
    sort_field = Sort::MAP[options[:sort_field] || DEFAULT_SORT_FIELD]
    sort_order = options[:sort_type] || DEFAULT_SORT_ORDER

    @sphinx_params = {
      page: page_number,
      per_page: page_size,
      includes_list: [{:mentors => :member}, {:students => :member}, :closure_reason, :mentoring_model],
      sort: { sort_field => sort_order }
    }.merge!(get_with_options(group_ids, options[:filter]))
  end

  def groups
    Group.get_filtered_groups(@sphinx_params)
  end

  private

  def get_with_options(group_ids, filter_options)
    es_options = {}
    es_options[:must_filters] = {:id => group_ids.present? ? group_ids : [0]}
    if filter_options && filter_options[:current_status]
      if filter_options[:current_status] == CurrentStatus::ONGOING
        es_options[:must_filters].merge!(:status => [Group::Status::ACTIVE, Group::Status::INACTIVE])
      else
        es_options[:must_filters].merge!(:status => [Group::Status::CLOSED])
        closure_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
        if filter_options[:current_status] == CurrentStatus::COMPLETED
          es_options[:must_filters].merge!(:closure_reason_id => closure_reason_ids)
        else
          es_options[:must_not_filters] = {:closure_reason_id => closure_reason_ids}
        end
      end
    end
    return es_options
  end
end