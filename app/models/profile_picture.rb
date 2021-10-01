# == Schema Information
#
# Table name: profile_pictures
#
#  id                 :integer          not null, primary key
#  image_file_name    :string(255)
#  image_content_type :string(255)
#  image_file_size    :integer
#  image_updated_at   :datetime
#  image_remote_url   :string(255)
#  member_id          :integer
#  not_applicable     :boolean          default(FALSE)
#

# For downloading remote images
require 'open-uri'

# Represents the profile picture of an user.
class ProfilePicture < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    update: [:image_url, :image],
    user_create: [:image_url, :image]
  }

  ##############################################################################
  # ATTRIBUTES AND ASSOCIATIONS
  ##############################################################################
  belongs_to :member
  has_attached_file :image, {
    :styles => {:small => "35x35#", :medium => "50x50#", :large => "75x75#", :retina => "150x150#"},
    :source_file_options => { all: '-orient top-left' },
    :convert_options => { all: "-strip" },
    :default_style => :large,
    :default_url => "/assets/v3/user_:style.jpg",
    :processors => [:cropper],
    :whiny_thumbnails => true}.merge(USER_PICTURE_STORAGE_OPTIONS)

  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h, :rotate

  attr_accessor :image_url # Virtual attribute for handling remote image urls.
  # attr_protected :image_remote_url

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  before_validation :set_image_data
  validates_presence_of :member
  validates_presence_of :image_remote_url, :if => :image_url_provided?

  # Picture must be one of the valid types
  validates_attachment_presence :image, unless: lambda { |profile_picture| profile_picture.new_record? && profile_picture.not_applicable? }
  validates_attachment_content_type :image, :content_type => PICTURE_CONTENT_TYPES, unless: lambda { |profile_picture| profile_picture.new_record? && profile_picture.not_applicable? }

  after_save :reindex_es_user
  after_destroy :reindex_es_user

  def cropping?
    crop_x.present? && crop_y.present? && (crop_w.present? && crop_w.to_i != 0) && (crop_h.present? && crop_h.to_i != 0) && rotate.present?
  end

  def image_geometry(style = :original)
    @geometry ||= {}
    if USER_PICTURE_STORAGE_OPTIONS[:storage] == :s3
      @geometry[style] ||= Paperclip::Geometry.from_file(image.url(style))
    else
      @geometry[style] ||= Paperclip::Geometry.from_file(image.path(style))
    end
  end

  def get_width
    image_geometry.width.to_i
  end

  def reprocess_image
    image.reprocess!
  end

  def self.es_reindex(profile_picture)
    member_ids = Array(profile_picture).collect(&:member_id)
    user_ids = User.where(member_id: member_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_partial_update_es_documents(User, user_ids, User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list])
  end

  def reindex_es_user
    if self.new_record? || self.destroyed? || image_changed?
      ProfilePicture.es_reindex(self)
    end
  end

  ##############################################################################
  # PRIVATE METHODS
  ##############################################################################

  private

  def image_changed?
    self.saved_change_to_image_updated_at? || self.saved_change_to_image_file_size? || self.saved_change_to_image_file_name? || self.saved_change_to_image_content_type?
  end

  # Returns whether the remote image_url link is present.
  def image_url_provided?
    !self.image_url.blank?
  end

  # Prepares the picture data from remote image url.
  def set_image_data
    if image_url_provided?
      image_data = get_remote_image_data
      return false if image_data == false
      self.image = image_data
      self.image_remote_url = image_url
    elsif self.image?
      # If self.image is present, it means normal picture upload. Clear
      # image_remote_url
      self.image_remote_url = nil
    end
  end

  # Downloads the remote image data.
  def get_remote_image_data
    io = open(URI.parse(self.image_url))
    def io.original_filename; base_uri.path.split('/').last; end
    io.original_filename.blank? ? nil : io
  rescue # catch url errors with validations instead of exceptions (Errno::ENOENT, OpenURI::HTTPError, etc...)
    self.errors[:base] << "activerecord.custom_errors.profile_picture.invalid_url".translate
    return false
  end
end
