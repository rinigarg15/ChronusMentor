# == Schema Information
#
# Table name: instructions
#
#  id         :integer          not null, primary key
#  program_id :integer          not null
#  content    :text(65535)
#  created_at :datetime
#  updated_at :datetime
#  type       :string(255)      not null
#

class AbstractInstruction < ActiveRecord::Base
  self.table_name = 'instructions'

  belongs_to :program
  translates :content
end