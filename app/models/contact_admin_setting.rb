# == Schema Information
#
# Table name: contact_admin_settings
#
#  id                       :integer          not null, primary key
#  label_name               :string(255)
#  content                  :text(16777215)
#  contact_url              :text(16777215)
#  program_id               :integer          not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  external_help_desk_email :string(255)
#  api_key                  :string(255)
#  mailbox_id               :string(255)
#

class ContactAdminSetting < ActiveRecord::Base
  belongs_to_program
  validates :program_id, uniqueness: true, presence: true

  translates :label_name, :content

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:label_name, :contact_url, :content],
    :update => [:label_name, :contact_url, :content]
  }
end
