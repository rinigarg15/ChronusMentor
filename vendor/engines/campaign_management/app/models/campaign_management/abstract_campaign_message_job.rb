class CampaignManagement::AbstractCampaignMessageJob < ActiveRecord::Base
  self.table_name = "cm_campaign_message_jobs"
  
  module TYPE
    USER = "CampaignManagement::UserCampaignMessageJob"
    PROGRAMINVITATION = "CampaignManagement::ProgramInvitationCampaignMessageJob"
    SURVEY = "CampaignManagement::SurveyCampaignMessageJob"

    def self.all
      [USER, PROGRAMINVITATION, SURVEY]
    end
  end

  belongs_to :abstract_object, :polymorphic => true

  before_validation :set_abstract_object_type
  validates :type, inclusion: { :in => TYPE.all }, presence: true
  validates :abstract_object_id, :abstract_object_type, presence: true
  validates :campaign_message_id, uniqueness: {scope: [:abstract_object_id, :abstract_object_type]}

  scope :pending, -> { where("failed = ?", false) }
  scope :ready_to_be_executed, -> { where("run_at < ?", Time.zone.now)}
end
