class MoveProfileAnswersMemberIdToRefObj< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.connection.execute("UPDATE profile_answers SET ref_obj_id = member_id")
    ActiveRecord::Base.connection.execute("UPDATE profile_answers SET ref_obj_type='Member'")
  end

  def down  
  end
end
