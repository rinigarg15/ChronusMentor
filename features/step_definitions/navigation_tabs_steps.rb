Then /there are no features enabled/ do
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  FeatureName.all.each do |feature_name|
    org.enable_feature(feature_name,false)
  end
end

Given /^only "([^"]*)" features are enabled$/ do |feature|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  FeatureName.all.each do |feature_name|
    org.enable_feature(feature_name,feature.split(', ').include?(feature_name))
  end
end

Then /^I should see the tabs "([^"]*)" in that order and "([^"]*)" is a subtab$/ do |tabs, subtab|  
  within "ul#side-menu" do
    tabs.split(", ").each do |tab|
      unless subtab.split(', ').include?(tab)
        step "I hover on tab \"#{tab}\""
      end
    end
  end
end

Then /^I should see the subtabs "([^"]*)" under the tab "([^"]*)"$/ do |subtabs, tab|
  tab_name = tab.to_html_id
  within "ul#side-menu" do
    step "I should see \"#{tab}\""
    subtabs.split(", ").each do |subtab|
      step "I should see \"#{subtab}\""
    end
  end
end

Then /^I should not see the subtabs "([^"]*)" under the tab "([^"]*)"$/ do |subtabs, tab|
  tab_name = tab.to_html_id
  within "ul#side-menu" do    
    step "I should see \"#{tab}\""        
    subtabs.split(", ").each do |subtab|
      step "I should not see \"#{subtab}\""            
    end
  end
end