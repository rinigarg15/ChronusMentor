Then /^I should see the radio button "([^"]*)" selected$/ do |button|
  assert page.evaluate_script("jQuery('##{button}').is(':checked')")
end

Then /^Then I enable "([^\"]*)" feature$/ do |feature|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  org.enable_feature(feature,true)
end

Then /^I send a mentoring offer$/ do
  steps %{
    When I visit the profile of "arun@albers.com"
    And I click "#mentor_profile .btn.dropdown-toggle"
    And I follow "Offer Mentoring"
    And I press "Offer Mentoring"
    Then I should see "Your offer for mentoring has been sent to arun albers for acceptance"
  }
end

And /^I accept the mentoring offer$/ do
  steps %{
    And I click ".pending_requests_notification_icon"
    Then I follow "Mentoring Offers"
    Then I should see "Good unique name"
    And I "Accept" the offer from "Good unique name"
    Then I should see "Congratulations on your mentoring connection with Good unique name"
    Then I should see "name & albers"
  }
end

And /^I create mentor offers$/ do
  program = Program.find_by(name: "Albers Mentor Program")
  program.organization.enable_feature(FeatureName::OFFER_MENTORING)
  program.update_attribute(:mentor_offer_needs_acceptance, true)
  program.groups.each do |group|
    mentee = group.students.first
    mentor = group.mentors.first
    create_mentor_offer(:mentor => mentor, :student => mentee, :program => program, :groups => group)
  end
end

And /^I click last mentor offer$/ do
  id = MentorOffer.last.id 
  step "I click \"#ct_mentor_offer_checkbox_#{id}\""
end

And /^I connect from users listing$/ do 
  step "I click by xpath \"//*[descendant::a[contains(text(),'arun albers')]]/../preceding-sibling::div/a[contains(text(), 'Connect')]\""
end

And /^the mentor offers report should be downloaded$/ do
  step "the download folder must have \"Mentoring\ Offers--#{DateTime.localize(Time.current, format: :csv_timestamp)}.csv\""
end
