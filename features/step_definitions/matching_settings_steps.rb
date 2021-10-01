When /^I check "([^\"]*)" in ongoing mentoring settings$/ do |label_text|
xpath="//label[contains(.,'#{label_text}')]/input"
steps %{
  And I click by xpath "#{xpath}"
  Then I press "Save"
  And I wait for ajax to complete
  }
end

Then /^I remove all match configs$/ do
  p = Program.find_by_root("albers")
  p.match_configs.each do |mc|
    mc.destroy!
  end
end

Then /^I recompute match scores$/ do
  @reindex_mongodb = true
  program = Program.find_by_root("albers")
  Matching.perform_program_delta_index_and_refresh(program.id)
end

When /^I unstub matching functions$/ do
  Matching.unstub(:perform_program_delta_index_and_refresh)
  @reindex_mongodb = false
end

When /^I stub matching functions$/ do
  Matching.stubs(:perform_program_delta_index_and_refresh)
end