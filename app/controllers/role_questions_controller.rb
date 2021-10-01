class RoleQuestionsController < ApplicationController
  include ProfileRoleQuestionExtensions
  skip_before_action :back_mark_pages

  allow :user => :can_manage_questions?
  #expired also for update questions but not in the case of change of order
  after_action :expire_index_cached_fragments, :only => [:update, :update_profile_summary_fields]

  def index
    redirect_to profile_questions_path
  end

  def update
    @profile_question = @current_organization.profile_questions_with_email_and_name.find(params[:id])
    email_or_name_type = @profile_question.default_type?
    if email_or_name_type
      role_ids = @current_program.role_questions.where(:profile_question_id => @profile_question.id).collect{|r| r.role_id.to_s}
    else
      role_ids = params[:programs].present? ? params[:programs].values.flatten : []
    end
    role_questions = @profile_question.role_questions
    role_questions_hash = role_questions.group_by(&:role_id)
    program_role_questions = (role_questions & @current_program.role_questions)
    updated_ques = role_questions.where(role_id: role_ids)
    role_params = params[:role_questions].permit!.to_h || {}

    deleted_role_qns_role_ids = []
    RoleQuestion.transaction do
      deleted_role_qns_role_ids = destroy_role_questions(program_role_questions - updated_ques)
      role_ids.each do |role_id|
        role_q = role_questions_hash[role_id.to_i]
        if role_q.present?
          role_q = role_q.first
        else
          role_q = role_questions.new
          role_q.role_id = role_id
        end
        attrs = embed_additional_attrs(@profile_question, role_id, role_q, role_params)
        role_q.update_attributes!(attrs)
      end
    end
    User.delay.es_reindex_for_profile_score((role_ids.map(&:to_i) + deleted_role_qns_role_ids).uniq)
    if (@profile_question.role_questions.reload & @current_program.role_questions.for_user(user: current_user).reload).any?
      render :template => 'role_questions/update', :formats => [:js], :handlers => [:erb]
    else
      render :template => 'profile_questions/destroy', :formats => [:js], :handlers => [:erb]
    end
  end

  def update_profile_summary_fields
    role_program_questions = @current_program.role_questions_for(@current_program.roles_without_admin_role.collect(&:name), user: current_user)
    current_fields = role_program_questions.shown_in_summary
    param_role_questions = role_program_questions.find(params[:fields] || [])
    to_be_retained_fields = current_fields && param_role_questions
    to_be_created_fields = param_role_questions - current_fields
    to_be_removed_fields = current_fields - to_be_retained_fields

    to_be_created_fields.each do |field|
      field.update_attributes(:in_summary => true)
    end
    to_be_removed_fields.each do |field|
      field.update_attributes(:in_summary => false)
    end
    flash[:notice] = "flash_message.organization_flash.profile_summary_updated".translate
    redirect_to (@current_organization.standalone? ? profile_questions_path : role_questions_path)
  end

  private

  def expire_index_cached_fragments
    # Expiring the listing page profile snap shot
    expire_user_filters(@current_program.id)
  end
end