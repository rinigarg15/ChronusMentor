class PostsController < ApplicationController
  include MentoringModelUtils
  include ForumExtensions

  before_action :find_forum_and_topic_and_post

  allow exec: :authorize_user, except: [:destroy, :moderatable_posts]
  allow exec: :authorize_user_for_destroy, only: [:destroy]
  allow exec: :check_program_forum, only: [:moderate_publish, :moderate_decline]
  allow exec: :check_forum_feature, only: [:moderatable_posts]
  allow user: :can_manage_forums?, only: [:moderatable_posts, :moderate_publish, :moderate_decline]

  group_forum_extensions([:create, :destroy])

  def index
    redirect_to [@forum, @topic]
  end

  def create
    @home_page = params[:home_page].to_s.to_boolean
    @post = @topic.posts.build(post_params(:create))
    @post.user = current_user
    @post.published = current_user.can_manage_forums? || !@forum.allow_moderation?

    if @post.save
      track_ei_for_create
      @success_message = get_success_message
      fetch_posts if @post.root?
    else
      @error_message = @post.errors.full_messages.to_sentence.presence
    end
  rescue VirusError
    @error_message = "flash_message.forum_flash.virus_present".translate
  end

  # Declining an unpublished post is non-AJAX
  def destroy
    Flag.set_status_as_deleted(@post, current_user, Time.now)
    @post.destroy

    if @post.published?
      @success_message = "flash_message.forum_flash.p_deleted".translate
      fetch_posts if @post.root?
    else
      if @post.user != current_user
        ChronusMailer.content_moderation_user_notification(@post.user, @post, params[:reason]).deliver_now
      end
      flash[:notice] = "flash_message.forum_flash.p_declined".translate
      redirect_to params[:redirect_back_to] || forum_topic_path(@forum, @topic, from_moderate_content: params[:from_moderate_content])
    end
  end

  def moderatable_posts
    page = params[:page] || 1
    posts_unpublished = current_program.posts.unpublished.order(:created_at)
    @unpublished_posts = posts_unpublished.paginate(page: page)
  end

  def moderate_publish
    @post.update_attributes!(published: true)
    flash[:notice] = "flash_message.forum_flash.p_published".translate(user: @post.user.name)
    redirect_to params[:redirect_back_to] || back_url
  end

  def moderate_decline
    render partial: "posts/moderate_decline_form"
  end

  protected

  def post_params(action)
    params.require(:post).permit(Post::MASS_UPDATE_ATTRIBUTES[action])
  end

  def authorize_user_for_destroy
    @post.can_be_deleted?(current_user)
  end

  private

  def find_forum_and_topic_and_post
    @forum = @current_program.forums.find(params[:forum_id]) if params[:forum_id]
    @topic = @current_program.topics.find(params[:topic_id]) if params[:topic_id]
    @post = @current_program.posts.find(params[:id]) if params[:id]
  end

  def track_ei_for_create
    track_activity_for_ei(EngagementIndex::Activity::POST_TO_FORUM, {context_object: @forum.is_group_forum? ? @group.name : @forum.name})
  end

  def get_success_message
    if @post.published?
      "flash_message.forum_flash.p_created".translate
    else
      Post.delay(queue: DjQueues::HIGH_PRIORITY).notify_admins_for_moderation(@current_program, @post, RecentActivityConstants::Type::POST_CREATION)
      "flash_message.forum_flash.p_moderation_v1".translate
    end
  end
end