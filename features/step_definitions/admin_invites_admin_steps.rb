Then /^there is a private theme for "([^\"]*)"$/ do |org_subdomain|
  css_file = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
  Theme.create!({:name => 'Default', :css => css_file, :program => get_organization(org_subdomain)})
end

When /^I visit the organization admins page$/ do
  visit organization_admins_path
end

Given /^"([^\"]*)" is made the member of "([^\"]*)"$/ do |email, program_root|
  program = Program.find_by(root: program_root)
  member = Member.find_by(email: email)
  member.update_attribute(:organization_id, program.parent_id)
end