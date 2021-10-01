class ProfileQuestionsController < ApplicationController
  include SolutionPack::ImporterUtils
  module PreviewType
    MEMBERSHIP_FORM = :membership_form
    USER_PROFILE_FORM = :user_profile_form
    USER_PROFILE = :user_profile

    def self.all
      [MEMBERSHIP_FORM, USER_PROFILE_FORM, USER_PROFILE]
    end
  end

  include ProfileRoleQuestionExtensions
  include PreviewFormsCommon
  skip_before_action :back_mark_pages

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  before_action :set_program_level_and_check_access, only: [:index, :edit, :update, :update_for_all_roles]

  before_action :load_question, :only => [:update, :destroy, :edit, :update_for_all_roles, :get_role_question_settings, :update_profile_question_section]
  before_action :load_profile_questions, :only => [:index, :new, :edit]

  before_action :load_program_roles, :only => [:new, :edit, :create, :update, :index]

  after_action :expire_cached_program_user_filters, :only => [:create, :update, :destroy]

  allow :exec => :check_admin_access
  allow exec: :super_console?, only: [:export, :import]

  def new
    @profile_question = @current_organization.profile_questions.new
    @section = @current_organization.sections.find(params[:section_id])
    @profile_question.section = @section
    @disabled_for_editing = false
    render partial: 'profile_questions/new'
  end

  def index
    @sections = @current_organization.sections
    @visible_section_ids = get_visible_section_ids(@sections) if @program_level
    @show_membership_intruction = should_show_membership_intruction?
    @membership_instruction = (current_program.membership_instruction.presence || current_program.build_membership_instruction) if @show_membership_intruction
    @non_membership_profile_questions = get_non_membership_profile_questions if @current_organization.standalone?
  end

  def create
    @profile_question = @current_organization.profile_questions.new(map_question_type(profile_question_params(:create)))
    assign_user_and_sanitization_version(@profile_question)
    @profile_question.organization = @current_organization
    @profile_question.section = @current_organization.sections.find(params[:section_id])
    section_questions = @profile_question.section.profile_questions
    @profile_question.position = section_questions.present? ? section_questions.last.position + 1 : 1
    @disabled_for_editing = false
    save_profile_question!(params, false)
  end

  def edit
    @section = @profile_question.section
    @disabled_for_editing = is_profile_question_disabled_for_editing?(@profile_question)
    @subprogram_view = true if (program_view? && !@current_organization.standalone?)
    @add_pq_at_program_level = @subprogram_view && !@profile_question.programs.collect(&:id).include?(@current_program.id)
    render partial: 'profile_questions/edit'
  end

  def update
    if params[:new_order]
      update_order
      head :ok
    else
      assign_user_and_sanitization_version(@profile_question)
      @section = @profile_question.section
      @role_options = get_update_role_options
      update_profile_question_followups
      @disabled_for_editing = is_profile_question_disabled_for_editing?(@profile_question)
    end
  end

  def update_for_all_roles
    @section = @current_organization.sections.find(params[:section_id])
    roles = @profile_question.role_questions.collect{|r| r.role_id} + @current_program.roles_without_admin_role.collect(&:id)
    create_or_update_role_questions_for(roles.collect(&:to_s), skip_role_visibility_options_includein: true)
    @profile_question.reload
  end

  def destroy
    if program_view? && !@current_organization.standalone?
      role_ids = destroy_role_questions(@current_program.role_questions & @profile_question.role_questions)
    else
      role_ids = @profile_question.role_questions.pluck(:role_id).uniq
      @profile_question.destroy
    end
    User.delay.es_reindex_for_profile_score(role_ids)
  end

  def preview
    update_preview_type
    update_preview_programs
    update_preview_filter_variables
    @can_preview_membership_form = super_console? || (program_view? ? check_authorization_for_membership_questions(@preview_program) : @current_organization.can_preview_membership_questions_for_any_program?)
    allow! :exec => lambda { @can_preview_membership_form } if membership_form_preview_type? && program_view?
    update_preview_profile_questions_and_sections
  end

  def get_role_question_settings
    @role_questions = @profile_question.role_questions.group_by(&:role_id)
    @program = @current_organization.programs.find_by(id: params[:program_id])
    @role = @program.roles_without_admin_role.find_by(id: params[:role_id])
  end

  def get_conditional_options
    @profile_question = @current_organization.profile_questions_with_email_and_name.find_by(id: params[:id]) || @current_organization.profile_questions.new
    @conditional_question = @current_organization.profile_questions_with_email_and_name.find(params[:question_id])
    @choice_id_mapping = @conditional_question.default_choice_records.collect{|qc| [qc.text, qc.id]}
    @default_values = get_default_conditional_match_text(params[:question_id].to_i, @profile_question)
  end

  def update_profile_question_section
    @section = @current_organization.sections.find(params[:section_id])
    load_profile_questions(@section.profile_questions.except_email_and_name_question)
    new_order = @profile_questions.collect(&:id)
    new_order << @profile_question.id
    update_order(new_order: new_order)
    @profile_question.reload
  end

  def export
    # We are using solution pack dummy object to just export
    # This object won't persist in db
    @solution_pack = SolutionPack.new(program: @current_program)
    file_path = @solution_pack.export(
      custom_associated_exporters: ProfileQuestion::ImportExportConstants::ExportConstants[:ToInclude],
      skipped_associated_exporters: ProfileQuestion::ImportExportConstants::ExportConstants[:ToSkip],
      return_zip_file: true,
      skip_post_attachment: true
    )
    handle_file_deletion_and_export(file_path)
  end

  def import
    file_path = params[:profile_question_file]
    if file_path.present?
      begin
        ActiveRecord::Base.transaction do
          @current_program.solution_pack_file = save_content_pack_to_be_imported(file_path)
          import_solution_pack(
            @current_program,
            custom_associated_importers: ProfileQuestion::ImportExportConstants::ImportConstants[:ToInclude],
            skipped_associated_importers: ProfileQuestion::ImportExportConstants::ImportConstants[:ToSkip]
          )
          flash.now[:notice] = "flash_message.program_flash.created_using_profile_question_pack".translate
        end
      rescue => e
        @error_flash = "feature.profile_question.file_uploader.errors.profile_question_import_failed".translate
        notify_airbrake(@error_flash)
        clean_up_solution_pack_file(@current_program.solution_pack_file)
      end
    end
  end

  private

  def handle_file_deletion_and_export(file_path)
    zip_data = File.read(file_path)
    FileUtils.rm_rf file_path
    send_data zip_data, type: "application/zip", disposition: "attachment", filename: S3Helper.embed_timestamp("#{SecureRandom.hex(3)}_profile_questions.zip")
  end

  def get_default_conditional_match_text(question_id, profile_question)
    profile_question.conditional_question_id == question_id ? profile_question.conditional_match_choices.pluck(:question_choice_id) : []
  end

  def save_profile_question!(params, skip_choices_updation)
    # skip_choices_updation is used to identify the forms where profile question itself is created/updated
    begin
      ProfileQuestion.transaction do
        return @profile_question.save && (skip_choices_updation || (@profile_question.reload.update_question_choices!(profile_question_choices_params) && @profile_question.update_conditional_match_choices!(params[:profile_question][:conditional_match_choices_list])))
      end
    rescue ActiveRecord::RecordInvalid => _invalid
      return false
    end
  end

  def profile_question_choices_params
    return params[:profile_question] unless params[:profile_question].try(:[], :existing_question_choices_attributes).present?
    params[:profile_question][:existing_question_choices_attributes][0] = permit_internal_attributes(params[:profile_question][:existing_question_choices_attributes][0], [:text])
    params[:profile_question]
  end

  def is_profile_question_disabled_for_editing?(profile_question)
    return false if super_console? || !profile_question.eligible_for_set_matching?
    program_ids = @current_organization.programs.select{|p| p.matching_enabled?}.map(&:id)
    role_question_ids = profile_question.role_questions.pluck(:id).join(",")
    program_match_configs = MatchConfig.where(program_id: program_ids, matching_type: MatchConfig::MatchingType::SET_MATCHING)
    program_match_configs.where("student_question_id IN (?) OR mentor_question_id IN (?)", role_question_ids, role_question_ids).exists?
  end

  def profile_question_params(action)
    params.require(:profile_question).permit(ProfileQuestion::MASS_UPDATE_ATTRIBUTES[action])
  end

  def role_question_params(attrs)
    return attrs unless attrs.is_a?(ActionController::Parameters)
    attrs.permit(RoleQuestion::MASS_UPDATE_ATTRIBUTES[:from_profile_question])
  end

  def load_question
    @profile_question = @current_organization.profile_questions_with_email_and_name.find(params[:id]) if !params[:new_order]
  end

  def load_program_roles
    @all_programs_with_roles = @current_organization.programs.ordered.includes(:roles)
  end

  # Returns whether the current member is an organization admin.
  def check_admin_access
    program_view? ? current_user.is_admin? : wob_member.admin?
  end

  def get_visible_section_ids(sections)
    sections.select{ |section| (section.role_questions.collect(&:role_id) & current_program.roles.collect(&:id)).present? }.collect(&:id)
  end

  def get_non_membership_profile_questions
    current_program.role_questions.for_user(user: current_user).role_profile_questions.collect(&:profile_question).uniq
  end

  def should_show_membership_intruction?
    program_view? && check_authorization_for_membership_questions(current_program) && current_user.can_manage_membership_forms?
  end

  def update_preview_profile_questions_and_sections
    @profile_questions = @preview_program.profile_questions_for(@filter_role, {fetch_all: true, default: true, skype: @current_organization.skype_enabled?, pq_translation_include: true}).sort_by(&:position)
    @profile_questions.select! { |pq| pq.role_questions.where(role_id: @filter_role_ids).map { |rq| rq.show_for_roles?(@viewer_roles) || (@should_be_connected && rq.show_connected_members?) }.inject(:|) } if @viewer_roles.present?
    @sections = @profile_questions.collect(&:section).uniq.sort_by(&:position)
    @profile_questions = @profile_questions.group_by(&:section_id)
    @all_answers = {}
    update_grouped_role_questions_and_required_questions
  end

  def update_grouped_role_questions_and_required_questions
    @grouped_role_questions = @preview_program.role_questions_for(@filter_role, fetch_all: true, include_privacy_settings: true).group_by(&:profile_question_id)
    @required_questions = @preview_program.role_questions_for(@filter_role).required.select([:required, :profile_question_id]).group_by(&:profile_question_id)
  end

  def update_preview_programs
    @membership_preview_programs = (super_console? ? @current_organization.programs : @current_organization.programs.allowing_membership_requests).ordered
    @profile_preview_programs = @current_organization.programs.ordered
  end

  def membership_form_preview_type?
    @preview_type == PreviewType::MEMBERSHIP_FORM
  end

  def update_preview_type
    @preview_type = (PreviewType.all.find{|type| type == params[:preview_type].try(:to_sym)}) || PreviewType::USER_PROFILE_FORM
  end

  def update_preview_filter_variables
    if params[:filter] && request.xhr? # profile preview case only comes here
      update_preview_filter_variables_for_xhr
    else
      programs = membership_form_preview_type? ? @membership_preview_programs : @profile_preview_programs
      @preview_program = params[:program_id].present? ? programs.find_by(id: params[:program_id]) : (program_view? ? @current_program : programs.first)
      @filter_role = []
    end
  end

  def update_preview_filter_variables_for_xhr
    @preview_program = @profile_preview_programs.find_by(id: params[:filter][:program])
    @filter_role_ids = params[:filter][:role]
    @filter_role = @preview_program ? @preview_program.roles.where(id: @filter_role_ids).pluck(:name) : []
    @viewer_roles = params[:filter][:viewer_role]
    @should_be_connected = params[:filter][:should_be_connected].try(:to_boolean) || false
  end

  def get_update_role_options
    {
      skip_role_settings: params[:skip_role_settings].to_s.to_boolean,
      skip_role_visibility_options_includein: params[:skip_role_visibility_options_includein].to_s.to_boolean,
      skip_other_roles: params[:skip_other_roles].to_s.to_boolean
    }
  end

  def update_profile_question_followups
    roles, skip_choices_updation = get_roles_for_update_profile_question
    @profile_question.assign_attributes(map_question_type(profile_question_params(:update)))
    if save_profile_question!(params, skip_choices_updation)
      create_or_update_role_questions_for(roles, @role_options)
      @profile_question.reload
    end
  end

  def get_roles_for_update_profile_question
    skip_choices_updation = false
    roles = nil
    if (@role_options[:skip_role_settings] || update_default_type_definition)
      roles = @profile_question.role_questions.collect{|r| r.role_id.to_s}
    elsif (@role_options[:skip_role_visibility_options_includein])
      roles = params[:programs].present? ? params[:programs].values.flatten : []
      skip_choices_updation = true
    elsif (@role_options[:skip_other_roles])
      skip_choices_updation = true
      roles= get_roles_for_update_profile_question_skip_other_roles
    end
    return roles, skip_choices_updation
  end

  def update_default_type_definition
    @profile_question.default_type? && !@role_options[:skip_other_roles]
  end

  def get_roles_for_update_profile_question_skip_other_roles
    profile_question_role_ids_ary = Array(params[:profile_question][:role_id])
    if !(params[:available_for_flag].to_s.to_boolean)
      @role_options[:skip_other_roles] = false
      @role_options[:skip_role_visibility_options_includein] = true
      @remove_role = true
      @profile_question.role_questions.collect{|r| r.role_id.to_s} - profile_question_role_ids_ary
    else
      params[:role_questions] ? params[:role_questions].keys : profile_question_role_ids_ary
    end
  end

  def create_or_update_role_questions_for(roles, options = {})
    return if options[:skip_role_settings]
    to_be_deleted_role_ids = []
    RoleQuestion.transaction do
      role_questions = @profile_question.role_questions
      role_questions_hash = role_questions.group_by(&:role_id)
      role_q = role_questions.where(role_id: roles)
      @role_destroy_flag = true if (to_be_destroyed_role_qns = (role_questions - role_q)).present?
      unless options[:skip_other_roles]
        to_be_deleted_role_ids = destroy_role_questions(to_be_destroyed_role_qns)
      end
      roles.each do |role_id|
        internal_update_role_questions_for(role_id, role_questions_hash, role_questions, options)
      end
    end
    User.delay.es_reindex_for_profile_score((roles.map(&:to_i) + to_be_deleted_role_ids).uniq)
  end

  def internal_update_role_questions_for(role_id, role_questions_hash, role_questions, options = {})
    role_q = role_questions_hash[role_id.to_i]
    if role_q.present?
      return if options[:skip_role_visibility_options_includein]
      role_q = role_q.first
    else
      role_q = role_questions.new
      role_q.role_id = role_id
    end
    role_params = params[:role_questions] || (options[:skip_role_visibility_options_includein] ? get_default_role_question_settings_hash(role_q) : {})
    attrs = embed_additional_attrs(@profile_question, role_id, role_q, role_params)
    role_q.update_attributes!(role_question_params(attrs))
  end

  def update_order(options = {})
    section, new_order_params = get_section_and_new_order_params(options)
    load_profile_questions(section.profile_questions.except_email_and_name_question)

    if new_order_params.size > @profile_questions.size
      update_additional_question_section(new_order_params, @profile_questions, section)
    end

    # The position index in db starts from 1, but in the array, the index starts from zero. adding +1 to default questions count
    # This +1 will be be added as a part of Reorder service
    base_position = section.profile_questions.default_questions.count
    section_questions = section.reload.profile_questions.find(new_order_params)
    ReorderService.new(section_questions).reorder(new_order_params, base_position)
  end

  def get_section_and_new_order_params(options = {})
    section = @current_organization.sections.find(params[:section_id])
    new_order = options[:new_order].present? ? options[:new_order] : params[:new_order]
    new_order_params = new_order.reject { |s| s.blank? }.collect(&:to_i)
    [section, new_order_params]
  end

  def update_additional_question_section(new_order_params, profile_questions, section)
    additional_question_id = (new_order_params - profile_questions.collect(&:id)).first
    additional_question = @current_organization.profile_questions.find(additional_question_id)
    additional_question.update_column(:section_id, section.id)
  end

  def get_dual_role_questions(programs)
    dual_role_ques = []
    @current_organization.profile_questions_with_email_and_name.each do |prof_q|
      count=0
      programs.each do |program|
        count += program.role_questions.for_user(user: current_user).select{|q| q.profile_question == prof_q}.count
      end
      dual_role_ques << prof_q if count == programs.count*2
    end
    return dual_role_ques
  end

  def map_question_type(profile_question)
    if profile_question[:question_type].present?
      question_type = profile_question[:question_type].to_i
      if params[:allow_multiple].presence == "true" && PROFILE_MERGED_QUESTIONS.invert[question_type].present?
        profile_question.merge!(:question_type => PROFILE_MERGED_QUESTIONS.invert[question_type])
      end
    end
    return profile_question
  end

  def set_program_level_and_check_access
    @program_level = (!@current_organization.standalone?) && program_view?
    allow! user: :can_manage_questions? if @program_level
  end

  def load_profile_questions(scope = nil)
    @profile_questions = scope.nil? ? @current_organization.profile_questions_with_email_and_name : scope
    @profile_questions = @profile_questions.except_skype_question unless @current_organization.skype_enabled?
    @profile_questions = @profile_questions.includes([:section, :role_questions, :roles]).to_a

    unless is_membership_form_enabled?(@current_organization)
      @profile_questions = @profile_questions.select { |question| !question.membership_only? }
    end
  end

  def get_default_role_question_settings_hash(role_q)
    roleq_program_roles = role_q.program.roles_without_admin_role.collect(&:id)
    roleq_program_roles_visibility_hash = HashWithIndifferentAccess.new
    roleq_program_roles.each do |role_id|
      roleq_program_roles_visibility_hash[role_id] = 0.to_s
    end
    role_settings_hash = HashWithIndifferentAccess.new
    role_settings_hash[role_q.role_id.to_s] = HashWithIndifferentAccess.new({
      :privacy_settings => {
        RoleQuestion::PRIVACY_SETTING::RESTRICTED.to_s => {
          RoleQuestionPrivacySetting::SettingType::ROLE.to_s => roleq_program_roles_visibility_hash,
          RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS.to_s => 0.to_s
        }
      },
      :filterable => true
    })
    role_settings_hash
  end
end