class MailerWidgetsController < ApplicationController

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization

  before_action :get_program_in_subprograms_context

  allow :exec => :authorize_update_actions, :only => [:update]
  allow :exec => :check_management_access

  def edit
    @uid         = params[:id]

    widget       = WidgetTag.get_descendant(@uid)
    @widget_hash = widget.widget_attributes
    @all_tags    = widget.get_tags_from_widget
    @enable_update = authorize_update_actions

    @mailer_widget = @current_program_or_organization.mailer_widgets.find_or_initialize_by(uid: @uid)
    @mailer_widget.source  = widget.get_template(@current_organization, @current_program)
  end

  def create
    @mailer_widget = @current_program_or_organization.mailer_widgets.new(mailer_widget_params(:create))
    assign_user_and_sanitization_version(@mailer_widget)

    handle_mailer_widget_updation(@mailer_widget, mailer_widget_params(:create))
  end

  def update
    @mailer_widget = @current_program_or_organization.mailer_widgets.find(params[:id])
    assign_user_and_sanitization_version(@mailer_widget)

    handle_mailer_widget_updation(@mailer_widget, mailer_widget_params(:update))
  end

  private

  def mailer_widget_params(action)
    params[:mailer_widget].present? ? params[:mailer_widget].permit(Mailer::Widget::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def check_management_access
    @is_sub_program_view ? current_user.is_admin? : wob_member.admin?
  end

  def authorize_update_actions
    super_console? || @current_organization.customize_emails_enabled?
  end

  def get_program_in_subprograms_context
    @is_sub_program_view = program_view? && !@current_organization.standalone?
    @current_program_or_organization = @is_sub_program_view ? @current_program : @current_organization
  end

  def handle_success_and_failure_cases(status)
    if status
      flash[:notice] = "flash_message.mailer_template_flash.widget_update_success".translate
      redirect_to mailer_templates_path()
    else
      widget       = WidgetTag.get_descendant(@mailer_widget.uid)
      @widget_hash = widget.widget_attributes
      @all_tags    = widget.get_tags_from_widget
      @enable_update = authorize_update_actions
      render :action => :edit
    end
  end

  def handle_mailer_widget_updation(mailer_widget, widget_params)
    other_locales = (@current_organization.languages.collect{|language| language[:language_name].to_sym} << I18n.default_locale).uniq - [current_locale]
    status = Mailer::Widget.populate_mailer_widget_for_all_locales(mailer_widget, widget_params, other_locales)
    handle_success_and_failure_cases(status)
  end
end
