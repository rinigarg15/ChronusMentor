And /^I uncheck the group "([^\"]*)" in the listing$/ do |name|
  group_id = Group.find_by(name: name).id	
  step "I uncheck \"cjs_groups_record_#{group_id}\""  
end

And /^(.*) in the users listing$/ do |step_definition|
  within "#results_pane" do
    step step_definition
  end
end