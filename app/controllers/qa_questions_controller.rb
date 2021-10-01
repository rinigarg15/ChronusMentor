class QaQuestionsController < ApplicationController
  before_action :add_custom_parameters_for_newrelic, :only => [:index]
  before_action :fetch_qa_question, only: [:show, :follow, :destroy]

  allow :exec => :authorize_access_to_actions
  allow :exec => :authorize_user_for_destroy, :only => [:destroy]
  allow :user => :can_ask_question?, :only => [:new, :create]
  allow :user => :can_view_questions?, :only => [:index, :show]
  allow :user => :can_follow_question?, :only => [:follow]

  # New question form
  def new
    @qa_question = @current_program.qa_questions.new(qa_question_params(:new))
  end

  def index
    @sort_field = params[:sort] || :id
    @sort_order = params[:order] || :desc
    @search_query = params[:search]
    @add_new_question = params[:add_new_question].to_s.to_boolean
    @new_qa_question = build_new_qa_question if current_user.can_ask_question?
    if @search_query.present?
      @qa_questions = QaQuestion.get_qa_questions_matching_query(QueryHelper::EsUtils.sanitize_es_query(@search_query), qa_make_search_options)
    else
      @qa_questions = QaQuestion.includes(:program, :user => [:roles, :member => [:profile_picture]]).where(:program_id => @current_program.id).order(qa_sort_spec.values.join(" ")).paginate(qa_pagination_options)
      @top_contributors = @current_program.users.includes(:roles, :member => [:profile_picture])
                            .order("qa_answers_count DESC")
                            .where(" qa_answers_count > 0")
                            .limit(5)
    end
  end

  def show
    @answers_sort_options = PaginationService.build_sort_options(QaAnswer.name, params[:sort], params[:order])
    @page = params[:page]
    if @qa_question.blank?
      flash[:error] = "flash_message.qa_question.question_not_exist".translate
      redirect_to qa_questions_path and return
    end
    prepare_qa_show_question(params[:id], params[:sort])
    @qa_answers = @qa_question.qa_answers
              .includes(:ratings, :flags, :user => [:roles, :member => :profile_picture])
              .order(@answers_sort_options[:order_string])
              .paginate(PaginationService.pagination_options(QaAnswer.name,@page))
    @similar_qa_questions = @qa_question.similar_qa_questions
    @back_link = params[:from_flags] == true.to_s ? {label: "feature.flag.header.Flags".translate, link: flags_path} : {label: "feature.question_answers.header.question_answers".translate, link: qa_questions_path}
    # mark answer helpful, used via email qa_answer_notification
    handle_mark_as_helpful(params[:mark_helpful_answer_id].to_i) if params[:mark_helpful_answer_id].present?
    track_activity_for_ei(EngagementIndex::Activity::VIEW_QA, {context_object: @qa_question.summary})
  end

  def create
    @qa_question = build_new_qa_question(qa_question_params(:create))
    if @qa_question.save
      track_activity_for_ei(EngagementIndex::Activity::POST_TO_QA, {context_object: @qa_question.summary})
      flash[:notice] = "flash_message.qa_question.posted".translate
    else
      flash[:error] = "flash_message.qa_question.not_posted".translate
    end
    redirect_to :action => 'index', format: :js
  end

  def follow
    @qa_question.toggle_follow!(current_user)
    @qa_question.reload
  end

  def destroy
    Flag.set_status_as_deleted(@qa_question, current_user, Time.now)
    QaQuestion.includes([:ratings, :recent_activities, :flags, :user, :qa_answers => [:ratings, :qa_question, :user, :recent_activities, :flags]]).find(@qa_question.id).destroy
    flash[:notice] = "flash_message.qa_question.deleted".translate
    redirect_to qa_questions_path
  end

  protected

  def build_new_qa_question(options = {})
    @question = @current_program.qa_questions.build(options)
    @question.user = current_user
    @question
  end

  def prepare_qa_show_question(question_id, sort_params)
    @new_qa_question = build_new_qa_question if current_user.can_ask_question?
    QaQuestion.increment_counter(:views, question_id) unless (sort_params.present? || @qa_question.user_id == current_user.id)
    @qa_answer = QaAnswer.new
  end

  def qa_make_search_options
    options = qa_pagination_options
    options.merge!(qa_sort_spec)
    options[:with] = {:program_id => @current_program.id}
    options[:includes_list] = [:program, :user => [:roles, :member => [:profile_picture]]]
    options
  end

  private

  def fetch_qa_question
    @qa_question = @current_program.qa_questions.find_by(id: params[:id])
  end

  def qa_question_params(action)
    params.require(:qa_question).permit(QaQuestion::MASS_UPDATE_ATTRIBUTES[action])
  end

  def authorize_access_to_actions
    @current_program.qa_enabled?
  end

  def authorize_user_for_destroy
    (@qa_question.user == current_user) || current_user.can_manage_questions?
  end

  def qa_sort_spec
    {sort_field: @sort_field, sort_order: @sort_order}
  end

  def qa_pagination_options
    {
      :page => (params[:page] || 1),
      :per_page => QaQuestion.per_page,
    }
  end

  def handle_mark_as_helpful(answer_id)
    answer = @qa_answers.find_by(id: answer_id)
    answer.toggle_helpful!(current_user) if (answer.present? && !answer.helpful?(current_user))
  end
end
