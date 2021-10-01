class Feedback::ResponsesController < ApplicationController

  before_action :set_feedback_form

  def new
    set_group_and_recipient(params)
    @feedback_response = @feedback_form.responses.new(group: @group, rating_giver: current_user, rating_receiver: @recipient)
    @feedback_questions = @feedback_form.questions
    @answers_map = @feedback_response.answers.group_by{|answer| answer.common_question_id}
    if request.xhr?
      render :partial => "feedback/responses/new"
    end
  end

  def create
    set_group_and_recipient(params[:feedback_response])
    rating = params[:score].to_f
    @feedback_response = Feedback::Response.create_from_answers(
      current_user, @recipient, rating, @group, @feedback_form, params[:feedback_answers])

    @feedback_response.delay.notify_admins if @feedback_response.valid?
  end

  private

  def set_feedback_form
    @feedback_form = @current_program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
  end

  def set_group_and_recipient(params)
    @group = current_user.studying_groups.published.find(params[:group_id])
    @recipient = @group.mentors.find(params[:recipient_id])
  end
end