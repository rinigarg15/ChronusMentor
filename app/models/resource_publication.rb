# == Schema Information
#
# Table name: resource_publications
#
#  id                  :integer          not null, primary key
#  program_id          :integer
#  resource_id         :integer
#  visible             :boolean          default(TRUE), not null
#  position            :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  show_in_quick_links :boolean          default(FALSE)
#  admin_view_id       :integer

class ResourcePublication < ActiveRecord::Base
  before_validation :set_position

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:show_in_quick_links, :admin_view_id],
    :update => [:show_in_quick_links, :admin_view_id]
  }

  belongs_to_program
  belongs_to :resource
  belongs_to :admin_view

  has_many :role_resources, dependent: :destroy
  has_many :roles, through: :role_resources

  validates :program, :resource, :position, presence: true

  def self.es_reindex(resource_publication)
    DelayedEsDocument.do_delta_indexing(Resource, Array(resource_publication), :resource_id)
  end

  private

  def set_position
    return if self.position.present? || self.program.blank?
    self.position = self.program.resource_publications.maximum(:position).to_i + 1
  end
end
