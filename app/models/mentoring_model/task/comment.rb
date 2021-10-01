# == Schema Information
#
# Table name: mentoring_model_task_comments
#
#  id                      :integer          not null, primary key
#  program_id              :integer
#  sender_id               :integer
#  content                 :text(65535)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  mentoring_model_task_id :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#

class MentoringModel::Task::Comment < ActiveRecord::Base
  include AttachmentUtils
  MASS_UPDATE_ATTRIBUTES = {
    :create => [:content, :attachment]
  }

  self.table_name = "mentoring_model_task_comments"
  belongs_to :mentoring_model_task, class_name: MentoringModel::Task.name, foreign_key: "mentoring_model_task_id"
  belongs_to :program
  belongs_to :sender, class_name: 'Member'
  has_one :mentoring_model_task_comment_scrap, :foreign_key => :mentoring_model_task_comment_id, :dependent => :destroy
  has_one :scrap, through: :mentoring_model_task_comment_scrap
  has_attached_file :attachment, TASK_COMMENT_STORAGE_OPTIONS
  validates_attachment_content_type :attachment, :content_type => DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, :message => Proc.new { "flash_message.message.file_attachment_invalid".translate }
  validates_attachment_size :attachment, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_format_of :attachment_file_name, :without => DISALLOWED_FILE_EXTENSIONS, :message => Proc.new { "flash_message.general_file_attachment.file_attachment_name_invalid".translate }
  
 
  validates_presence_of :content
  before_post_process :transliterate_file_name

  attr_accessor :notify

  def self.create_scrap_from_comment(comment_id)
    comment = MentoringModel::Task::Comment.find_by(id: comment_id)
    if comment.present?
      group = comment.mentoring_model_task.group
      scrap = group.scraps.new(comment.attributes.slice("program_id", "content"))
      scrap.subject = "feature.mentoring_model_task_comment.action.reg_title".translate(title: comment.mentoring_model_task.title)
      scrap.sender = comment.sender
      AttachmentUtils.copy_attachment(comment, scrap) if comment.attachment.exists?
      scrap.comment = comment
      scrap.create_receivers!
      scrap.save!
    end
  end

  def self.recent
    order "created_at DESC"
  end
end
