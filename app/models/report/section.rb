# == Schema Information
#
# Table name: report_sections
#
#  id              :integer          not null, primary key
#  title           :string(255)
#  description     :text(65535)
#  program_id      :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  position        :integer          default(1000)
#  default_section :integer
#

class Report::Section < ActiveRecord::Base
  self.table_name = "report_sections"

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description],
    :update => [:title, :description]
  }

  # Modules
  module DefaultSections
    RECRUITMENT = 0
    CONNECTION = 1
    ENGAGEMENT = 2
    OTHER = 3

    class << self
      def all_default_sections_in_order
        [RECRUITMENT, CONNECTION, ENGAGEMENT]
      end

      def ongoing_mentoring_related_sections
        [ENGAGEMENT]
      end
    end
  end

  # Associations
  belongs_to :program
  has_many :metrics, -> { order "report_metrics.position ASC" }, dependent: :destroy, class_name: Report::Metric.name, foreign_key: :section_id

  # Validations
  validates :program, :title, presence: true
  validates :default_section, inclusion: {in: DefaultSections.all_default_sections_in_order}, allow_nil: true

  # Scopes
  scope :non_ongoing_mentoring_related, -> { where("default_section IS ? OR default_section NOT IN (?)", nil, DefaultSections.ongoing_mentoring_related_sections)}

  def tile
    case default_section
    when DefaultSections::RECRUITMENT
      DashboardReportSubSection::Tile::ENROLLMENT
    when DefaultSections::ENGAGEMENT
      DashboardReportSubSection::Tile::GROUPS_ACTIVITY
    when DefaultSections::CONNECTION
      DashboardReportSubSection::Tile::MATCHING
    end
  end
end
