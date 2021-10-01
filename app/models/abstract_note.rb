# == Schema Information
#
# Table name: connection_private_notes
#
#  id                      :integer          not null, primary key
#  text                    :text(65535)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  created_at              :datetime
#  updated_at              :datetime
#  ref_obj_id              :integer
#  type                    :string(255)
#

class AbstractNote < ActiveRecord::Base

  self.table_name = 'connection_private_notes'

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  has_attached_file :attachment, PRIVATE_NOTE_STORAGE_OPTIONS
  has_many :recent_activities, :as => :ref_obj

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates :text, presence: true
  validates_attachment_size :attachment, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_attachment_content_type :attachment, :content_type => DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, :message => Proc.new { "flash_message.message.file_attachment_invalid".translate }
  validates_format_of :attachment_file_name, :without => DISALLOWED_FILE_EXTENSIONS, :message => Proc.new { "flash_message.general_file_attachment.file_attachment_name_invalid".translate }


  ##############################################################################
  # NAMED SCOPES
  ##############################################################################
  
  # Order with the latest notes first.
  scope :latest_first, -> { order("connection_private_notes.id DESC") }

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:attachment, :text, :notify_attendees],
    :update => [:attachment, :text]
  }

end
