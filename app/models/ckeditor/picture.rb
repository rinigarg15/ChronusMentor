# == Schema Information
#
# Table name: ckeditor_assets
#
#  id                :integer          not null, primary key
#  data_file_name    :string(255)      not null
#  data_content_type :string(255)
#  data_file_size    :integer
#  assetable_id      :integer
#  assetable_type    :string(30)
#  type              :string(25)
#  guid              :string(10)
#  locale            :integer          default(0)
#  program_id        :integer
#  created_at        :datetime
#  updated_at        :datetime
#  login_required    :boolean          default(FALSE)
#

class Ckeditor::Picture < Ckeditor::Asset

  PROGRAM_CKPHOTOS_VIRUS_SCAN_OPTIONS = PROGRAM_CKPHOTOS_STORAGE_OPTIONS[:styles].present? ? { text: (PROGRAM_CKPHOTOS_STORAGE_OPTIONS.dig(:styles, :text) || {}).merge(processors: PROGRAM_CKPHOTOS_STORAGE_OPTIONS[:processors]) } : {}
  PROGRAM_CKPHOTOS_STORAGE_OPTIONS[:styles] = { content: '575>', thumb: '80x80#' }.merge(PROGRAM_CKPHOTOS_VIRUS_SCAN_OPTIONS)
  PROGRAM_CKPHOTOS_STORAGE_OPTIONS.delete(:processors)
  has_attached_file :data, PROGRAM_CKPHOTOS_STORAGE_OPTIONS

  validates_attachment_size :data, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE / ONE_MEGABYTE) }
  validates_attachment_presence :data
  validates_attachment_content_type :data, content_type: PICTURE_CONTENT_TYPES

  def url_content
    "#{self.organization.url(true)}/ck_pictures/#{self.id}"
  end
end