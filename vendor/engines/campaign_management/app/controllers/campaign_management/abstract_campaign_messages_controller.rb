class CampaignManagement::AbstractCampaignMessagesController < ApplicationController
  include CampaignManagement::CampaignsHelper
  respond_to :json, only: :index
  
  allow :exec => :logged_in_at_current_level?
  allow :exec => :admin_at_current_level?
  
  before_action :fetch_campaign
  before_action :fetch_back_link
  before_action :fetch_campaign_message, :only => [:new, :update, :edit, :destroy]
  before_action :fetch_campaign_email_tags, :only => [:new, :update, :create, :edit]
  before_action :fetch_browser_version, :only => [:new, :edit]

  def new
    @tour_taken = OneTimeFlag.has_tag?(@current_user, get_campaign_message_tour_tag(@campaign))
    get_new_campaign_email_title
  end

  def create
    @campaign_message = @campaign.campaign_messages.new(campaign_message_params(:create))
    @campaign_message.build_email_template(email_template_params(:create))
    assign_user_and_sanitization_version(@campaign_message.email_template)
    @campaign_message.email_template.belongs_to_cm = true
    @campaign_message.mark_campaign_active = can_start_campaign?
    if @campaign_message.save
      if @campaign.is_user_campaign?
        if @campaign_message.mark_campaign_active
          email_subjects, email_count = get_campaign_email_subjects_with_zero_duration(@campaign)
          notice_flash = "flash_message.campaign_management.campaign_message.create_active_v2".translate(campaign_name: @campaign.title)
          notice_flash += " " + "flash_message.campaign_management.campaign_message.zero_duration_campaign_email_help_text".translate(count: email_count, email_subjects: email_subjects) if email_subjects.present?
        else
          notice_flash = "flash_message.campaign_management.campaign_message.create_success_user_campaign".translate(campaign_name: @campaign.title, email_subject: @campaign_message.email_template.subject)
          if @campaign.active? && @campaign_message.duration.zero?
            notice_flash += ". " + "flash_message.campaign_management.campaign_message.zero_duration_campaign_email_help_text".translate(count: 1, email_subjects: "'#{@campaign_message.email_template.subject}'" )
          end
        end
      else
        notice_flash = "flash_message.campaign_management.campaign_message.create_success".translate
      end
      flash[:notice] = html_escape(notice_flash)
      redirect_to @back_url
    else
      flash[:error] = "flash_message.campaign_management.campaign_message.create_failure".translate
      tour_taken = OneTimeFlag.has_tag?(@current_user, get_campaign_message_tour_tag(@campaign))
      fetch_instance_variables(tour_taken)
      get_new_campaign_email_title
      render :action => :new
    end
  end

  def edit
    @tour_taken = true
    get_edit_campaign_email_title
  end

  def update
    options = params[:campaign_management_abstract_campaign_message]
    @campaign_message.mark_campaign_active = can_start_campaign?
    assign_user_and_sanitization_version(@campaign_message.email_template)
    if update_campaign_message(options)
      flash[:notice] = @campaign_message.mark_campaign_active ? "flash_message.campaign_management.campaign_message.create_active_v2".translate(campaign_name: @campaign.title) : "flash_message.campaign_management.campaign_message.update_success_v2".translate
      redirect_to @back_url
    else
      flash[:error] = "flash_message.campaign_management.campaign_message.update_failure".translate
      fetch_instance_variables
      get_edit_campaign_email_title
      render :action => :edit
    end
  end

  def send_test_email
    options = params[:campaign_management_abstract_campaign_message]
    mailer_template_options = options[:mailer_template]
    sender_name = render_campaign_message_sender(params[:sender_id])
    mail_options = {}
    mail_options[:sender_name] = sender_name if sender_name != current_user.program.name
    mail_options[:level] = @campaign.is_a?(CampaignManagement::ProgramInvitationCampaign) ? ProgramInvitationCampaignEmailNotification.mailer_attributes[:level] : UserCampaignEmailNotification.mailer_attributes[:level]

    if mailer_template_options[:subject] && mailer_template_options[:source]
      email_template = Mailer::Template.new(:source => mailer_template_options[:source], :subject => mailer_template_options[:subject], :program_id => current_program.id)
      email_template.belongs_to_cm = true
      if email_template.valid? && email_template.validate_tags_and_widgets_through_campaign(@campaign.id)
        UserCampaignEmailNotification.preview(current_user, wob_member, current_user.program, current_user.program.organization, mail_options.merge(mailer_template_obj: email_template)).deliver_now()
        @campaign_message_email_success = "flash_message.campaign_management.campaign_message.email_success".translate(:email => wob_member.email)
      else
        @campaign_message_email_failure = email_template.errors.full_messages.to_sentence
      end
    end
  end

  def auto_complete_for_name
    options = {
      with: {
        "roles.id" => @current_program.get_role(RoleConstants::ADMIN_NAME).id,
        state: User::Status::ACTIVE,
        program_id: @current_program.id
      },
      match_fields: ["name_only.autocomplete"],
      source_columns: [:id, :name_only]
    }

    admin_users = User.get_filtered_users(params[:search].strip, options) if params[:search].present?
    admin_users ||= current_program.active_admins_except_mentor_admins

    admin_name_result = validate_program_name

    admin_users.try(:each) do |admin_user|
      admin_name_hash = Hash.new
      admin_name_hash["title"] = h(admin_user.name_only)
      admin_name_hash["id"] = admin_user.id.to_i
      admin_name_result << admin_name_hash
    end
    respond_to do |format|
      format.json do
        render :json => admin_name_result.to_json
      end
    end
  end


  def index
    @campaign_messages = @campaign.campaign_messages.order(:duration)
    respond_to do |format|
      format.html
      format.json
    end
  end

  def destroy
    @campaign_message.destroy
    render template: "campaign_management/abstract_campaign_messages/refresh"
  end


  private

  def campaign_message_params(action)
    params.require(:campaign_management_abstract_campaign_message).permit(CampaignManagement::AbstractCampaignMessage::MASS_UPDATE_ATTRIBUTES[action]).merge(sender_id: params[:sender_id])
  end

  def email_template_params(action)
    params[:campaign_management_abstract_campaign_message].require(:mailer_template).permit(CampaignManagement::AbstractCampaignMessage::MASS_UPDATE_ATTRIBUTES[:mailer_template][action]).merge(:program_id => current_program.id)
  end

  def validate_program_name
    admin_name_result = []
    if params[:search].blank? || (params[:search].present? && current_program.name.downcase().include?(params[:search].downcase()))
      admin_name_hash = Hash.new
      admin_name_hash["title"] = h(current_program.name)
      admin_name_hash["id"] = nil
      admin_name_result << admin_name_hash
    end
    admin_name_result
  end

  def update_campaign_message(options)
    mailer_template_options = options[:mailer_template]
    @campaign_message.email_template.update_attributes(email_template_params(:update)) && 
    @campaign_message.update_attributes(campaign_message_params(:update))
  end

  def fetch_campaign
    campaign_id = params[:user_campaign_id] || params[:program_invitation_campaign_id] || params[:survey_campaign_id]
    @campaign = CampaignManagement::AbstractCampaign.find(campaign_id)
  end

  def fetch_campaign_message
    if params[:id]
      @campaign_message = CampaignManagement::AbstractCampaignMessage.find(params[:id])
    else
      @campaign_message = CampaignManagement::AbstractCampaignMessage.new(email_template: Mailer::Template.new) 
    end
  end

  def fetch_browser_version
    @less_than_ie9 = is_ie_less_than?(9)
  end

  def fetch_campaign_email_tags
    @all_tags = @campaign.campaign_email_tags
  end

  def fetch_instance_variables(tour_taken = true)
    @tour_taken = tour_taken
    fetch_browser_version
  end

  def fetch_back_link
    back_link_and_url = get_back_link_label_and_url
    @back_url = back_link_and_url[:url]
    @back_link = {:label => back_link_and_url[:label], :link => @back_url}
  end

  def get_back_link_label_and_url
    back_link = {}

    case @campaign.type
    when CampaignManagement::AbstractCampaign::TYPE::USER
      back_link[:label] = "'#{@campaign.title}'"
      back_link[:url]  = details_campaign_management_user_campaign_path(@campaign)
    when CampaignManagement::AbstractCampaign::TYPE::PROGRAMINVITATION
      back_link[:label] = "feature.campaigns.label.invitations".translate
      back_link[:url]  = invite_users_path
    when CampaignManagement::AbstractCampaign::TYPE::SURVEY
      back_link[:label] = "feature.survey.content.Reminders".translate
      back_link[:url]  = reminders_survey_path(@campaign.survey)
    end
    back_link
  end

  def get_new_campaign_email_title
    case @campaign.type
    when CampaignManagement::AbstractCampaign::TYPE::USER
      @new_campaign_email_title = "feature.campaigns.header.new_campaign_title".translate(:title => @back_link[:label])
    when CampaignManagement::AbstractCampaign::TYPE::PROGRAMINVITATION
      @new_campaign_email_title = "feature.campaign_message.header.new_invitation_email_title".translate
    when CampaignManagement::AbstractCampaign::TYPE::SURVEY
      @new_campaign_email_title = "feature.survey.content.new_reminder_email".translate
    end
  end

  def get_edit_campaign_email_title
    case @campaign.type
    when CampaignManagement::AbstractCampaign::TYPE::USER
      @edit_campaign_email_title = "feature.campaigns.header.edit_campaign".translate(:title => @back_link[:label])
    when CampaignManagement::AbstractCampaign::TYPE::PROGRAMINVITATION
      @edit_campaign_email_title = "feature.campaign_message.header.edit_invitation_email_title".translate
    when CampaignManagement::AbstractCampaign::TYPE::SURVEY
      @edit_campaign_email_title = "feature.survey.content.edit_reminder_email".translate
    end
  end

  def can_start_campaign?
    @campaign.is_user_campaign? && params[:start_campaign] && params[:start_campaign].to_boolean
  end

end