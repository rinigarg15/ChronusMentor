# == Schema Information
#
# Table name: article_contents
#
#  id                      :integer          not null, primary key
#  title                   :string(255)
#  body                    :text(4294967295)
#  type                    :string(255)
#  embed_code              :text(65535)
#  created_at              :datetime
#  updated_at              :datetime
#  status                  :integer
#  published_at            :datetime
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#

class ArticleContent < ActiveRecord::Base
  sanitize_html_attributes :body

  acts_as_taggable_on :labels

  module Status
    DRAFT = 0
    PUBLISHED = 1
  end

  module Type
    TEXT = "text"
    MEDIA = "media"
    LIST = "list"
    UPLOAD_ARTICLE = "upload_article"

    def self.all
      [TEXT, MEDIA, LIST, UPLOAD_ARTICLE]
    end
  end

  ALLOWED_UPLOAD_CONTENT_TYPES = [
    "application/pdf",
    "application/x-pdf",
    "image/png",
    "image/gif",
    "image/jpg",
    "image/jpeg",
    "application/msword",
    "application/vnd.ms-excel",
    "application/vnd.ms-powerpoint",
    'image/pjpeg', #IE MIME for jpg
    'image/x-png', #IE MIME for png
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', #XLSX
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',#PPTX
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document', #DOCX
    'application/rar',
    'application/x-rar',
    'application/x-rar-compressed',
    'application/zip',
    'application/x-zip',
    'application/x-zip-compressed',
    'application/octet-stream',
    'application/x-compress',
    'application/x-compressed',
    'multipart/x-zip'
  ]

  sanitize_attributes_content :body, :embed_code, sanitize_scriptaccess: [:embed_code]

  has_many :list_items, :dependent => :destroy, :class_name => "ArticleListItem", :autosave => true
  has_many :articles, :dependent => :destroy

  has_union   :programs,
              :class_name => "Program",
              :collections => [{:articles => :published_programs}]

  has_many :organizations, :through => :articles

  has_attached_file :attachment, ARTICLE_STORAGE_OPTIONS
  before_post_process :set_content_disposition

  validates_presence_of :type, :status

  validates_inclusion_of :type, :in => [Type::TEXT, Type::MEDIA, Type::LIST, Type::UPLOAD_ARTICLE]
  validates_inclusion_of :status, :in => [Status::DRAFT, Status::PUBLISHED]
  
  validates_presence_of :title, :if => :published?
  validates_presence_of :embed_code, :if => Proc.new { |a| a.published? && a.media? }

  validates_attachment_content_type :attachment, :content_type => ALLOWED_UPLOAD_CONTENT_TYPES
  validates_attachment_size :attachment, less_than_or_equal_to: AttachmentSize::END_USER_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_format_of :attachment_file_name, :without => DISALLOWED_FILE_EXTENSIONS, :message => Proc.new { "flash_message.general_file_attachment.file_attachment_name_invalid".translate }

  validates_associated :list_items, :message => Proc.new { "activerecord.custom_errors.article.are_invalid".translate }, :if => Proc.new { |a| a.published? && a.list? }
  validate :check_if_list_is_empty, :if => Proc.new { |a| a.published? && a.list? }
  validate :check_attachment_is_present, :if => Proc.new { |a| a.uploaded_content? }

  after_update :save_list_items
  after_save :es_reindex_article

  scope :published, -> { where(:status => Status::PUBLISHED) }

  # To prevent 'type' from being interpreted as STI column.
  self.inheritance_column = 'type__'

  def published?
    self.status == Status::PUBLISHED
  end

  # has the article been published at least once?
  def published_once?
    not self.published_at.nil?
  end

  def draft?
    self.status == Status::DRAFT
  end

  def media?
    self.type == Type::MEDIA
  end

  def list?
    self.type == Type::LIST
  end

  def uploaded_content?
    self.type == Type::UPLOAD_ARTICLE
  end

  # Return the column 'type'
  def type
    self.attributes["type"]
  end
  
  def new_listitem_attributes=(listitem_attributes)
    # Skip if everything is left blank
    listitem_attributes.each_pair do |temporary_id, item|
      # Ignore empty items
      next if item[:title].blank? and item[:content].blank? and item[:description].blank?
      item = item.permit(:title, :content, :description, :type_string) if item.is_a?(ActionController::Parameters)
      # To reject newly created items while updating or marking for deletion of existing list items
      item[:marked_as_new_item] = true
      list_items << item[:type_string].constantize_only(ArticleListItem.valid_types_as_strings).new(item)
    end
  end

  def existing_listitem_attributes=(listitem_attributes)
    existing_items = list_items.reject(&:marked_as_new_item)
    existing_items.each do |list_item|
      attributes = listitem_attributes[list_item.id.to_s]
      attributes = attributes.permit(:title, :content, :description, :type_string) if attributes.is_a?(ActionController::Parameters)
      if attributes
        list_item.attributes = attributes
      else
        # Don't delete it yet. Just mark it deleted
        list_item.mark_for_destruction
      end
    end
  end

  private
  
  def check_if_list_is_empty
    if self.list_items.blank? || self.list_items.all?(&:marked_for_destruction?)
      self.errors[:base] << "activerecord.custom_errors.article.list_blank".translate
    end
  end

  # Checks whether the attachment is present for upload type article.
  def check_attachment_is_present
    unless self.attachment?
      self.errors.add(:attachment, "activerecord.custom_errors.article.blank".translate)
    end
  end

  def save_list_items
    # Save changes on the other existing items
    list_items.each do |list_item|
      list_item.article_content = self
      list_item.save(:validate => false)
    end
  end

  def set_content_disposition
    self.attachment.options.merge({:s3_headers => {"Content-Disposition" => "attachment; filename="+self.attachment_file_name}})
  end

  def self.es_reindex(article_content)
    article_ids = Article.where(article_content_id: Array(article_content).collect(&:id)).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Article, article_ids)
  end

  def es_reindex_article
    if self.saved_change_to_title? || self.saved_change_to_body? || self.saved_change_to_label_list? || self.saved_change_to_status?
      self.class.es_reindex(self)
    end
  end
end