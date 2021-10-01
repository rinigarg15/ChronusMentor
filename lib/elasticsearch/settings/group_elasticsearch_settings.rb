#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module GroupElasticsearchSettings
  REINDEX_VERSION = 2
  extend ActiveSupport::Concern

  included do
    include Searchable
    INDEX_FIELDS = ['name', 'mentors.name_only', 'students.name_only', 'name.sort']

    settings ElasticsearchConstants::STOPWORDS_ANALYZER_SETTINGS.deep_merge(ElasticsearchConstants::AUTOCOMPLETE_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS })).deep_merge(ElasticsearchConstants::SORTABLE_ANALYZER_SETTINGS) do
      mappings dynamic_templates: ElasticsearchConstants::GROUP_DYNAMIC_TEMPLATES do
        indexes :id, type: 'integer'
        indexes :program_id, type: 'integer'
        indexes :status, type: 'byte'
        indexes :group_status, type: 'integer' # Global search has a search based on group's status. We can't generically search on status since all the other global search indices have status field.
        indexes :closure_reason_id, type: 'integer'
        indexes :name, type: 'text', analyzer: 'stopwords', fields: {sort: {type: 'text', analyzer: "sortable", fielddata: true}, autocomplete: {type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer'}, keyword: {type: 'text', analyzer: 'sortable'}}
        indexes :role_ids, type: 'integer'
        indexes :expiry_time, type: 'date'
        indexes :last_activity_at, type: 'date'
        indexes :last_member_activity_at, type: 'date'
        indexes :global, type: 'boolean'
        indexes :published_at, type: 'date'
        indexes :pending_at, type: 'date'
        indexes :created_at, type: 'date'
        indexes :closed_at, type: 'date'
        indexes :start_date, type: 'date'
        indexes :mentoring_model_id, type: 'integer'
        indexes :has_overdue_tasks, type: 'boolean'
        indexes :pending_project_requests_count, type: 'integer'
        indexes :activity_count, type: 'integer'
        indexes :membership_setting_total_slots, type: 'object'
        indexes :membership_setting_slots_taken, type: 'object'
        indexes :membership_setting_slots_remaining, type: 'object'
        indexes :meetings_activity_for_all_roles, type: 'object'
        indexes :get_rolewise_login_activity_for_group, type: 'object'
        indexes :get_rolewise_messages_activity_for_group, type: 'object'
        indexes :get_rolewise_posts_activity_for_group, type: 'object'
        indexes :role_users_full_name, type: 'object'
        indexes :tasks_overdue_count, type: 'integer'
        indexes :tasks_pending_count, type: 'integer'
        indexes :tasks_completed_count, type: 'integer'
        indexes :milestones_overdue_count, type: 'integer'
        indexes :milestones_pending_count, type: 'integer'
        indexes :milestones_completed_count, type: 'integer'
        indexes :survey_responses_count, type: 'integer'
        indexes :mentors do
          indexes :name_only, type: 'text', analyzer: 'standard', fields: { sort: {type: 'text', analyzer: "sortable", fielddata: true} }
        end
        indexes :students do
          indexes :name_only, type: 'text', analyzer: 'standard', fields: { sort: {type: 'text', analyzer: "sortable", fielddata: true} }
        end
        # members here are actually users
        indexes :members do
          indexes :id, type: 'integer'
          indexes :name_only, type: 'text', analyzer: 'standard'
        end
        indexes :created_by do
          indexes :name_only, type: 'text', analyzer: 'standard', fields: { sort: {type: 'text', analyzer: "sortable", fielddata: true} }
        end
        indexes :closed_by do
          indexes :name_only, type: 'text', analyzer: 'standard', fields: { sort: {type: 'text', analyzer: "sortable", fielddata: true} }
        end
        indexes :state_changes, type: 'nested' do
          indexes :id, type: 'integer'
          indexes :date_id, type: 'integer'
          indexes :from_state, type: 'byte'
          indexes :to_state, type: 'byte'
        end
        indexes :mentoring_model do
          indexes :title, type: 'text', analyzer: 'standard', fields: { sort: {type: 'text', analyzer: "sortable", fielddata: true} }
        end
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(options={})
      self.as_json(indexes)
    end

    # indexes is a hash which can consists of keys :only, :methods, :include
    # always provide array to :only and :methods
    # always provide hash to :include
    def indexes
      {
        only: [:id, :program_id, :status, :closure_reason_id, :name, :expiry_time, :last_activity_at, :last_member_activity_at, :global, :published_at, :pending_at, :created_at, :closed_at, :mentoring_model_id, :start_date],
        methods: [:role_ids, :has_overdue_tasks, :pending_project_requests_count, :activity_count, :membership_setting_total_slots, :membership_setting_slots_taken, :membership_setting_slots_remaining, :role_users_full_name, :group_status, :tasks_overdue_count, :tasks_pending_count, :tasks_completed_count, :milestones_overdue_count, :milestones_pending_count, :milestones_completed_count, :meetings_activity_for_all_roles, :get_rolewise_login_activity_for_group, :get_rolewise_messages_activity_for_group, :get_rolewise_posts_activity_for_group, :survey_responses_count],
        include: {
          state_changes: { only: [:id, :date_id, :from_state, :to_state] },
          mentors: { only: [], methods: [:name_only] },
          students: { only: [], methods: [:name_only] },
          members: { only: [:id], methods: [:name_only] },
          created_by: {only: [], methods: [:name_only]},
          closed_by: {only: [], methods: [:name_only]},
          mentoring_model: {only: [:title], methods: []}
        }
      }
    end

    def group_status
      self.status
    end

    def tasks_overdue_count
      @overdue_tasks_for_es ||= MentoringModel::Task.get_overdue_tasks(mentoring_model_tasks)
      @overdue_tasks_for_es.size
    end

    def tasks_pending_count
      @pending_tasks_for_es ||= MentoringModel::Task.get_pending_tasks(mentoring_model_tasks)
      @pending_tasks_for_es.size
    end

    def tasks_completed_count
      @completed_tasks_for_es ||= MentoringModel::Task.get_complete_tasks(mentoring_model_tasks)
      @completed_tasks_for_es.size
    end

    def milestones_overdue_count
      @overdue_tasks_for_es ||= MentoringModel::Task.get_overdue_tasks(mentoring_model_tasks)
      @overdue_tasks_for_es.select(&:required?).collect(&:milestone_id).compact.uniq.size
    end

    def milestones_pending_count
      @pending_tasks_for_es ||= MentoringModel::Task.get_pending_tasks(mentoring_model_tasks)
      @overdue_tasks_for_es ||= MentoringModel::Task.get_overdue_tasks(mentoring_model_tasks)
      (@pending_tasks_for_es.select(&:required?).collect(&:milestone_id).compact.uniq - @overdue_tasks_for_es.select(&:required?).collect(&:milestone_id).compact.uniq).size
    end

    def milestones_completed_count
      (mentoring_model_milestones.collect(&:id) - mentoring_model_tasks.select(&:todo?).select(&:required?).collect(&:milestone_id).compact.uniq).size
    end

    def survey_responses_count
      unique_survey_answers(false, nil, skip_select: true).count
    end
  end
end
