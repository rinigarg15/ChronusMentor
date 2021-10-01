And /^I should see all the role options$/ do
  within '#apply_for' do
    steps %{
      And I should see "Mentor"
      And I should see "Student"
    }
  end
end
