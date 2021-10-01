class DateAnswer < ActiveRecord::Base
# == Schema Information
#
# Table name: date_answers
#
#  id                 :integer          not null, primary key
#  ref_obj_id         :integer
#  ref_obj_type       :string(255)
#  answer             :date
#  created_at         :datetime         not null
#  updated_at         :datetime         not null

  ############ ASSOCIATIONS #################
  belongs_to :ref_obj, polymorphic: true

  ############# VALIDATIONS ##################
  validates :ref_obj, presence: true
  validates :answer, presence: true
end
