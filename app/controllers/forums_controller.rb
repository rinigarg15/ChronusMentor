class ForumsController < ApplicationController
  include MentoringModelUtils
  include ForumExtensions

  before_action :fetch_forum, only: [:show, :update, :edit, :destroy, :subscription]
  before_action :add_custom_parameters_for_newrelic, only: [:index]

  allow exec: :authorize_user, only: [:show, :subscription]
  allow exec: :check_program_forum, only: [:edit, :update, :destroy, :subscription]
  allow exec: :check_forum_feature, only: [:index, :new, :create, :edit, :update, :destroy, :subscription]
  allow user: :can_manage_forums?, only: [:index, :new, :create, :edit, :update, :destroy]

  group_forum_extensions

  def show
    includes_list = [:forum, { user: [:member, :roles] }, :recent_post]
    @home_page = params[:home_page].to_s.to_boolean
    if @home_page
      @topics = fetch_topics(@forum, TopicsController::RECENT_TOPICS_HOMEPAGE)
      @group = @current_program.groups.find(params[:group_id])
    else
      @topics = @forum.topics
      @topics = @topics.where(id: params[:topic_ids]) if params[:search_view]
      @topics = @topics.order(sticky_position: :desc, id: :desc).includes(includes_list).paginate(page: params[:page])
    end
    @topic_id_to_view = params[:topic_id]
    @recent_topics = fetch_topics(@forum, TopicsController::RECENT_TOPICS) if @forum.is_program_forum?
  end

  def new
    @forum = @current_program.forums.new
  end

  def create
    @forum = @current_program.forums.build(forum_params)
    @forum.access_role_names = params[:forum][:access_role_names]
    if @forum.save
      flash[:notice] = "flash_message.forum_flash.f_created".translate
      redirect_to forums_path(filter: Forum::For::ALL)
    else
      render action: :new
    end
  end

  def edit
    render action: :new
  end

  def update
    @forum.assign_attributes(forum_params)
    if @forum.save
      flash[:notice] = "flash_message.forum_flash.f_updated".translate
      redirect_to forums_path(filter: Forum::For::ALL)
    else
      render action: :new
    end
  end

  def index
    @filter_field = params[:filter] || Forum::For::ALL
    @forums = @current_program.program_forums_with_role(@filter_field).sort_by { |f| -f[:id] }.paginate(page: params[:page], per_page: PER_PAGE)
    forum_ids = @forums.collect(&:id)
    @forum_subscriptions = Subscription.where(ref_obj_type: Forum.name).where(ref_obj_id: forum_ids).group('ref_obj_id').count("id")
    @forum_posts = Topic.where(forum_id: forum_ids).group(:forum_id).sum("posts_count")
  end

  def destroy
    @forum.destroy
    flash[:notice] = "flash_message.forum_flash.f_removed".translate
    redirect_to forums_path(filter: Forum::For::ALL)
  end

  def subscription
    if params[:subscribe] == "true"
      @forum.subscribe_user(current_user)
      flash[:notice] = "flash_message.forum_flash.subscription".translate(forum_name: @forum.name)
    elsif params[:subscribe] == "false"
      @forum.unsubscribe_user(current_user)
      @forum.topics.each do |topic|
        topic.unsubscribe_user(current_user) if topic.subscribed_by?(current_user)
      end
      flash[:notice] = "flash_message.forum_flash.unsubscription".translate(forum_name: @forum.name)
    end
    redirect_to @forum
  end

  protected

  def forum_params
    params.require(:forum).permit(Forum::MASS_UPDATE_ATTRIBUTES[params[:action].to_sym])
  end

  private

  def fetch_forum
    @forum = @current_program.forums.find(params[:id])
  end

  def fetch_topics(forum, count)
    arr1 = forum.topics.order(updated_at: :desc).limit(count)
    topic_ids = forum.topic_ids
    arr2 = Post.where(topic_id: topic_ids).distinct(:topic_id).order(created_at: :desc).limit(count).collect(&:topic)

    arr = arr1 + arr2
    arr.uniq!
    arr.sort_by!{|t| t.get_last_touched_time }
    return arr.reverse.first(count)
  end
end