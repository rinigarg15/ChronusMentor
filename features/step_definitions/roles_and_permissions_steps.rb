Then /^the view "([^\"]*)" permission should be enabled for "([^\"]*)" role$/ do |view_role_name, role_name|
  role_id = Program.find_by(root: "albers").find_role(role_name).id
  step "the \"program_role_permissions_#{role_id}_view_#{view_role_name}\" checkbox_id should be checked"
end

And /^I disable view "([^\"]*)" permission for "([^\"]*)" role$/ do |view_role_name, role_name|
  role_id = Program.find_by(root: "albers").find_role(role_name).id
  step "I uncheck \"program_role_permissions_#{role_id}_view_#{view_role_name}\""
end

Then /^I enable "([^\"]*)" permission for "([^\"]*)" role$/ do |permission_name, role_name|
  role_id = Program.find_by(root: "albers").find_role(role_name).id
  step "I check \"program_role_permissions_#{role_id}_#{permission_name}\""
  step "the \"program_role_permissions_#{role_id}_#{permission_name}\" checkbox_id should be checked"
end

Then /^I disable "([^\"]*)" permission for "([^\"]*)" role$/ do |permission_name, role_name|
  role_id = Program.find_by(root: "albers").find_role(role_name).id
  step "I uncheck \"program_role_permissions_#{role_id}_#{permission_name}\""
  step "the \"program_role_permissions_#{role_id}_#{permission_name}\" checkbox_id should not be checked"
end