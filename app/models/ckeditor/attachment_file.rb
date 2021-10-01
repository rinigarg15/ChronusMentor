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

class Ckeditor::AttachmentFile < Ckeditor::Asset
  has_attached_file :data, PROGRAM_CKRESOURCES_STORAGE_OPTIONS

  validates_attachment_size :data, less_than: AttachmentSize::ADMIN_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::ADMIN_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_attachment_presence :data
  validates_attachment_content_type :data, :content_type => DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, :message => Proc.new { "flash_message.message.file_attachment_invalid".translate }
  validates_format_of :data_file_name, :without => DISALLOWED_FILE_EXTENSIONS, :message => Proc.new { "flash_message.general_file_attachment.file_attachment_name_invalid".translate }


  def url_thumb
    @url_thumb ||= Ckeditor::Utils.filethumb(filename)
  end

  def url_content
    "#{self.organization.url(true)}/ck_attachments/#{self.id}"
  end
end
