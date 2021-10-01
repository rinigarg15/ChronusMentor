# == Schema Information
#
# Table name: progress_status_counts
#
#  id                 :integer          not null, primary key
#  progress_status_id :integer
#  count              :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class ProgressStatusCount < ActiveRecord::Base
  belongs_to :progress_status
end
