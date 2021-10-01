Then /^I fill owners for group "([^"]*)" with "([^"]*)" in "([^"]*)":"([^"]*)"$/ do |group_name, user_name, org, prog_domain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,org)
  p = org.programs.find_by(root: prog_domain)
  group = p.groups.find_by(name: group_name)
  users = group.members
  to_be_owner = nil
  users.each do |u|
    to_be_owner= u if user_name == u.name(name_only: true)
  end
  # page.execute_script("jQuery('#group_owner_#{group.id}').val('#{to_be_owner.id}')")
  steps %{
    When I click "#s2id_group_owner_#{group.id} > .select2-choices"
    And I click on select2 result "#{user_name}"
  }
end