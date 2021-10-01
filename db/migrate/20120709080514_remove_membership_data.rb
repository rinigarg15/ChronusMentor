class RemoveMembershipData< ActiveRecord::Migration[4.2]
 def up      
#   ActiveRecord::Base.connection.execute "SET AUTOCOMMIT=0;"
#   ActiveRecord::Base.transaction do
#    puts "REMOVE MEMBERSHIP DATA ##########################Start Time is - #{Time.now.strftime("%H:%M:%S")}"
#    profile_answer_count = ProfileAnswer.count
#    profile_question_count = ProfileQuestion.count
#    common_answer_count = CommonAnswer.count
#    common_question_count = CommonQuestion.count
#    membership_answers_count = MembershipAnswer.count
#    membership_questions_count = MembershipQuestion.count
#
#    MembershipAnswer.all.each do |mem_ans|
#     mem_ans.destroy
#    end
#    raise "MembershipAnswer count is not proper" unless CommonAnswer.count == common_answer_count-membership_answers_count
#    raise "ProfileAnswer count is not proper" unless ProfileAnswer.count ==profile_answer_count
#
#    MembershipQuestion.all.each do |mem_ques|
#     mem_ques.destroy
#    end
#    raise "MembershipQuestion count is not proper" unless CommonQuestion.count == common_question_count-membership_questions_count
#    raise "ProfileQuestion count is not proper" unless ProfileQuestion.count == profile_question_count
#    puts "REMOVE MEMBERSHIP DATA ##########################End Time is - #{Time.now.strftime("%H:%M:%S")}"
#   end
#   ActiveRecord::Base.connection.execute "SET AUTOCOMMIT=1;"
  end

  def down
  end
end
