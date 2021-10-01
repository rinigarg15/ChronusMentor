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

class MembershipRequest::Instruction < AbstractInstruction

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:content],
    :update => [:content]
  }
end
