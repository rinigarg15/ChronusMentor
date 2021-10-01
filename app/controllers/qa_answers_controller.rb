class QaAnswersController < ApplicationController
  allow :exec => :authorize_access_to_actions
  allow :exec => :authorize_user_for_destroy, :only => [:destroy]

  def create
    @qa_question = @current_program.qa_questions.find(params[:qa_question_id])
    @qa_answer = @qa_question.qa_answers.build(qa_answer_params(:create))
    @qa_answer.user = current_user
    @qa_answer.save!
    track_activity_for_ei(EngagementIndex::Activity::REPLY_TO_QA, {context_object: @qa_question.summary})
    redirect_to qa_question_path(@qa_question, format: :js, sort: "id", order: "desc", answer_created: true)
  end

  def helpful
    @qa_answer = @current_program.qa_answers.find_by(id: params[:id])
    @is_helpful = @qa_answer.toggle_helpful!(current_user) if @qa_answer.present?
    head :ok
  end

  def destroy
    Flag.set_status_as_deleted(@qa_answer, current_user, Time.now)
    @qa_question = @qa_answer.qa_question
    @qa_answer.destroy
    # http://api.rubyonrails.org/classes/ActionController/Redirecting.html#method-i-redirect_to
    answer_deleted = params[:answer_deleted].nil? ? false : true
    redirect_to qa_question_path(@qa_question, format: :js, sort: "id", order: "desc", answer_deleted: answer_deleted), status: :see_other
  end

  private
  def qa_answer_params(action)
    params.require(:qa_answer).permit(QaAnswer::MASS_UPDATE_ATTRIBUTES[action])
  end

  def authorize_access_to_actions
    @current_program.qa_enabled?
  end

  def authorize_user_for_destroy
    @qa_answer = @current_program.qa_answers.find(params[:id])
    @qa_question = @qa_answer.qa_question
    (@qa_answer.user == current_user) || current_user.can_manage_answers?
  end
end
