class LanguagesController < ApplicationController

  before_action :require_super_user, :except => [:set_current, :set_current_non_org]
  allow exec: :is_mobile_app?, only: :set_current_non_org

  # Language management is only for super users. Its not a program specific feature.
  skip_before_action :login_required_in_program,
                     :require_program,
                     :require_organization,
                     :load_current_organization,
                     :load_current_root,
                     :load_current_program,
                     :configure_program_tabs,
                     :except => [:set_current]

  newrelic_ignore_apdex :except => [:set_current]

  skip_before_action  :set_time_zone,
                      :configure_program_tabs,
                      :check_feature_access,
                      :check_browser,
                      :handle_terms_and_conditions_acceptance,
                      :login_required_in_program,
                      :require_program,
                      :back_mark_pages,
                      :handle_pending_profile_or_unanswered_required_qs,
                      :only => [:set_current]

  def index
    @languages = Language.ordered
  end

  def new
    @language = Language.new
  end

  def create
    @language = Language.new(language_params(:create))
    if @language.save
      redirect_to languages_path, :notice => 'flash_message.language.created'.translate
    else
      flash.now[:error] = 'flash_message.language.not_created'.translate
      render :action => :new
    end
  end

  def edit
    @language = Language.find(params[:id])
  end

  def update
    @language = Language.find(params[:id])
    if @language.update_attributes(language_params(:update))
      redirect_to languages_path, :notice => 'flash_message.language.edited'.translate
    else
      flash.now[:error] = 'flash_message.language.not_edited'.translate
      render :action => :edit
    end
  end

  def destroy
    @language = Language.find(params[:id])
    @language.destroy
    redirect_to languages_path, :notice => 'flash_message.language.deleted'.translate
  end

  # Sets the current locale for the user in session/db
  def set_current
    # Saving the current locale in DB as well if the user is logged in.

    if params[:locale].present?
      store_locale_to_member(params[:locale]) if wob_member
      store_locale_to_cookie(params[:locale])
    end

    unless params[:redirect_to].blank? || request.env["HTTP_REFERER"].blank?
      referer = request.env["HTTP_REFERER"]
      referer.gsub!(/set_locale=/, "set_locale_ignore=") if referer
      redirect_back(fallback_location: root_path)
    else
      redirect_to program_root_path
    end
  end

  def set_current_non_org
    store_locale_to_cookie(params[:locale], from_non_org: true)
    referer = request.env["HTTP_REFERER"]
    referer.gsub!(/set_locale=/, "set_locale_ignore=") if referer
    unless params[:redirect_to].blank? || request.env["HTTP_REFERER"].blank?
      redirect_back(fallback_location: root_path)
    else
      redirect_to mobile_v2_verify_organization_path
    end
  end

  private

  def language_params(action)
    params[:language].permit(Language::MASS_UPDATE_ATTRIBUTES[action])
  end

end
