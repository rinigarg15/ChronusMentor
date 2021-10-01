When /^I select "([^\"]*)" view as user set for resource$/ do |view_title|
  admin_view_id = Program.find_by(root: "albers").admin_views.find_by(title: view_title).id
  steps %{
    When I choose radio button with label "Select a different user set"
    And I click ".select2-choice"
    And I click "#adminview_#{admin_view_id}"
  }
end