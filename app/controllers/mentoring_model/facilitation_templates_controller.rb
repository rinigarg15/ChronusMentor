class MentoringModel::FacilitationTemplatesController < ApplicationController
  include MentoringModelUtils

  allow user: :is_admin?
  before_action :fetch_mentoring_model
  allow exec: :manage_mm_messages_at_admin_level?
  before_action :fetch_facilitation_template, only: [:destroy, :edit, :update]
  before_action :fetch_templates_to_associate, only: [:new, :edit]
  before_action :fetch_task_templates_for_survey_select, only: [:new, :edit]
  before_action :get_facilitation_message_tags, only: [:new, :create, :edit, :update]

  def new
    @facilitation_template = @mentoring_model.mentoring_model_facilitation_templates.new(milestone_template_id: params[:milestone_template_id], send_on: 7)
    render_facilitation_template_form
  end

  def create
    user_and_sanitization_version = {current_user: current_user, current_member: current_member, sanitization_version: @current_organization.security_setting.sanitization_version}
    @facilitation_template = @mentoring_model.mentoring_model_facilitation_templates.new(validate_and_facilitation_template_params!(:create).merge(user_and_sanitization_version))
    save_facilitation_template!
    render "create.js", :handlers => [:erb]
  end

  def edit
    render_facilitation_template_form
  end

  def update
    assign_user_and_sanitization_version(@facilitation_template)
    @facilitation_template.assign_attributes(validate_and_facilitation_template_params!(:update))
    save_facilitation_template!
    render "update.js", :handlers => [:erb]
  end

  def destroy
    @facilitation_template.destroy
    @all_task_templates = fetch_appropriate_task_templates
  end

  def preview_email
    @email = ChronusActionMailer::Base.get_descendant(MentoringModel::FacilitationTemplate::AUTO_EMAIL_NOTIFICATION_UID)
    @mailer_template = Mailer::Template.find_or_initialize_mailer_template_with_default_content(@current_program, @email)

    @email.preview(current_user, wob_member, @current_program, @current_organization, mailer_template_obj: @mailer_template, level: @email.mailer_attributes[:level], facilitation_message: preview_facilitation_message).deliver_now
  end

  private

  def preview_facilitation_message
    facilitation_message = @current_program.admin_messages.build
    facilitation_message.subject = get_facilitation_template_subject(params[:mentoring_model_facilitation_template][:subject])
    facilitation_message.content = params[:mentoring_model_facilitation_template][:message]
    facilitation_message.auto_email = true
    return facilitation_message
  end

  def mentoring_model_facilitation_template_permitted_params(action)
    params.require(:mentoring_model_facilitation_template).permit(MentoringModel::FacilitationTemplate::MASS_UPDATE_ATTRIBUTES[action])
  end

  def save_facilitation_template!
    role_names = params[:mentoring_model_facilitation_template][:role_names]
    @facilitation_template.role_names = role_names if role_names.present?
    @facilitation_template.save!
    @all_task_templates = fetch_appropriate_task_templates
  end

  def fetch_templates_to_associate
    @milestone_templates_to_associate = @mentoring_model.mentoring_model_milestone_templates if manage_mm_milestones_at_admin_level?
  end

  def fetch_facilitation_template
    @facilitation_template = @mentoring_model.mentoring_model_facilitation_templates.find(params[:id])
  end

  def fetch_task_templates_for_survey_select
    survey_links = []
    mentoring_model_survey_ids = []
    @current_program.surveys.of_engagement_type.each do |survey|
      survey_links << {name: survey.name, value: "{{engagement_survey_link_#{survey.id}}}"}
    end
    @survey_links = survey_links.to_json
  end

  def validate_and_facilitation_template_params!(action)
    facilitation_template_params = mentoring_model_facilitation_template_params(action)
    facilitation_template_params[:milestone_template_id] = params[:mentoring_model_facilitation_template][:milestone_template_id] if manage_mm_milestones_at_admin_level?
    facilitation_template_params[:subject] = get_facilitation_template_subject(facilitation_template_params[:subject])
    facilitation_template_params
  end

  def get_facilitation_template_subject(subject = nil)
    subject.presence || "feature.mentoring_model.label.default_facilitation_template_title".translate(Mentoring: _Mentoring)
  end

  def mentoring_model_facilitation_template_params(action)
    selected_params = mentoring_model_facilitation_template_permitted_params(action)
    if(params[:mentoring_model_facilitation_template][:date_assigner] == MentoringModel::FacilitationTemplate::DueDateType::SPECIFIC_DATE)
      selected_params[:specific_date] = get_en_datetime_str(selected_params[:specific_date])
      selected_params[:send_on] = nil
    elsif params[:duration_id_input].present?
      selected_params[:send_on] = (params[:duration_id_input].to_i * selected_params[:send_on].to_i).to_s
      selected_params[:specific_date] = nil
    end
    selected_params
  end

  def render_facilitation_template_form
    render(partial: "mentoring_model/facilitation_templates/facilitation_template_progressive_form.html", locals: {
      facilitation_template: @facilitation_template,
      milestone_templates_to_associate: @milestone_templates_to_associate,
      assignable_roles: @current_program.roles.for_mentoring,
      survey_links: @survey_links,
      as_ajax: true
    }, layout: false)
  end
end