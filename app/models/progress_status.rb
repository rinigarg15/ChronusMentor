# == Schema Information
#
# Table name: progress_statuses
#
#  id              :integer          not null, primary key
#  ref_obj_id      :integer
#  ref_obj_type    :string(255)
#  for             :string(255)
#  completed_count :integer
#  maximum         :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class ProgressStatus < ActiveRecord::Base
  serialize :details

  belongs_to :ref_obj, :polymorphic => true
  has_many :counters, :class_name => "ProgressStatusCount", :dependent => :destroy

  validates :ref_obj, :maximum, presence: true
  validates :maximum, numericality: { greater_than: 0 }
  validates :completed_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: :maximum }, if: Proc.new{|ps| ps.completed_count.present?}

  module For
    module CsvImports
      VALIDATION = 'validation'
      IMPORT_DATA = 'import_data'
    end
    module User
      REMOVE_USER = 'remove_user'
    end
    module Group
      BULK_PUBLISH = 'bulk_publish'
    end
  end

  def percentage
    ((total_completed_count||0) * 100)/maximum
  end

  def completed?
    total_completed_count == maximum
  end

  def total_completed_count
    count + self.counters.pluck(:count).sum
  end

  def count
    completed_count||0
  end
end
