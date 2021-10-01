class CommentsController < ApplicationController
  before_action :load_article_publication

  def create
    @comment = @article_publication.comments.new(comment_params)
    @comment.user = current_user
    if @comment.save
      track_activity_for_ei(EngagementIndex::Activity::COMMENT_ON_ARTICLE, {context_object: @article_publication.article.title})
    end
  end

  def destroy
    @comment = @article_publication.comments.find(params[:id])
    allow! :exec => Proc.new { (@comment.user == current_user) || current_user.can_manage_articles? }
    Flag.set_status_as_deleted(@comment, current_user, Time.now)
    @comment.destroy
    redirect_back(fallback_location: root_path) unless request.xhr?
  end

  protected

  def load_article_publication
    @article_publication = @current_program.article_publications.find_by(article_id: params[:article_id])
  end

  private

  def comment_params
    params[:comment].present? ? params[:comment].permit(Comment::MASS_UPDATE_ATTRIBUTES[:create]) : {}
  end
end
