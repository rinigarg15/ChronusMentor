Then /^I should be taken to my edit profile page$/ do
  me = controller.instance_eval("current_user")
  assert_select "div#edit_profile" do
    assert_select "div#profile"
  end
end

Then /^I should be redirected to "([^\"]*)"$/ do |arg|
  assert_redirected_to arg
  follow_redirect!
end

And /^I fill the location and experience values with "([^\"]*)"$/ do |loc_exp|
  member = Member.find_by(email: "custom@admin.com")
  loc_ques_id = member.organization.profile_questions.select{|ques| ques.location?}.first.id
  exp_ques_id = member.organization.profile_questions.select{|ques| ques.experience?}.first.id
  steps %{
    And I fill in "profile_answers_#{loc_ques_id}" with "#{loc_exp.split(',')[0]}"
    And I fill in "profile_answers[#{exp_ques_id}][new_experience_attributes][][company]" with "#{loc_exp.split(',')[1]}"
  }
end
