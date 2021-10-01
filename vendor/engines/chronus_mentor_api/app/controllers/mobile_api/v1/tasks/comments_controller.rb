class MobileApi::V1::Tasks::CommentsController < MobileApi::V1::MentoringAreaController
  include MentoringModelUtils
  before_action :prohibit_writes, :can_comment?, :fetch_task
  before_action :fetch_comment, :can_destroy?, only: :destroy

  def create
    @comment = @task.comments.create!(task_comment_params)
    @comments = @task.comments.includes(:sender)
    render_success("tasks/comments/index")
  end

  def destroy
    @comment.destroy
    @comments = @task.comments.includes(:sender)
    render_success("tasks/comments/index")
  end

  private

  def fetch_task
    @task = @group.mentoring_model_tasks.find(params[:task_id])
  end

  def fetch_comment
    @comment = @task.comments.find(params[:id])
  end

  def task_comment_params
    { sender: wob_member, program_id: @group.program_id, notify: 1 }.merge(params.to_h.pick(:content))
  end

  def can_comment?
    unless current_program.mentoring_connections_v2_enabled?
      render_errors({can_comment: false}, 403)
    end
  end

  def can_destroy?
    unless can_destroy_task_comment?
      render_errors({can_destroy_comment: false}, 403)
    end
  end
end