include ImportExportUtils

class CampaignManagement::Importer

  attr_accessor :error_importing_campaigns, :campaign_template_rows, :campaign_message_template_rows, :program_id
  include ImportExportUtils

  ITEM_TO_DATA_MODULE_MAPPER = {
    campaign_template: CampaignManagement::ImportExportUtils::CampaignTemplate,
    campaign_message_template: CampaignManagement::ImportExportUtils::CampaignMessageTemplate
  }
  DEFAULT_DATA_INTERPRETOR = (->(x,options){x.present? ? x.respond_to?(:strip) ? x.strip : x : x})

  def initialize(csv_content, program_id)
    @csv_content = csv_content
    begin
      @data = CSV.parse(@csv_content)
    rescue
      return self
    end

    @campaign_states = {}
    @campaign_referenced_by_title = {}
    @program_id = program_id
    @error_importing_campaigns = []
  end

  def import
    #extract_data_rows_from_csv_data(@data)
    items_header = [:campaign_template, :campaign_message_template]

    extract_data_rows_from_csv_data(self, @data, ITEM_TO_DATA_MODULE_MAPPER, items_header)

    populate_campaign_templates_and_update_title_references(@campaign_template_rows)

    populate_campaign_message_templates(@campaign_message_template_rows)

    self
  end

  private

  def populate_campaign_templates_and_update_title_references(campaign_template_rows)
    campaign_template_rows.each do |campaign_template_row_data|
      campaign_object = CampaignManagement::AbstractCampaign.new(:program_id => @program_id)
      populate_item_with_row_data!(:campaign_template, campaign_object, campaign_template_row_data)
      # before calling the above method we are not aware of the type of object, so we had to create 
      # AbstractCampaign object, however, it results in failure of a validation defined in abstract campaign model while saving it. Hence we are creating the object of specific type below.
      if campaign_object.type == "CampaignManagement::UserCampaign"
        campaign = CampaignManagement::UserCampaign.new(:program_id => @program_id)
      else
        campaign = CampaignManagement::ProgramInvitationCampaign.new(:program_id => @program_id)
        campaign.featured = true
      end
      campaign.state = campaign_object.state
      campaign.title = campaign_object.title
      campaign.trigger_params = campaign_object.trigger_params
      begin
        campaign.save!
      rescue
        @error_importing_campaigns << campaign
      end
      if campaign.id != nil
        @campaign_referenced_by_title[campaign.title] = campaign
      end
    end
  end

  def populate_campaign_message_templates(campaign_message_template_rows)
    campaign_message_template_rows.each do |campaign_message_template_row_data|
      campaign_message = CampaignManagement::AbstractCampaignMessage.new
      populate_item_with_row_data!(:campaign_message_template, campaign_message, campaign_message_template_row_data)
      campaign_message.sender_id = Program.find(@program_id).active_admins_except_mentor_admins.try(:first).try(:id)
      if campaign_message.source == nil || campaign_message.subject == nil
        next
      end
      begin
        email_template = Mailer::Template.new(:source => campaign_message.source, :subject => campaign_message.subject, :program_id => @program_id)
        email_template.belongs_to_cm = true
        CampaignManagement::AbstractCampaign.find(campaign_message.campaign_id).campaign_messages.create!(sender_id: campaign_message.sender_id, duration: campaign_message.duration, email_template: email_template)
      rescue
        false
      end
      campaign_message
    end
  end

  def populate_item_with_row_data!(item_key, item, row_data, campaign_referenced_by_title = @campaign_referenced_by_title)
    item_constants_module = ITEM_TO_DATA_MODULE_MAPPER[item_key]
    options = {
      campaign_referenced_by_title: campaign_referenced_by_title,
      program_id: @program_id
    }
    item_constants_module::FIELD_HEADER_ORDER.each_with_index do |attribute, index|
      item.send("#{attribute}=", (item_constants_module::DATA_INTERPRETOR[attribute] || DEFAULT_DATA_INTERPRETOR).call(row_data[index], options))
    end
  end

end