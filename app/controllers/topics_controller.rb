class TopicsController < ApplicationController
  include MentoringModelUtils
  include ForumExtensions

  before_action :find_forum_and_topic
  before_action :redirect_if_no_topic, except: [:index, :create]

  allow exec: :authorize_user
  allow exec: :authorize_user_for_destroy, only: [:destroy]
  allow exec: :check_program_forum, only: [:set_sticky_position]
  allow user: :can_manage_forums?, only: [:set_sticky_position]

  group_forum_extensions([:create, :follow, :destroy], [:fetch_all_comments])

  RECENT_TOPICS =  5
  RECENT_TOPICS_HOMEPAGE = 2

  def index
    redirect_to @forum
  end

  def show
    fetch_posts
    fetch_recent_topics
    @topic.hit! if @topic.user != current_user
    track_activity_for_ei(EngagementIndex::Activity::READ_A_FORUM_POST, {context_object: @forum.is_group_forum? ? @group.name : @forum.name})
    @show_title = params[:show_title]
    @back_link = generate_back_link
    @home_page = params[:home_page].to_s.to_boolean
  end

  def create
    if request.xhr?
      @group_id = params[:group_id].to_i
    end
    @topic = @forum.topics.build(topic_params(:create))
    @topic.user = current_user
    assign_user_and_sanitization_version(@topic)
    if @topic.save
      flash[:notice] = "flash_message.forum_flash.conversation_created".translate unless request.xhr?
    else
      @error_message = "flash_message.forum_flash.conversation_created_failed".translate
      flash[:error] = @error_message unless request.xhr?
    end

    respond_to do |format|
      format.html {
        redirect_to @forum
      }
      format.js
    end
  end

  def follow
    if params[:subscribe] == "true"
      @topic.subscribe_user(current_user)
    else
      @topic.unsubscribe_user(current_user)
    end
    @topic.reload
  end

  def set_sticky_position
    @topic.sticky_position = params[:sticky_position].to_i if params[:sticky_position]
    @success = @topic.save!
  end

  def fetch_all_comments
    @root_post = @topic.posts.find_by(id: params[:root_id])
    comments, unmoderated_comments_count = @root_post.fetch_children_and_unmoderated_children_count(current_user)

    render json: {
      content: view_context.post_comments_container(@root_post, true),
      view_all_comments_label: view_context.view_all_comments_label(comments.size, unmoderated_comments_count)
    }.to_json.html_safe
  end

  def destroy
    @topic.destroy
    flash[:notice] = "flash_message.forum_flash.conversation_removed".translate
    redirect_to @forum
  end

  def mark_viewed
    @topic.mark_posts_viewability_for_user(current_user.id)
    @unviewed_discussions_board_count = @forum.group.get_cummulative_unviewed_posts_count(current_user)
    @home_page = params[:home_page].to_s.to_boolean
  end

  protected

  def topic_params(action)
    params.require(:topic).permit(Topic::MASS_UPDATE_ATTRIBUTES[action])
  end

  def authorize_user_for_destroy
    @topic.can_be_deleted?(current_user)
  end

  private

  def find_forum_and_topic
    @forum = @current_program.forums.find(params[:forum_id])
    @topic = @forum.topics.find_by(id: params[:id]) if params[:id]
  end

  def redirect_if_no_topic
    return if @topic.present?

    flash[:error] = "flash_message.forum_flash.conversation_does_not_exist".translate
    redirect_to forum_path(@forum)
  end

  def generate_back_link
    return if @forum.is_group_forum?

    if params[:from_flags] == "true"
      { label: "feature.flag.header.Flags".translate, link: flags_path }
    elsif params[:from_moderate_content] == "true"
      { label: "quick_links.program.moderate_content".translate, link: moderatable_posts_path }
    else
      { label: @forum.name, link: forum_path(@forum.id) }
    end
  end
end