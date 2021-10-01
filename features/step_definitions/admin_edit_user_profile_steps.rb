Then /^I mark "([^\"]*)" mandatory for mentors in "([^\"]*)"$/ do |question_text, program_root|
  prog = Program.find_by(root: program_root)
  role_q = prog.role_questions_for(RoleConstants::MENTOR_NAME).joins(:profile_question => :translations).where('profile_question_translations.question_text = ?', question_text).readonly(false).first
  role_q.update_attribute(:required, true)
end

Given /^"(.*?)" has not answered "(.*?)"$/ do |email, question_text|
  member = Member.find_by(email: email)
  organization = member.organization
  profile_answer = organization.profile_questions.where(question_text: question_text).first.profile_answers.where(ref_obj_id: member.id).first 
  profile_answer.destroy if profile_answer.present?
end