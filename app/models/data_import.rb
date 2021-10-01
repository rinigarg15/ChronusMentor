# == Schema Information
#
# Table name: data_imports
#
#  id                       :integer          not null, primary key
#  organization_id          :integer
#  status                   :integer
#  failure_message          :string(255)
#  created_count            :integer
#  updated_count            :integer
#  suspended_count          :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  source_file_file_name    :string(255)
#  source_file_content_type :string(255)
#  source_file_file_size    :integer
#  source_file_updated_at   :datetime
#  log_file_file_name       :string(255)
#  log_file_content_type    :string(255)
#  log_file_file_size       :integer
#  log_file_updated_at      :datetime
#

class DataImport < ActiveRecord::Base

  module Status
    SUCCESS = 0
    FAIL = 1
    SKIPPED = 2

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  validates :source_file_file_name, :presence => true
  validates :status, inclusion: {in: Status.all}

  belongs_to_organization foreign_key: 'organization_id'

  has_attached_file :source_file, DATA_IMPORT_SOURCE_FILE_STORAGE_OPTIONS
  has_attached_file :log_file, DATA_IMPORT_LOG_FILE_STORAGE_OPTIONS
  do_not_validate_attachment_file_type :source_file, :log_file
  scope :recent_first, -> { order("data_imports.created_at DESC") }

  def success?
    self.status == Status::SUCCESS
  end

end
