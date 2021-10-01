module CampaignManagement::AbstractCampaignState
  extend ActiveSupport::Concern

  included do
    validates :state, presence: true
    validates :state, inclusion: { :in => CampaignManagement::AbstractCampaign::STATE::ACTIVE..CampaignManagement::AbstractCampaign::STATE::DRAFTED }

    before_save :set_enabled_at
  end

  def stop!
    cleanup_items_when_not_active
    update_attributes!(state: CampaignManagement::AbstractCampaign::STATE::STOPPED)
  end

  # We are removing all existing jobs, clearig all statuses when not active
  def cleanup_items_when_not_active
    cleanup_campaign_jobs
    cleanup_campaign_statuses
  end

  def activate!
    update_attributes!(state: CampaignManagement::AbstractCampaign::STATE::ACTIVE, enabled_at: Time.zone.now)
  end

  def set_enabled_at
    if !self.drafted? && self.enabled_at.nil?
      self.enabled_at = Time.now
    end
  end
end