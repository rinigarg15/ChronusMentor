# == Schema Information
#
# Table name: feed_exporters
#
#  id                 :integer          not null, primary key
#  program_id         :integer
#  frequency          :float(24)        default(1.0)
#  sftp_account_name  :string(255)

class FeedExporter < ActiveRecord::Base
  include ChronusS3Utils

  module Frequency
    DAILY = 1.day.to_i
    WEEKLY = 7.days.to_i

    def self.all
      [DAILY, WEEKLY]
    end
  end

  ROLE_SEPARATOR = "; "

  belongs_to_organization
  has_many :feed_exporter_configurations, class_name: "FeedExporter::Configuration", dependent: :destroy
  has_many :enabled_feed_exporter_configurations, -> {where(enabled: true)}, class_name: "FeedExporter::Configuration"

  validates :program_id, presence: true, uniqueness: true
  validates :frequency, inclusion: { in: Frequency.all }

  scope :daily, -> { where(frequency: Frequency::DAILY) }
  scope :weekly, -> { where(frequency: Frequency::WEEKLY) }

  def export_and_upload
    timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
    generate_csv(timestamp)
  end

  private

  def generate_csv(timestamp)
    self.enabled_feed_exporter_configurations.each do |configuration|
      file_name = configuration.get_file_name(timestamp)
      data = configuration.get_data
      CSV.open("#{Rails.root}/tmp/#{file_name}", "w") do |csv|
        if data.first.present?
          csv << data.first.keys
          data.each { |data_item| csv << data_item.values.flatten }
        end
      end
      upload_to_s3(file_name)
    end
  end

  def upload_to_s3(file_name)
    # If new account is being configured for reverse sftp feed, then export_accounts in feed_s3.yml have
    # to be updated with the configured sftp_account_name
    return unless sftp_account_name.present?

    file_path = "#{Rails.root}/tmp/#{file_name}"

    s3_credentials = YAML::load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)[Rails.env]
    S3Helper.transfer(file_path, "#{sftp_account_name}/downloads", s3_credentials["customer_feed_bucket"], url_expires: 7.days)
  end
end