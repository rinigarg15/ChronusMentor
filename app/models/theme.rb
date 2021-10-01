# == Schema Information
#
# Table name: themes
#
#  id               :integer          not null, primary key
#  css_file_name    :string(255)
#  css_content_type :string(255)
#  css_file_size    :integer
#  css_updated_at   :datetime
#  program_id       :integer
#  name             :string(255)
#  created_at       :datetime
#  updated_at       :datetime
#  mobile           :boolean          default(FALSE)
#  vars_list        :text(65535)
#

class Theme < ActiveRecord::Base
  DEFAULT = 'Default'
  MASS_UPDATE_ATTRIBUTES = {
    create: [:name, :css],
    update: [:name, :css]
  }
  attr_accessor :temp_path

  belongs_to_program_or_organization
  has_many :programs, :class_name => "AbstractProgram",  foreign_key: "theme_id"

  has_attached_file :css, STYLESHEET_STORAGE_OPTIONS

  before_validation :set_vars_list

  validates :name, presence: true
  validates :name, uniqueness: true, if: :is_global?

  # A loose validation on css_file_name beacuse default need not have any css file.
  validates :css_file_name, presence: true, unless: :is_default?
  validates_attachment_content_type :css, content_type: ['text/css'], message: Proc.new { "activerecord.custom_errors.theme.invalid_file_type".translate }, unless: :is_default?
  validate :check_vars_list

  scope :global, -> { where(:program_id=> nil) }
  scope :default, -> { where(:name => DEFAULT) }
  scope :available_themes, Proc.new { |program| where("program_id IN (?) or program_id IS NULL", program.is_a?(Program) ? [program.id, program.parent_id] : [program.id]).order("program_id ASC") }

  def is_global?
    self.program_id.nil?
  end

  def is_default?
    self.name == DEFAULT
  end

  def has_vars_list?
    !self.is_default?
  end

  def vars(force_refresh = false)
    @vars = (force_refresh || @vars.nil?) ? (self.vars_list.present? ? ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.vars_list)) : {}) : @vars
  end

  def set_vars_list
    return unless self.has_vars_list?
    self.vars_list = ThemeVarListExtractorService.new(self).get_vars_list
  end

  private

  def check_vars_list
    return unless self.has_vars_list?
    var_hash = ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.vars_list))
    ThemeBuilder::THEME_VARIABLES.keys.each do |theme_var|
      unless var_hash["$" + theme_var].present?
        self.errors.add(:vars_list, "activerecord.custom_errors.theme.incomplete_vars".translate)
        return
      end
    end
  end
end