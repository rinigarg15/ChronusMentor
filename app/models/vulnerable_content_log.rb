# == Schema Information
#
# Table name: vulnerable_content_logs
#
#  id                :integer          not null, primary key
#  original_content  :text(65535)
#  sanitized_content :text(65535)
#  member_id         :integer
#  ref_obj_id        :integer
#  ref_obj_type      :string(255)
#  ref_obj_column    :string(255)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class VulnerableContentLog < ActiveRecord::Base
  # Associations
  belongs_to :ref_obj, polymorphic: true
  belongs_to :member
  # Validations
  validates_presence_of :original_content, :ref_obj_type, :member_id, :ref_obj_column
end
