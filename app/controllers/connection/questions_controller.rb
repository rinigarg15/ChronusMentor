class Connection::QuestionsController < ApplicationController
  before_action :load_question, :only => [:update, :destroy]

  allow :user => :can_manage_connections?
  allow :exec => :check_program_has_ongoing_mentoring_enabled

  def index
    @connection_questions = @current_program.connection_questions.includes(:translations, question_choices: :translations)
  end

  def new
    @common_question = @current_program.connection_questions.new
    render :template => 'common_questions/new', :formats => [:js]
  end

  def create
    @common_question = @current_program.connection_questions.new(connection_question_params(:create))
    @common_question.program = @current_program
    begin
      ActiveRecord::Base.transaction do
        if @common_question.save! && @common_question.update_question_choices!(connection_question_choices_params)
          @common_question.insert_at(1)
          @common_question.set_unset_summary(params[:connection_question][:display_question_in_summary] == "1")
        end
      end
    rescue ActiveRecord::RecordInvalid => _invalid
      # suppress active record invalid exceptions
    end
    render :template => 'common_questions/create', :formats => [:js]
  end

  def update
    begin
      ActiveRecord::Base.transaction do
        @common_question.update_attributes!(connection_question_params(:update))
        @common_question.update_question_choices!(connection_question_choices_params)
        @common_question.set_unset_summary(params[:connection_question][:display_question_in_summary] == "1")
        @common_question.reload
      end
    rescue ActiveRecord::RecordInvalid => _invalid
      # suppress active record invalid exceptions
    end
    render :template => 'common_questions/update', :formats => [:js]
  end

  def destroy
    @summary_present = @common_question.summary.present?
    @common_question.destroy
    render :template => 'common_questions/destroy', :formats => [:js]
  end

  def sort
    connection_questions = @current_program.connection_questions.includes(:translations)
    ReorderService.new(connection_questions).reorder(params[:new_order])
    head :ok
  end

  private

  def connection_question_choices_params
    return params[:common_question] unless params[:common_question].try(:[], :existing_question_choices_attributes).present?
    params[:common_question][:existing_question_choices_attributes][0] = permit_internal_attributes(params[:common_question][:existing_question_choices_attributes][0], [:text])
    params[:common_question]
  end

  def connection_question_params(action)
    params.require(:connection_question).permit(Connection::Question::MASS_UPDATE_ATTRIBUTES[action])
  end

  def load_question
    @common_question = @current_program.connection_questions.find(params[:id])
  end
end
