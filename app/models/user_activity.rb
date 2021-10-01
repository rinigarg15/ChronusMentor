class UserActivity < ActiveRecord::Base
  belongs_to :member
  belongs_to :organization
  belongs_to :user
  belongs_to :program

  include Exportable
end