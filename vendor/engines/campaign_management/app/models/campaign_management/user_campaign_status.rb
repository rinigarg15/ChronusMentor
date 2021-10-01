class CampaignManagement::UserCampaignStatus < CampaignManagement::AbstractCampaignStatus 

  belongs_to :campaign,
             :foreign_key => "campaign_id",
             :class_name => "CampaignManagement::UserCampaign",
             :inverse_of => :statuses

  belongs_to :user, foreign_key: "abstract_object_id"

  validates :campaign, :user, presence: true

  # UserCampaignStatus objects are deleted in bulk using delete_all. Relook at that code, when you add any associations for this table

  private

  def set_abstract_object_type
    self.abstract_object_type = User.name
  end
end
