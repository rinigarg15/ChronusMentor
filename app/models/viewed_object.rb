# == Schema Information
#
# Table name: viewed_objects
#
#  id                 :integer          not null, primary key
#  ref_obj_id         :integer
#  ref_obj_type       :string(255)
#  user_id            :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class ViewedObject < ActiveRecord::Base

  ############ ASSOCIATIONS #################

  belongs_to :ref_obj, polymorphic: true
  belongs_to :user

  ############# VALIDATIONS ##################

  validates :user_id, presence: true, uniqueness: {scope: [:ref_obj_id, :ref_obj_type]}
  validates :ref_obj, presence: true

end
