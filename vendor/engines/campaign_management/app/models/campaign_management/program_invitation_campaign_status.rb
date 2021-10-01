class CampaignManagement::ProgramInvitationCampaignStatus < CampaignManagement::AbstractCampaignStatus

  belongs_to :campaign,
             :foreign_key => "campaign_id",
             :class_name => "CampaignManagement::ProgramInvitationCampaign",
             :inverse_of => :statuses

  belongs_to :program_invitation, foreign_key: "abstract_object_id"

  validates :campaign, :program_invitation, presence: true

  private

  def set_abstract_object_type
    self.abstract_object_type = ProgramInvitation.name
  end
end
