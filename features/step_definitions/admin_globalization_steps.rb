Given /^"([^\"]*)" language is( not)? enabled for the organization "([^\"]*)"$/ do |language_name, not_enable, organization_name|
    language = Language.find_by(title: language_name)
    organization = Organization.where(name: organization_name).first
    org_language = organization.languages.find_by(title: language_name)
    if org_language.present?
      org_language.destroy
    else
      OrganizationLanguage.create!(:organization   => organization,
        :enabled        => not_enable.present? ? OrganizationLanguage::EnabledFor::NONE : OrganizationLanguage::EnabledFor::ALL,
        :title          => "Telugu",
        :display_title  => "Telugulu",
        :language       => language)
    end
end

Then /^I enable "([^\"]*)" language for the organization "([^\"]*)"$/ do |language_name, organization_name|
    language = Language.find_by(title: language_name)
    organization = Organization.where(name: organization_name).first
    org_language = organization.languages.find_by(title: language_name)
    if org_language.present?
      org_language.update_attribute(:enabled, OrganizationLanguage::EnabledFor::ALL)
    else
      OrganizationLanguage.create!(:organization   => organization,
        :enabled        => OrganizationLanguage::EnabledFor::ALL,
        :title          => language.title,
        :display_title  => language.display_title,
        :language       => language)
    end
    organization.enable_feature("language_settings", true)
end

Then /^I change locale from "([^\"]*)" to "([^\"]*)"$/ do |from_locale, to_locale|
  steps %{
    Then I should see "#{from_locale}" within "#header_actions .dropdown"
    Then I follow "#{from_locale}" within "#header_actions .dropdown"
    Then I should see "#{to_locale}" within "#header_actions .dropdown"
    And I follow "#{to_locale}"
  }
end
