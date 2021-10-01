class SetEmailPosToTwo< ActiveRecord::Migration[4.2]
  def up
  	Organization.active.each do |organization|
    	organization.email_question.update_attribute(:position, 2)
    end
  end

  def down
  end
end
