class MailerTemplatesController < ApplicationController
  include UserMailerHelper
  include MailerTemplatesHelper

  ALL_CATEGORIES_VALUE = 0

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization

  before_action :fetch_email, :only => [:edit, :update_status, :preview_email]
  before_action(only: [:create, :update]) { set_correct_level(params[:mailer_template][:uid]) }

  allow :exec => :authorize_update_actions, :only => [:update, :update_status]
  allow :exec => :check_management_access

  def index
    emails_hash_list = ChronusActionMailer::Base.get_descendants.collect{|e| e.mailer_attributes.dup }
    emails_hash_list = get_emails_to_show(emails_hash_list)
    
    email_rollout_service = EmailRolloutService.new(current_program_or_organization, current_user_or_member)
    @show_rollout_update_all = email_rollout_service.show_rollout_update_all?

    email_per_catogory = emails_hash_list.group_by{|e| e[:category]}
    @email_catogories_list = EmailCustomization::NewCategories::Type.all.map {|catogory| {catogory: catogory, name: catogory_name(catogory), count: (email_per_catogory[catogory]||[]).size, description: catogory_description(catogory)}}
    @email_catogories_list.delete_if{|c| c[:count].zero?}.sort_by{|c| c[:catogory]}
  end

  def category_mails
    @category = params[:category].to_i
    @sub_categories = EmailCustomization::NewCategories::Type::SubCategoriesForType[@category]
    @emails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:category] == @category}
    @emails_hash_list = @emails.collect{|e| e.mailer_attributes.dup }
    @emails_hash_list = get_emails_to_show(@emails_hash_list)

    @widgets_hash_list = WidgetTag.get_descendants.collect{|e| e.widget_attributes.dup }.sort_by{|h| h[:title].call}
    @widgets_hash_list.reject!{|widget_attribute| widget_attribute[:uid] == WidgetStyles.widget_attributes[:uid]}
    
    @enable_update = authorize_update_actions

    email_rollout_service = EmailRolloutService.new(current_program_or_organization, current_user_or_member)

    @emails_hash_list.each do |email|
      email[:disabled] = current_program_or_organization.email_template_disabled_for_activity?(ChronusActionMailer::Base.get_descendant(email[:uid]))
      email[:rollout] = !email[:skip_rollout] && email_rollout_service.rollout_applicable?(email[:uid])
      email[:content_customized] = Mailer::Template.content_customized?(current_program_or_organization, ChronusActionMailer::Base.get_descendant(email[:uid]))
    end

    @emails_hash_list.sort_by!{|mailer_attribute| mailer_attribute[:listing_order]}

    @emails_by_subcategory_hash = @emails_hash_list.group_by{|mailer_attribute| mailer_attribute[:subcategory]}
  end

  def edit
    content = @email.compute_subject_and_email(@current_organization, @current_program)
    @mailer_template ||= correct_level.mailer_templates.new(uid: @uid, enabled: !correct_level.email_template_disabled_for_activity?(@email))
    @mailer_template.subject = content[:subject_template] || ""
    @mailer_template.source  = content[:email_template] || ""
    @enable_update = authorize_update_actions

    @all_tags = get_tags_from_email(@email)
    @widget_names = @email.get_widgets_from_email
  end

  def create
    params_mailer_template = mailer_template_params(:create)
    params[:mailer_template] = params_mailer_template

    Mailer::Template.update_subject_source_params_if_unchanged(params, current_member)
    @mailer_template = correct_level.mailer_templates.new(params_mailer_template)
    assign_user_and_sanitization_version(@mailer_template)

    handle_mailer_template_updation(@mailer_template, params_mailer_template)
  end

  def update
    params_mailer_template = mailer_template_params(:update)
    params[:mailer_template] = params_mailer_template

    Mailer::Template.update_subject_source_params_if_unchanged(params, current_member)
    @mailer_template = correct_level.mailer_templates.find(params[:id])
    assign_user_and_sanitization_version(@mailer_template)

    handle_mailer_template_updation(@mailer_template, params_mailer_template)
  end

  def update_status
    @mailer_template ||= correct_level.mailer_templates.new(:uid => @uid)
    @mailer_template.enabled = (params[:enabled] == "true")
    @mailer_template.save!
  end

  def preview_email
    @mailer_template ||= correct_level.mailer_templates.build(:uid => @uid)
    @mailer_template.subject = params[:mailer_template][:subject] || ""
    @mailer_template.source = params[:mailer_template][:source] || ""
    
    if @mailer_template.valid?
      @email.preview(current_user, wob_member, @current_program, @current_organization, mailer_template_obj: @mailer_template, :level => @email.mailer_attributes[:level]).deliver_now
    end
  end

  private

  def mailer_template_params(action)
    params[:mailer_template].present? ? params[:mailer_template].permit(Mailer::Template::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def reject_email_template(email, disabled_features)
    email_feature_array = Array(email[:feature])
    email_feature_array.present? && (email_feature_array - disabled_features).empty?
  end

  def check_management_access
    program_view? ? current_user.is_admin? : current_member.admin?
  end

  def authorize_update_actions
    super_console? || @current_organization.customize_emails_enabled?
  end

  def fetch_email
    @uid = params[:id]
    @email = ChronusActionMailer::Base.get_descendant(@uid)
    @email_hash = @email.mailer_attributes
    set_correct_level(@uid)
    @mailer_template = correct_level.mailer_templates.find_by(uid: @uid)
  end

  def handle_success_and_failure_cases(status)
    if status
      flash[:notice] = "flash_message.mailer_template_flash.update_success".translate
      redirect_to edit_mailer_template_path(@mailer_template.uid)
    else
      email = ChronusActionMailer::Base.get_descendant(@mailer_template.uid)
      @email_hash = email.mailer_attributes
      @all_tags = get_tags_from_email(email)
      @widget_names = email.get_widgets_from_email
      @enable_update = authorize_update_actions
      render :action => :edit
    end
  end

  def handle_mailer_template_updation(mailer_template, template_params)
    other_locales = (@current_organization.languages.collect{|language| language[:language_name].to_sym} << I18n.default_locale).uniq - [current_locale]
    status = Mailer::Template.populate_mailer_template_for_all_locales(mailer_template, template_params, other_locales)
    handle_success_and_failure_cases(status)
  end

  def get_tags_from_email(email)
    @mailer_template.campaign_message_id.blank? ? email.get_tags_from_email : @mailer_template.campaign_message.campaign.campaign_email_tags
  end

  def display_email_in_program(e)
    e[:program_settings].present? ? e[:program_settings].call(@current_program) : true
  end

  def set_correct_level(uid)
    email = ChronusActionMailer::Base.get_descendant(uid)
    email_hash = email.mailer_attributes
    @correct_level = (email_hash[:level]==EmailCustomization::Level::ORGANIZATION) ? @current_organization : @current_program
  end

  def correct_level
    @correct_level
  end

  def catogory_name(catogory)
    EmailCustomization.get_translated_email_type_name(EmailCustomization::NewCategories::NAMES[catogory]).call(current_program_or_organization)
  end

  def catogory_description(catogory)
    EmailCustomization.get_translated_email_description(EmailCustomization::NewCategories::NAMES[catogory]).call(current_program_or_organization)
  end

  def get_emails_to_show(emails_hash_list)
    emails_hash_list.reject!{|mailer_attribute|  mailer_attribute[:donot_list]}
    emails_hash_list = EmailCustomization::Level.select_those_applicable_at_current_level(emails_hash_list, current_program_or_organization) unless @current_organization.standalone?

    disabled_features = @current_program ? @current_program.disabled_features : @current_organization.disabled_features
    emails_hash_list = emails_hash_list.reject{|e| reject_email_template(e, disabled_features) }
    emails_hash_list = emails_hash_list.select{|e| display_email_in_program(e)} if @current_program
    return emails_hash_list
  end
end