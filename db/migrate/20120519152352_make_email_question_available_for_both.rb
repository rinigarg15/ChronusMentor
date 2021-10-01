class MakeEmailQuestionAvailableForBoth< ActiveRecord::Migration[4.2]
  def up
    email_profile_question_ids = ProfileQuestion.select("id, question_text, question_type").where(:question_type => ProfileQuestion::Type::EMAIL).collect(&:id)
    ActiveRecord::Base.connection.execute("UPDATE role_questions SET available_for = #{RoleQuestion::AVAILABLE_FOR::BOTH} where profile_question_id IN (#{email_profile_question_ids.join(',')})") unless email_profile_question_ids.empty?          
  end

  def down
  end
end
