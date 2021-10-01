# == Schema Information
#
# Table name: program_assets
#
#  id                       :integer          not null, primary key
#  program_id               :integer
#  logo_file_name           :string(255)
#  logo_content_type        :string(255)
#  logo_file_size           :integer
#  logo_updated_at          :datetime
#  banner_file_name         :string(255)
#  banner_content_type      :string(255)
#  banner_file_size         :integer
#  banner_updated_at        :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  mobile_logo_file_name    :string(255)
#  mobile_logo_content_type :string(255)
#  mobile_logo_file_size    :integer
#  mobile_logo_updated_at   :datetime
#

class ProgramAsset < ActiveRecord::Base

  TEMP_BASE_PATH = "program_asset_files"
  module Type
    LOGO = 1
    BANNER = 2
    MOBILE_LOGO = 3
  end

  MAX_SIZE = {
    Type::LOGO => AttachmentSize::LOGO_OR_BANNER_ATTACHMENT_SIZE,
    Type::BANNER => AttachmentSize::LOGO_OR_BANNER_ATTACHMENT_SIZE,
    Type::MOBILE_LOGO => AttachmentSize::LOGO_OR_BANNER_ATTACHMENT_SIZE
  }

  ASSET_NAME = {
    Type::LOGO => 'logo',
    Type::BANNER => 'banner',
    Type::MOBILE_LOGO => 'mobile_logo'
  }

  belongs_to_program_or_organization
  has_attached_file :logo, StorageConstants::LOGO_STORAGE_OPTIONS
  has_attached_file :banner, StorageConstants::BANNER_STORAGE_OPTIONS
  has_attached_file :mobile_logo, MOBILE_LOGO_STORAGE_OPTIONS

  translates :logo_file_name, :logo_content_type, :logo_file_size, :banner_file_name, :banner_content_type, :banner_file_size

  validates :program_id, presence: true
  validates_attachment_content_type :logo, content_type: PICTURE_CONTENT_TYPES
  validates_attachment_size         :logo, less_than: MAX_SIZE[Type::LOGO], message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: MAX_SIZE[Type::LOGO]/ONE_MEGABYTE) }

  validates_attachment_content_type :banner, content_type: PICTURE_CONTENT_TYPES
  validates_attachment_size         :banner, less_than: MAX_SIZE[Type::BANNER], message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: MAX_SIZE[Type::BANNER]/ONE_MEGABYTE) }

  validates_attachment_content_type :mobile_logo, content_type: PICTURE_CONTENT_TYPES
  validates_attachment_size         :mobile_logo, less_than: MAX_SIZE[Type::MOBILE_LOGO], message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: MAX_SIZE[Type::MOBILE_LOGO]/ONE_MEGABYTE) }
  after_save :save_attachment_in_default_locale

  def get_attachment_url_and_attributes(attachment_type)
    attachment = self.send(attachment_type)
    if attachment.exists?
      url = if Rails.env.development? || Rails.env.test?
        open attachment.path.gsub(/\?\d+/,"")
      else
        URI.parse(attachment.url.gsub(/\?\d+/,""))
      end
      [url, self.attributes_for(attachment_type)]
    end
  end

  def attributes_for(attachment_type)
    [self.send("#{attachment_type}_file_name"), self.send("#{attachment_type}_file_size"), self.send("#{attachment_type}_content_type")]
  end

  private

  def save_attachment_in_default_locale
    return if I18n.locale == I18n.default_locale
    logo_url, logo_attributes = get_url_and_attrs_from_org_or_self(:logo)
    banner_url, banner_attributes = get_url_and_attrs_from_org_or_self(:banner)

    if logo_url.present? || banner_url.present?
      GlobalizationUtils.run_in_locale(I18n.default_locale) do
        self.reload
        unless self.logo.exists? && self.banner.exists?
          self.logo = logo_url if logo_url.present?
          self.banner = banner_url if banner_url.present?
          self.save!
        end
      end
    end
  end

  def get_url_and_attrs_from_org_or_self(attachment_type)
    url, attributes = if self.program.is_a?(Program)
      org_asset = self.program.organization.program_asset
      GlobalizationUtils.run_in_locale(I18n.default_locale) do
        org_asset.get_attachment_url_and_attributes(attachment_type) if org_asset.present?
      end
    end
    url, attributes = self.get_attachment_url_and_attributes(attachment_type) unless url.present? && attributes.present?
    return [url, attributes]
  end
end
