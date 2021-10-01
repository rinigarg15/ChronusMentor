class MatchReportAdminView < ActiveRecord::Base

  belongs_to :program
  belongs_to :admin_view
  validates :program, :admin_view, :section_type, :role_type, presence: true
  validates_uniqueness_of :role_type, :scope => [:program, :section_type]
end