# == Schema Information
#
# Table name: sections
#
#  id            :integer          not null, primary key
#  program_id    :integer
#  title         :string(255)
#  position      :integer
#  default_field :boolean
#  description   :text(16777215)
#

class Section < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description],
    :update => [:title, :description]
  }
  belongs_to_organization

  has_many :profile_questions, -> {order 'position, id'}, :dependent => :destroy
  has_many :role_questions, :through => :profile_questions

  validate :check_one_default_section

  validates_presence_of :organization, :title
  validate :check_default_section_position
  validate :check_section_title_uniqueness_for_org

  default_scope -> { includes(:translations) }
  scope :default_section, -> {where(:default_field => true)}

  translates :title, :description

  ##############################################################################
  # INSTANCE METHODS
  ##############################################################################

  def role_questions_for(role)
    self.role_questions.where(role_id: role.id)
  end

  def populate_section_attributes
    s_attributes = self.attributes
    s_attributes["title"] = self.title
    s_attributes["description"] = self.description
    return s_attributes
  end

  private

  def check_default_section_position
    if (self.default_field? && self.position != 1)
      self.errors.add(:position, "activerecord.custom_errors.section.default_reposition".translate)
    end
  end

  def check_one_default_section
    if self.default_field_changed?
      if self.organization && (self.organization.sections.default_section.size == 1 && self.default_field?)
        self.errors.add(:default_field, "activerecord.custom_errors.section.default_count".translate)
      end
    end
  end

  def check_section_title_uniqueness_for_org
    if(org = self.organization)
      !org.sections.collect(&:title).include?(self.title)
    end
  end
end