class MentoringModel::Task::CommentsController < ApplicationController
  include ConnectionFilters
  include MentoringModelUtils
  common_extensions
  before_action :fetch_task
  
  def create
    comment_attributes = {sender: wob_member, program_id: @group.program_id}.merge(mentoring_model_task_comment_params(:create))
    @comment = @task.comments.new
    @comment.attributes = comment_attributes
    @comment.notify = true if (@current_organization.audit_user_communication? || params[:mentoring_model_task_comment][:notify].to_i == 1)
    @home_page_view = params[:home_page_view].to_s.to_boolean
    if @comment.save
      @comments_and_checkins = @task.comments_and_checkins
      @new_comment = @task.comments.new
      @new_checkin = @task.checkins.new
      @scrap = @comment.scrap
      track_activity_for_ei(EngagementIndex::Activity::CREATE_TASK_COMMENT)
    else
      @error_message = @comment.errors.full_messages.to_sentence.presence
    end
  rescue VirusError
    @error_message = "flash_message.message_flash.virus_present".translate
  end

  def destroy
    @comment = @task.comments.find(params[:id])
    allow! :exec => :can_destroy_task_comment?
    @comment.destroy
    @comments = @task.comments
    @comments_and_checkins = @task.comments_and_checkins
    @home_page_view = params[:home_page_view].to_s.to_boolean
  end

  private

  def mentoring_model_task_comment_params(action)
    params.require(:mentoring_model_task_comment).permit(MentoringModel::Task::Comment::MASS_UPDATE_ATTRIBUTES[action])
  end

  def fetch_task
    @task = @group.mentoring_model_tasks.find(params[:task_id])
    @can_checkin_access = checkin_access
  end
end