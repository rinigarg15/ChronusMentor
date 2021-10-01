# == Schema Information
#
# Table name: role_references
#
#  id           :integer          not null, primary key
#  ref_obj_id   :integer          not null
#  ref_obj_type :string(255)      not null
#  role_id      :integer          not null
#  created_at   :datetime
#  updated_at   :datetime
#

# A generic mapping model for role to any record.
class RoleReference < ActiveRecord::Base
  # ASSOCIATIONS
  # ----------------------------------------------------------------------------
  belongs_to :role
  belongs_to :ref_obj, :polymorphic => true, touch: true

  after_save :reindex_elasticsearch
  after_destroy :reindex_elasticsearch

  # VALIDATIONS
  # ----------------------------------------------------------------------------
  validates_uniqueness_of :role_id, :scope => [:ref_obj_id, :ref_obj_type]

  def self.es_reindex(role_reference)
    user_ids = Array(role_reference).select{|role_ref| role_ref.ref_obj_type == User.name }.collect(&:ref_obj_id).uniq
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)
    member_ids = User.where(id: user_ids).pluck(:member_id).uniq
    DelayedEsDocument.delayed_bulk_update_es_documents(Member, member_ids)
  end

  def reindex_elasticsearch
  	return unless self.ref_obj_type == User.name
  	self.class.es_reindex(self)
  end
end
