# == Schema Information
#
# Table name: resources
#
#  id         :integer          not null, primary key
#  program_id :integer          not null
#  title      :string(255)
#  content    :text(16777215)
#  created_at :datetime
#  updated_at :datetime
#  default    :boolean          default(FALSE), not null
#  view_count :integer          default(0)
#

class Resource < ActiveRecord::Base
  include ViewCount
  include ResourceElasticsearchSettings
  include ResourceElasticsearchQueries

  acts_as_rateable
  sanitize_attributes_content :content, sanitize_scriptaccess: [:content]
  belongs_to_program_or_organization(:organization)

  MARKED_HELPFUL_AND_VIEWED_COUNT = 3
  RESOURCE_PINNED_THRESHOLD = 3

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :content],
    :update => [:title, :content]
  }

  module RatingType
    HELPFUL = "0"
    UNHELPFUL = "1"
  end

  has_many :resource_publications, dependent: :destroy
  has_many :role_resources, through: :resource_publications
  has_many :programs, through: :resource_publications
  has_many :roles, :through => :role_resources

  alias_method :resource_for_role_ids, :role_ids

  validates :title, :content, :program_id, :presence => true

  translates :title, :content

  scope :default, -> { where(:default => true)}
  scope :non_default, -> { where(:default => false)}

  def is_organization?
    self.organization.is_a?(Organization)
  end

  def remove_rating(member)
    self.find_user_rating(member).destroy if self.rated_by_user?(member)
  end

  def create_rating(rating, member)
    self.remove_rating(member)
    self.ratings << Rating.new(:rating => rating, :member => member)
    self.save!
  end

  def get_helpful_count
    self.ratings.select{|rating| rating_helpful?(rating)}.count
  end

  def rating_helpful?(rating_object)
    rating_object.rating.to_s == Resource::RatingType::HELPFUL
  end
  
end
