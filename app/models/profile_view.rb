class ProfileView < ActiveRecord::Base
  belongs_to :user, inverse_of: :profile_views
  belongs_to :viewed_by, class_name: User.name, inverse_of: :viewed_profile_views

  validates :user, :viewed_by, presence: true
end
