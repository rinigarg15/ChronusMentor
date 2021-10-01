Then /^"([^\"]*)" should be active in the Show filter$/ do |text|
  within 'div#sidebarRight' do
    page.has_checked_field?(text)
  end
end

Then /^I should see "([^\"]*)" with status "([^\"]*)"$/ do |template, status|
  status_icon_span_class = {:enabled => 'enabled_icon', :disabled => 'disabled_icon'}
  within 'div.email_template' do
    within 'span' do
      page.has_css?("span.#{status_icon_span_class[status.to_sym]}")
    end
    step "I should see \"#{template}\""
  end
end

When /^I "([^\"]*)" the email template "([^\"]*)"$/ do |status, template|
  status_hash = {:enable => true, :disable => false}
  uid = template.constantize.mailer_attributes[:uid]
  temp = Organization.first.mailer_templates.find_or_initialize_by(uid: uid)
  temp.enabled = status_hash[status.to_sym]
  temp.save!
end

Then /^the email template "([^\"]*)" cannot be disabled$/ do |email_template_name|
  uid = email_template_name.constantize.mailer_attributes[:uid]
  steps %{
    Then I should not see "#status_icon_1x2znf78"
    When I follow "Customize" within "#mailer_template_#{uid}"
    Then the disabled "mailer_template_enabled_true" checkbox_id should be checked
    And element with id "#mailer_template_enabled_false" should be disabled
  }
end

Then /^the email template "([^\"]*)" should be "([^\"]*)"$/ do |template, status|
  status_hash = {:enabled => true, :disabled => false}
  uid = template.constantize.mailer_attributes[:uid]
  temp = Organization.first.mailer_templates.find_by(uid: uid)
  assert_equal status_hash[status.to_sym], !!temp.try(:enabled)
end

Then /^"([^\"]*)" email should be triggered$/ do |emails_count|
  assert_equal(ActionMailer::Base.deliveries.size, emails_count.to_i)
end

When /^I filter the category Content Related$/ do
  step "I choose \"Content Related\""
end

When /^I select the "([^\"]*)" category$/ do |catogery_name|
  category = case catogery_name
  when "Enrollment and user management"
    EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT
  when "Matching and engagement"
    EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT
  when "Community"
    EmailCustomization::NewCategories::Type::COMMUNITY
  when "General Administration"
    EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS
  when "Digest and weekly updates"
    EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES
  when "360 Degree Survey"
    EmailCustomization::NewCategories::Type::THREE_SIXTY_RELATED
  end
  # Then "I follow \".subcatogories_link\" within \"#catogery_#{category}\""
  step "I click \"#catogery_#{category} .subcatogories_link\""
end

When /^I customize "([^\"]*)" klass$/ do |klass|
  uid = klass.constantize.mailer_attributes[:uid]
  step "I follow \"Customize\" within \"#mailer_template_#{uid}\""
end

Then /^I should see simple textarea$/ do
  assert page.has_selector?("textarea", id: "mailer_widget_source", "data-skip-ckeditor" => true)
end

And /^I see that the subject and source are both nil in the template object$/ do
  template = Mailer::Template.last
  assert_nil template.source
  assert_nil template.subject
end

And /^I see that only the subject is not nil in the template object$/ do
  template = Mailer::Template.last
  assert_not_nil template.subject
  assert_not_nil template.source
end

And /^I see that only the source is not nil in the template object$/ do
  template = Mailer::Template.last
  assert template.translations.present?
  assert_not_nil template.source
  assert_not_nil template.subject
end

And /^I enable rollout for organization "([^\"]*)"$/ do |organization_subdomain|
  organization = get_organization(organization_subdomain)
  organization.update_attribute(:rollout_enabled, true)
end

Then /^I delete all rollout entries$/ do
  RolloutEmail.destroy_all
end

Then /^I should see "([^\"]*)" in the ckeditor "([^\"]*)"$/ do |value, id|
  data = page.evaluate_script("CKEDITOR.instances['#{id}'].getData()")
  assert_equal value, data
end

Then /^I close remote modal$/ do
  page.execute_script("jQuery('#remoteModal').modal('hide')");
end

Then /^I remove "([^\"]*)" auth config for "([^\"]*)"$/ do |auth_type, subdomain|
  organization = get_organization(subdomain)
  auth_config = organization.auth_configs.find_by(auth_type: auth_type)
  auth_config.destroy
end