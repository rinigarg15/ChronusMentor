#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module UserStateChangeElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings do
      mappings do
        indexes :id, type: 'integer'
        indexes :user_id, type: 'integer'
        indexes :date_id, type: 'integer'
        indexes :from_state, type: 'keyword'
        indexes :to_state, type: 'keyword'
        indexes :from_roles
        indexes :to_roles
        indexes :connection_membership_from_roles
        indexes :connection_membership_to_roles
        indexes :user do
          indexes :program_id, type: 'integer'
        end
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(options={})
      # Not adding callback on user as program_id is not going to be updated
      self.as_json(indexes)
    end

    # indexes is a hash which can consists of keys :only, :methods, :include
    # always provide array to :only and :methods
    # always provide hash to :include
    def indexes
      {
        only: [:id, :user_id, :date_id, :created_at, :updated_at],
        include: { user: {only: :program_id}},
        methods: [:from_state, :to_state, :from_roles, :to_roles, :connection_membership_from_roles, :connection_membership_to_roles]
      }
    end
  end
end