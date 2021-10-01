class CampaignManagement::SurveyCampaignStatus < CampaignManagement::AbstractCampaignStatus

  belongs_to :campaign,
             :foreign_key => "campaign_id",
             :class_name => "CampaignManagement::SurveyCampaign",
             :inverse_of => :statuses

  validates :campaign, presence: true

  private

  def set_abstract_object_type
    self.abstract_object_type ||= campaign.abstract_object_klass.name
  end
end
