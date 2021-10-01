class ProgramLanguage < ActiveRecord::Base

  belongs_to :program
  belongs_to :organization_language

  validates :organization_language_id, :program, presence: true

  scope :enabled_for_all, -> { joins(:organization_language).where(organization_languages: { enabled: OrganizationLanguage::EnabledFor::ALL }) }
end
