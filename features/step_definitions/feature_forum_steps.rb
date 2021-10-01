Then /^I check mentors and students$/ do
  check("forum_access_role_names_mentor")
  check("forum_access_role_names_student")
end

Given /^no subscriptions yet$/ do
  Subscription.destroy_all
end

Then /^I should see "([^\"]*)" as a thread$/ do |post_content|
  within("div#post_#{Post.last.id}") do
    step "I should see \"#{post_content}\""
  end
end

And /^I set the topic title to "([^\"]*)"$/ do |title|
  within "#cjs_new_topic_modal" do
    step "I fill in \"topic_title\" with \"#{title}\""
  end
end

And /^I set the topic body to "([^\"]*)"$/ do |topic_body|
  sleep(2);
  page.execute_script("CKEDITOR.instances['new_topic_body'].setData('#{topic_body}')")
end

And /^I set the topic body of homepage to "([^\"]*)"$/ do |topic_body|
  sleep(2);
  page.evaluate_script("CKEDITOR.instances[Object.keys(CKEDITOR.instances)[0]].setData('#{topic_body}')")
end

And /^I add (\d+) comments with the text "([^\"]*)" to the last post$/ do |count, comment_text|
  last_post = Post.where(ancestry: nil).last
  count.to_i.times do
    within("#cjs_comment_form_#{last_post.id}") do
      step "I fill in \"cjs_post_comment_#{last_post.id}\" with \"#{comment_text}\""
      step "I press \"Send\""
      step "I wait for ajax to complete"
    end
  end
end

And /^I delete comment of the last post$/ do
  last_post = Post.where(ancestry: nil).last
  page.execute_script(%Q[jQuery("div#cjs_post_comments_#{last_post.id}").find(".cjs_less_comments").find(".caret:first").click()])
  step "I follow \"Delete\""
  step "I wait for ajax to complete"
  step "I confirm popup"
end

Given /^I edit the forum "([^"]*)"$/ do |forum|
  page.execute_script("jQuery('a[title=\"Edit\"]').mouseover()")
  steps %{
    And I click by xpath "//a[contains(text(),'#{forum}')]/following-sibling::*/a[@title='Edit']"
  }
end

Given /^I delete the forum "([^"]*)"$/ do |forum|
  page.execute_script("jQuery('a[title=\"Delete\"]').mouseover()")
  steps %{
    And I click by xpath "//a[contains(text(),'#{forum}')]/following-sibling::*/a[@title='Delete']"
    Then I should see "Are you sure you want to remove this forum?"
    And I click "a.btn.btn-primary.confirm"
  }
end

Then /^I visit forum with name "([^\"]*)"$/ do |forum|
  forum = Forum.find_by(name: forum)
  visit forum_path(forum, :root => "albers")
end