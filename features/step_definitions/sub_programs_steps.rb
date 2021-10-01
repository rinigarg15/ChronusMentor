Then /I should not be shown program selector/ do
  #assert_false page.has_css?("#my_programs_container")
  assert_false page.all("#my_programs_container").any?
end

Then /I navigate to articles page/ do
  visit articles_path()
end

Then /I should see program selector containing "([^\"]*)" under "([^\"]*)"/ do |sub_prog_name, prog_name|
  within ".cui_program_selector" do
    within "a.cui_program_selector_org_name" do
      step "I should see \"#{prog_name}\""
    end
    step "I should see \"#{sub_prog_name}\""
  end
end

Then /I should see "([^\"]*)" as a sub-program administrator/ do |admin_name|
  within "#administrators" do
    step "I should see \"#{admin_name}\""
  end
end

Then /I should see "([^\"]*)" as an administrator in the organization/ do |admin_name|
  within "#administrators" do
    step "I should see \"#{admin_name}\""
  end
end

Then /I should see "([^\"]*)" as an organization administrator in the sub-program/ do |admin_name|
  within "#from_org" do
    step "I should see \"#{admin_name}\""
  end
end

But /I should not see "([^\"]*)" as an organization administrator in the sub-program/ do |admin_name|
  #assert_false page.has_css?("a", :text => "#{admin_name}")
  assert_false page.all("a", :text => "#{admin_name}").any?
end

Then /program setup session & host issue hack/ do
  page.execute_script("jQuery('input[type=\"submit\"]').trigger('click');")
  step "the current program is \"iit\":\"p1\""
  #visit edit_program_path(:root => "p1", :subdomain => "iit", :first_visit => "1")  
end  
   
Then /I fill in the domain name/ do  
  if ENV['TDDIUM']  
   step "I fill in \"program_organization_program_domain_domain\" with \"lvh.me\""  
  end   
end  
  
Then /I goto the first visit page/ do
  visit edit_program_path(:root => "main", :subdomain => "iit", :first_visit => "1")
end