class AuthConfigSetting < ActiveRecord::Base

  module Section
    DEFAULT = 1
    CUSTOM = 2

    def self.all
      [DEFAULT, CUSTOM]
    end
  end

  MASS_UPDATE_ATTRIBUTES = {
    update: [
      :default_section_title,
      :default_section_description,
      :custom_section_title,
      :custom_section_description,
      :show_on_top
    ]
  }

  translates :default_section_title, :default_section_description, :custom_section_title, :custom_section_description

  belongs_to_organization foreign_key: "organization_id"

  validates :organization_id, presence: true
  validates :show_on_top, inclusion: { in: Section.all }

  def show_default_section_on_top?
    self.show_on_top == AuthConfigSetting::Section::DEFAULT
  end
end