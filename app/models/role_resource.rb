# == Schema Information
#
# Table name: role_resources
#
#  id                      :integer          not null, primary key
#  role_id                 :integer          not null
#  created_at              :datetime
#  updated_at              :datetime
#  resource_publication_id :integer          not null
#

class RoleResource < ActiveRecord::Base
  belongs_to :role
  belongs_to :resource_publication

  validates :role, :resource_publication, presence: true
  validates :role_id, :uniqueness => {:scope => :resource_publication_id}
end
