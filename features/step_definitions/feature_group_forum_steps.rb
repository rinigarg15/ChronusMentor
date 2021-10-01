Then /^I should see the mentoring area tab "([^\"]*)" selected$/ do |tab_name|
  within "div#mentoring_area_tabs" do
    step "I should see the tab \"#{tab_name}\" selected"
  end
end

Then /^I should see the mentoring area tab "([^\"]*)"$/ do |tab_name|
  page.should have_xpath("//*[@id='mentoring_area_tabs']/*/*/ul/li/a/span[contains(text(), '#{tab_name}')]")
end

Then /^I should not see the mentoring area tab "([^\"]*)"$/ do |tab_name|
  page.should_not have_xpath("//*[@id='mentoring_area_tabs']/*/*/ul/li/a/span[contains(text(), '#{tab_name}')]")
end

Then /^I should see the conversation following icon$/ do
  page.should have_xpath("//span[@class='cjs_group_topic_follow_icon'][descendant::i]")
end

Then /^I should not see the conversation following icon$/ do
  page.should_not have_xpath("//span[@class='cjs_group_topic_follow_icon'][descendant::i]")
end

Then /^I should be following the conversation "([^\"]*)"$/ do |topic_title|
  topic = fetch_topic(topic_title)
  page.should have_xpath("//a[contains(@class, 'cjs_follow_topic_link_#{topic.id}')][contains(text(), 'Following')]")
end

Then /^I should not be following the conversation "([^\"]*)"$/ do |topic_title|
  topic = fetch_topic(topic_title)
  page.should_not have_xpath("//a[contains(@class, 'cjs_follow_topic_link_#{topic.id}')][contains(text(), 'Following')]")
  page.should have_xpath("//a[contains(@class, 'cjs_follow_topic_link_#{topic.id}')][contains(text(), 'Follow')]")
end

Then /^I follow the conversation "([^\"]*)"$/ do |topic_title|
  topic = fetch_topic(topic_title)
  xpath = "//a[contains(@class, 'cjs_follow_topic_link_#{topic.id}')][contains(text(), 'Follow')]"
  step "I click by xpath \"#{xpath}\""
end

Then /^I unfollow the conversation "([^\"]*)"$/ do |topic_title|
  topic = fetch_topic(topic_title)
  xpath = "//a[contains(@class, 'cjs_follow_topic_link_#{topic.id}')][contains(text(), 'Following')]"
  step "I click by xpath \"#{xpath}\""
end

Then /^I can delete the conversation "([^\"]*)"$/ do |topic_title|
  topic = fetch_topic(topic_title)
  page.evaluate_script("jQuery('div.topic_#{topic.id} a:contains(\"Delete\")').length == 1")
end

Then /^I cannot delete the conversation "([^\"]*)"$/ do |topic_title|
  topic = fetch_topic(topic_title)
  page.evaluate_script("jQuery('div.topic_#{topic.id} a:contains(\"Delete\")').length == 0")
end

Then /^I can delete the post "([^\"]*)" in the conversation "([^\"]*)"$/ do |post_body, topic_title|
  topic = fetch_topic(topic_title)
  post = fetch_post(topic, post_body)
  page.evaluate_script("jQuery('div#post_#{post.id} a:contains(\"Delete\")').length == 1")
end

Then /^I cannot delete the post "([^\"]*)" in the conversation "([^\"]*)"$/ do |post_body, topic_title|
  topic = fetch_topic(topic_title)
  post = fetch_post(topic, post_body)
  page.evaluate_script("jQuery('div#post_#{post.id} a:contains(\"Delete\")').length == 0")
end

Then /^I follow the back to conversations listing icon$/ do
  xpath = "//a[@id='back_to_conversations']"
  step "I click by xpath \"#{xpath}\""
end

Then /^I click on the conversation "([^\"]*)"$/ do |topic_title|
  topic = fetch_topic(topic_title)
  step "I click \".topic_#{topic.id}\""
end

Then /^I add a new reply "([^\"]+)"$/ do |reply|
  step "I fill in \"message_content_post\" with \"#{reply}\""
end

private

def fetch_topic(topic_title)
  Topic.find_by(title: topic_title)
end

def fetch_post(topic, post_body)
  topic.posts.find_by(body: post_body)
end