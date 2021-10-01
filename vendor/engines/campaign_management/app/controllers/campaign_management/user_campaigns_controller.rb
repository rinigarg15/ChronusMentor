class CampaignManagement::UserCampaignsController < ApplicationController
  include CampaignManagement::CampaignsHelper

  respond_to :html, except: [:disable]
  respond_to :json, only: :index

  allow :exec => :logged_in_at_current_level?
  allow :exec => :admin_at_current_level?

  before_action :build_presenter, only: [:index]
  before_action :fetch_campaign, only: [:disable, :destroy, :update, :edit, :details, :clone_popup, :clone, :start]
  before_action :require_super_user, only: [:import_csv, :export_csv]


  def index
    respond_to do |format|
      format.html
      format.json
    end
  end

  def new
    @campaign = current_program.user_campaigns.build
    @back_link = {:label => "feature.campaigns.label.Campaigns_v1".translate , :link => campaign_management_user_campaigns_path}
  end

  def create
    @campaign = current_program.user_campaigns.create(handle_campaign_params(:create))
    if @campaign.valid?
      redirect_to details_campaign_management_user_campaign_path(@campaign)
    else
      flash[:error] = "flash_message.campaign_management.campaign.create_failure".translate
      render action: :new
    end
  end

  def edit
    @back_link = {:label => "'#{@campaign.title}'", :link => details_campaign_management_user_campaign_path(@campaign)}
  end

  def update
    if @campaign.update_attributes(handle_campaign_params(:update, @campaign.state))
      flash[:notice] = "flash_message.campaign_management.campaign.update_success".translate
      redirect_to details_campaign_management_user_campaign_path(@campaign)
    else
      flash[:error] = "flash_message.campaign_management.campaign.update_failure".translate
      render action: :edit
    end
  end

  def import_csv
    stream = params[:campaign] && params[:campaign][:template]
    if stream.present?
      importer = CampaignManagement::Importer.new(File.read(stream.path, encoding: UTF8_BOM_ENCODING), current_program.id)
      if importer.program_id == nil
        flash[:error] = "flash_message.campaign_management.campaign.csv_parse_error".translate 
      else
        importer.import
        if importer.error_importing_campaigns.empty?
          flash[:notice] = "flash_message.campaign_management.campaign.csv_upload_successfully".translate  
        else
          error_notice = "feature.campaign.description.error_notice".translate
          error_notice += importer.error_importing_campaigns.collect(&:title).join(', ')
          error_notice += ". " + "feature.campaign.description.error_notice_tip".translate
          flash[:error] = error_notice
        end
      end
    else
      flash[:error] = "feature.campaign.description.error_file_absent".translate
    end

    redirect_to campaign_management_user_campaigns_path
  end

  def export_csv
    csv_file_name = "All_Campaigns_Template_#{DateTime.localize(Time.current, format: :csv_timestamp)}".to_html_id
    send_csv CampaignManagement::Exporter.new.export(current_program.id),
      :disposition => "attachment; filename=#{csv_file_name}.csv"
  end

  def start
    @campaign.activate!
    email_subjects, email_count = get_campaign_email_subjects_with_zero_duration(@campaign)
    notice_flash = "flash_message.campaign_management.campaign.activate_success_v1".translate
    notice_flash += " " + "flash_message.campaign_management.campaign_message.zero_duration_campaign_email_help_text".translate(count: email_count, email_subjects: email_subjects) if email_subjects.present?
    flash[:notice] = html_escape(notice_flash)
    redirect_to details_campaign_management_user_campaign_path(@campaign)
  end

  def disable
    @campaign.stop!
    flash[:notice] = "flash_message.campaign_management.campaign.disable_success_v1".translate
    redirect_to details_campaign_management_user_campaign_path(@campaign)
  end

  def destroy
    campaign_state = @campaign.state
    @campaign.destroy
    redirect_to campaign_management_user_campaigns_path(:state => campaign_state)
  end

  def details
    @back_link = {:label => "feature.campaigns.label.Campaigns_v1".translate , :link => campaign_management_user_campaigns_path(state: @campaign.state)}
    @tour_taken = OneTimeFlag.has_tag?(@current_user, OneTimeFlag::Flags::TourTags::CAMPAIGN_DETAILS_TOUR_TAG)
    @less_than_ie9 = is_ie_less_than?(9)
    # We are not posting any of these params from the frontend
    @overall_analytics, @analytic_stats = @campaign.get_analytics_details(params) unless @campaign.campaign_messages.empty?
  end

  def clone_popup
    @campaign.for_cloning = true
    render(partial: "campaign_management/user_campaigns/clone_popup", locals: {campaign: @campaign})
  end

  def clone
    state = params[:draft] && params[:draft].to_boolean ? CampaignManagement::AbstractCampaign::STATE::DRAFTED : CampaignManagement::AbstractCampaign::STATE::ACTIVE
    @cloned_campaign = CampaignManagement::UserCampaign.clone(@campaign, handle_campaign_params(:clone, state))
    email_subjects, email_count = get_campaign_email_subjects_with_zero_duration(@cloned_campaign) if @cloned_campaign.active?
    notice_flash = "flash_message.campaign_management.campaign.clone_success".translate(campaign_name: @cloned_campaign.title)
    notice_flash += " " + "flash_message.campaign_management.campaign_message.zero_duration_campaign_email_help_text".translate(count: email_count, email_subjects: email_subjects) if email_subjects.present?
    flash[:notice] = html_escape(notice_flash)
    redirect_to details_campaign_management_user_campaign_path(@cloned_campaign)
  end

  private
  def build_presenter
    @less_than_ie9 = is_ie_less_than?(9)
    @tour_taken = OneTimeFlag.has_tag?(@current_user, OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG)
    @presenter = CampaignManagement::CampaignPresenter.new(current_program, params, @tour_taken)
  end

  def fetch_campaign
    @campaign = current_program.user_campaigns.find(params[:id])
    @campaign.trigger_params = { 1 => [params[:admin_view_id].to_i] } if params[:admin_view_id].present?
  end

  def handle_campaign_params(action, state=CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    campaign_params = params.require(:campaign_management_user_campaign).permit(CampaignManagement::UserCampaign::MASS_UPDATE_ATTRIBUTES[action]).to_h
    campaign_params.merge!(trigger_params: get_admin_views, state: state)
  end

  def get_admin_views
    admin_view_id = params[:campaign_admin_views].split(",")[0].to_i if params[:campaign_admin_views] #CM_TODO should change when there are multiple admin views
    format_trigger_params(admin_view_id) unless admin_view_id.nil?
  end

  def format_trigger_params(admin_view_id) # CM_TODO should change this function accordingly
    trigger_params = {}
    trigger_params[1] = [admin_view_id]
    trigger_params
  end

end
