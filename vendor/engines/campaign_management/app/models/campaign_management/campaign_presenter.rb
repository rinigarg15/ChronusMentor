class CampaignManagement::CampaignPresenter
  def initialize(program, params, tour_taken)
    @program, @params, @tour_taken = program, params.to_unsafe_h, tour_taken
  end

  def find
    @program.user_campaigns.find(@params[:id])
  end

  def list
    campaigns = @program.user_campaigns.select(campaigns_select).includes(:campaign_messages)
    campaigns = campaigns.where(state: target_state) if target_state
    if @params[:sort] && @params[:sort].any? { |k, s| self.class.db_sort_fields.include?(s[:field].to_s) }
      campaigns = campaigns.order(sort_params)
    else
      campaigns = for_active_state? ? campaigns.order("enabled_at DESC") : campaigns.order("created_at DESC")
    end
    sort_campaigns(assign_campaign_params(campaigns))
  end

  def total
    @total ||= @program.user_campaigns.count
  end

  def active
    @active ||= @program.user_campaigns.active.count
  end

  def disabled
    @disabled ||= @program.user_campaigns.stopped.count
  end

  def drafted
    @not_started ||= @program.user_campaigns.drafted.count
  end

  def target_state
    if !@tour_taken
      return CampaignManagement::AbstractCampaign::STATE::DRAFTED
    else
      @params[:state].blank? ? CampaignManagement::AbstractCampaign::STATE::ACTIVE : @params[:state].to_i
    end
  end

  def for_active_state?
    target_state == CampaignManagement::AbstractCampaign::STATE::ACTIVE
  end

  def show_analytics?
    target_state != CampaignManagement::AbstractCampaign::STATE::DRAFTED
  end

  private

  def assign_campaign_params(campaigns)
    campaigns.map do |campaign|
      analytics = campaign.calculate_overall_analytics
      assign_campaign_rates(analytics, campaign)
      campaign.emails_count = campaign.campaign_messages.count
      campaign
    end
  end

  def assign_campaign_rates(analytics, campaign)
    clicked = analytics[CampaignManagement::EmailEventLog::Type::CLICKED].to_i
    opened = analytics[CampaignManagement::EmailEventLog::Type::OPENED].to_i
    campaign.total_sent = campaign.valid_emails.count
    campaign.click_rate = campaign.total_sent > 0 ? clicked.to_f / campaign.total_sent : 0
    campaign.open_rate = campaign.total_sent > 0 ? opened.to_f / campaign.total_sent : 0
  end

  def campaigns_select
    # CM_TODO Replace with correct code
    [:id, :state, :created_at, :enabled_at, "0 AS open_rate", "0 AS click_rate", "0 AS total_sent", "0 AS emails_count"]
  end

  def sort_params
    sort_params = @params[:sort] || {}
    sort_params.map { |key, sort_param| "#{sort_param[:field]} #{sort_param[:dir]}" }
  end

  def sort_campaigns(campaigns)
    if @params[:sort]
      _, sort_param = @params[:sort].first
      field, direction = sort_param[:field], sort_param[:dir]
      proc = ('desc' == direction.to_s) ? desc_sort_proc : asc_sort_proc
      if self.class.ruby_sort_fields.include?(field.to_s)
        campaigns.sort! do |c1, c2|
          proc[c1.send(field), c2.send(field)]
        end
      end
    end
    campaigns
  end

  def asc_sort_proc
    Proc.new { |c1, c2| c1 <=> c2 }
  end

  def desc_sort_proc
    Proc.new { |c1, c2| c2 <=> c1 }
  end

  def self.ruby_sort_fields
    ["title", "click_rate", "open_rate", "total_sent", "emails_count"]
  end

  def self.db_sort_fields
    ["id", "created_at", "enabled_at", "state"]
  end
end
