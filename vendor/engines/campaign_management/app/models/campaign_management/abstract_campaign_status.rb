class CampaignManagement::AbstractCampaignStatus < ActiveRecord::Base
  self.table_name = "cm_campaign_statuses"

  module TYPE
    USER = "CampaignManagement::UserCampaignStatus"
    PROGRAMINVITATION = "CampaignManagement::ProgramInvitationCampaignStatus"
    SURVEY = "CampaignManagement::SurveyCampaignStatus"

    def self.all
      [USER, PROGRAMINVITATION, SURVEY]
    end
  end

  belongs_to :abstract_object, :polymorphic => true

  before_validation :set_abstract_object_type
  validates :type, inclusion: { :in => TYPE.all }, presence: true
  validates :abstract_object_id, :abstract_object_type, presence: true
end
