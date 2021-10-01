class FeedImportConfiguration < ActiveRecord::Base

  belongs_to :organization

  module Frequency
    DAILY = 1.day.to_i
    WEEKLY = 7.days.to_i

    def self.all
      [DAILY, WEEKLY]
    end
  end

  scope :enabled, -> { where(enabled: true) }
  scope :daily, -> { where(frequency: Frequency::DAILY) }
  scope :weekly, -> { where(frequency: Frequency::WEEKLY) }

  validates :organization, :sftp_user_name, presence: true
  validates :frequency, inclusion: { in: Frequency.all }

  def get_config_options
    return {} if self.configuration_options.blank?
    ActiveSupport::HashWithIndifferentAccess.new(Marshal.load(Base64.decode64(self.configuration_options)))
  end

  def set_config_options!(options)
    return nil if options.blank?
    options = ActiveSupport::HashWithIndifferentAccess.new(options)
    process_config_options!(options)
    self.configuration_options = Base64.encode64(Marshal.dump(options))
    self.save!
  end

  def get_source_options
    return {} if self.source_options.blank?
    ActiveSupport::HashWithIndifferentAccess.new(Marshal.load(Base64.decode64(self.source_options)))
  end

  def set_source_options!(options)
    return nil if options.blank?
    self.source_options = Base64.encode64(Marshal.dump(ActiveSupport::HashWithIndifferentAccess.new(options)))
    self.save!
  end

  def enable!
    self.update_attributes!(enabled: true)
  end

  def disable!
    self.update_attributes!(enabled: false)
  end

  def set_frequency!(frequency)
    self.update_attributes!(frequency: frequency)
  end

  private
  def process_config_options!(options)
    return unless options["secondary_questions_map"].present?

    options["secondary_questions_map"] = options["secondary_questions_map"].to_h.stringify_keys
  end
end