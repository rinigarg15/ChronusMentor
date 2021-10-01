# == Schema Information
#
# Table name: program_event_users
#
#  id               :integer          not null, primary key
#  user_id          :integer
#  program_event_id :integer
#

class ProgramEventUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :program_event
end
