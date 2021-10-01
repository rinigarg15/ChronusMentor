module ForumExtensions
  include ConnectionFilters::CommonInclusions

  def self.included(controller)
    controller.extend CommonExtensions
    controller.send :include, CommonInclusions
  end

  module CommonExtensions
    def group_forum_extensions(non_listing_actions = [], additional_listing_actions = [])
      listing_actions = [:show]
      listing_actions += additional_listing_actions
      all_actions = listing_actions + non_listing_actions

      before_action :add_group_id_to_params, only: all_actions, if: :check_group_forum
      before_action :fetch_group, :fetch_current_connection_membership, only: all_actions, if: :check_group_forum

      allow exec: :check_member_or_admin, only: listing_actions, if: :check_group_forum
      allow exec: :check_group_open,  only: non_listing_actions, if: Proc.new { check_group_forum && non_listing_actions.present? }
      allow exec: :check_action_access, only: non_listing_actions, if: Proc.new { check_group_forum && non_listing_actions.present? }
      allow exec: :can_access_mentoring_area?, only: listing_actions, if: :associated_group_active?
      before_action :set_src, only: listing_actions, if: :associated_group_pending?
      before_action :set_from_find_new, only: listing_actions, if: :associated_group_pending?
      before_action :set_group_profile_view, only: listing_actions, if: :associated_group_pending?
      before_action :prepare_template, only: listing_actions, if: :check_group_forum
      before_action :update_login_count, only: listing_actions, if: :associated_group_active?
      after_action :update_last_visited_tab, only: listing_actions, if: :associated_group_active?
    end
  end

  module CommonInclusions
    def authorize_user
      @forum.can_be_accessed_by?(current_user, :read_only)
    end

    def check_group_forum
      @forum.is_group_forum?
    end

    def associated_group_pending?
      check_group_forum && @forum.group.pending?
    end

    def associated_group_active?
      check_group_forum && @forum.group.active?
    end

    def check_program_forum
      @forum.is_program_forum?
    end

    def check_forum_feature
      @current_program.forums_enabled?
    end

    def add_group_id_to_params
      params[:group_id] = @forum.group_id
    end

    def fetch_posts
      post_includes = [:flags, { user: [:roles, { member: :profile_picture } ] } ]
      @sort_fields = CommonSortUtils.fill_user_sort_input_or_defaults!({}, params)
      sort_options = { @sort_fields[:sort_field].to_sym => @sort_fields[:sort_order].to_sym }

      posts_scope = current_user.can_manage_forums? ? @topic.posts : @topic.posts.published
      @posts = posts_scope.roots.order(sort_options).includes(post_includes)
    end

    def fetch_recent_topics
      topic_includes = [:forum, :recent_post, { user: [:roles, :member] } ]
      @recent_topics = @forum.topics.where.not(id: @topic.id).
        order(sticky_position: :desc, id: :desc).includes(topic_includes).limit(TopicsController::RECENT_TOPICS)
    end
  end
end