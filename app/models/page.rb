# == Schema Information
#
# Table name: pages
#
#  id                  :integer          not null, primary key
#  program_id          :integer
#  title               :string(255)
#  content             :text(16777215)
#  created_at          :datetime
#  updated_at          :datetime
#  position            :integer
#  visibility          :integer          default(0)
#  use_in_sub_programs :boolean          default(FALSE)
#  published           :boolean          default(TRUE)
#

class Page < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :content, :position, :visibility, :use_in_sub_programs, :published],
    :update => [:title, :content, :position, :visibility, :use_in_sub_programs, :published]
  }

  module Visibility
    BOTH      = 0
    LOGGED_IN = 1
    def self.all
      [LOGGED_IN, BOTH]
    end
  end

  sanitize_attributes_content :content, sanitize_scriptaccess: [:content]
  acts_as_list :scope => :program_id
  publicize_ckassets attrs: [:content]

  belongs_to_program_or_organization

  validates_presence_of :program_id
  validates_presence_of :title
  validates :visibility, inclusion: {in: Visibility.all}

  translates :title, :content

  scope :for_not_logged_in_users, -> { where(visibility: Visibility::BOTH)}
  scope :published, -> { where(published: true)}

  def publish!
    update_attributes!(published: true)
  end

  def publicly_accessible?
    self.published? && ( self.visibility == Visibility::BOTH || !self.program.logged_in_pages_enabled? )
  end
end
