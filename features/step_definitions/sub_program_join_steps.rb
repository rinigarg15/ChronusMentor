# encoding: utf-8

Given /^"([^\"]*)":"([^\"]*)" has the custom page "([^\"]*)"$/ do |subdomain, prog_root, page_title|
  program = get_program(prog_root, subdomain)
  program.pages.create!(:title => page_title, :content => "some content")
end

When /^the last join request is accepted in "([^\"]*)"$/ do |root|
  program = Program.find_by(root: root)
  mem_req = program.membership_requests.last
  mem_req.status = MembershipRequest::Status::ACCEPTED
  mem_req.accepted_role_names = mem_req.role_names
  mem_req.admin = program.admin_users.first
  mem_req.save!
end

And /^membership questions are not mandatory in "([^\"]*)"$/ do |name|
  p = Program.find_by(root: name)
  p.role_questions.membership_questions.update_all(required: 0)
end
