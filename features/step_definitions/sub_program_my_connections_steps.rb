Then /^I should (not )?see "([^\"]*)" as a "([^\"]*)" in the connection page$/ do |is_not, name, role|
  role_str = (role == "mentor") ? "Mentor" : "Student"
  role_str == "Mentor" ? page.execute_script("jQuery('.cjs_users_of_role_panel_header').click()") : page.execute_script("jQuery('.cjs_users_of_role_panel_header').last().click()")
  unless is_not
    within '#group_info' do
      step "I should see \"#{role_str}\""
      step "I should see \"#{name}\""
    end
  else
    step "I should not see \"{name}\""
  end
end