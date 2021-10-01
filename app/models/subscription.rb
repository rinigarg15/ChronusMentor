# == Schema Information
#
# Table name: subscriptions
#
#  id           :integer          not null, primary key
#  user_id      :integer
#  ref_obj_id   :integer
#  ref_obj_type :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#

class Subscription < ActiveRecord::Base
  # ASSOCIATIONS
  # ----------------------------------------------------------------------------
  belongs_to :user
  belongs_to :ref_obj, :polymorphic => true

  # VALIDATIONS
  # ----------------------------------------------------------------------------
  validates_uniqueness_of :user_id, :scope => [:ref_obj_id, :ref_obj_type]
end
