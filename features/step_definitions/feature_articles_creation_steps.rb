# encoding: utf-8
# Articles related macros
Given /^There are a few articles in "([^\"]*)"$/ do |sub|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,sub)
  assert org.articles.size > 0
end

Then /^I should see articles listed$/ do
  within "div#articles" do
    step "I should see \"Posted\""
  end
end

When /^I read the first article in the listing$/ do
  art = Article.first
  visit article_path(art, :root => "albers")
end

When /^I set the article title to "([^\"]*)"$/ do |title|
  step "I fill in \"article_article_content_title\" with \"#{title}\""
end

When /^I set the article embed code to "([^\"]*)"$/ do |title|
  step "I fill in \"article_article_content_embed_code\" with \"#{title}\""
end

When /^I set the article content to "([^\"]*)"$/ do |title|
  step "I fill in \"article_article_content_body\" with \"#{title}\""
end

When /^I set the general article content to "([^\"]*)"$/ do |title|
  sleep(2);
  page.evaluate_script("CKEDITOR.instances['article_body'].setData('#{title}')")
end


When /^I read the article with title "([^\"]*)"$/ do |art|
  steps %{
    And I click ".dropdown-toggle"
    And I follow "See more articles"
    And I follow "#{art}"
  }
end

Then /^I should be able to rate the current article$/ do
  step "I follow \"Like\""
end

Then /^I should see that I can revert back the rating$/ do
  #assert page.has_css?("a", :title => "You marked this article helpful (click to change)")
  #within("form#useful_form") do
  #  assert page.has_css?("input", :type => "hidden", :name => "useful", :value => -1)
  #end
  #And "I follow \"click to change\""
  step "I follow \"Like\""
end

When /^I post a new comment "([^\"]*)"$/ do |comment|
  # This test might fail if the focus is not left on the firefox window.
  page.execute_script("jQuery('#comment_body').focus()")

  steps %{
    Then I wait for animation to complete
    And I fill in "comment_body" with "#{comment}"
    And I press "Comment"
  }
end

When /^I should see my comment "([^\"]*)"$/ do |comment|
  within "div.cjs_comments_container" do
    step "I should see \"#{comment}\""
  end
end

Given /^The first article has a few comments "([^"]*)":"([^"]*)"$/ do |subdomain, prog_root|
  prog = get_program(prog_root, subdomain)
  art = Article.first
  a = art.publications.select {|a| a.program == prog}.first
  a.comments.create!(:user => a.program.mentor_users.first, :body => "Aasdsd")
  a.comments.create!(:user => a.program.student_users.first, :body => "Aasdsd")
  a.comments.create!(:user => a.program.student_users[1], :body => "Aasdsd")
  a.reload
  assert_equal(3, a.comments.size)
end

When /^I should be able to delete comments$/ do
  within (first("div#comments_section a.action")) do
    page.should have_xpath("//i[@title='Delete']")
  end
end

Then /^The title of the article should be "([^\"]*)"$/ do |title|
  # The title of the article is the page title too.
  step "I should see the page title \"#{title}\""
end

#Then /^The article with title "([^\"]*)" should be not be shown in the articles listing$/ do |title|
#  response.should_not contain(title)
#end

When /^I click on the author of article "([^"]*)" of "([^"]*)":"([^"]*)"$/ do |arg, org, prog|
  prog = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,org).programs.find_by(root: prog)
  ac = ArticleContent.find_by(title: arg)
  a = ac.articles.published_in(prog).first
  within('div#page_canvas .p-sm') do
    step "I follow \"#{a.author.name}\""
  end
end

Then /^I should go to the profile of author of article "([^\"]*)" of "([^"]*)":"([^"]*)"$/ do |art, org, prog|
  prog = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,org).programs.find_by(root: prog)
  ac = ArticleContent.find_by(title: art)
  a = ac.articles.published_in(prog).first
  step "I should see \"#{a.author.name}\""
  assert page.has_css? "div#mentor_profile"
end

When /^I select the programs "([^\"]*)"$/ do |arg|
  progs = []

  arg.split(",").each do |prog_info|
    subdomain, prog_root = prog_info.split(":")
    org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
    progs << org.programs.find_by(root: prog_root)
  end

  within "#program_list" do
    progs.each do |p|
      step "I click \"#publish_to_\""
    end
  end
end

Then /^I should see other articles written by the author of article "([^\"]*)"$/ do |art|
  prog = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary").programs.find_by(root: "albers")
  ac = ArticleContent.find_by(title: art)
  a = ac.articles.published_in(prog).first
  step "I should see \"#{a.author.name}\""
  within 'div#profile_side_bar' do
    step "I should see \"Articles\""
  end
end

When /^I visit the "([^\"]*)":"([^\"]*)" program article "([^\"]*)"$/ do |subdomain, prog_root, title|
  ac = ArticleContent.last
  prog = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain).programs.find_by(root: prog_root)
  program_article = ac.articles.published_in(prog).first
  visit article_path(program_article, :subdomain => subdomain, :root => prog.root)
end

When /^I delete the article$/ do
  step "I follow \"Delete article\""
end

When /^I publish the article$/ do
  step "I press \"Post\""
end

When /^I save the draft$/ do
  step "I press \"Save as draft\""
end

When /^I resume editing the article with title "([^\"]*)"$/ do |arg1|
  m = Member.find_by(email: "robert@example.com")
  article = m.articles.select {|a| a.title == arg1 }.first
  assert article.draft?
  within "div#draft_#{article.id}" do
    step "I follow \"Resume Editing\""
  end
end

Then /^the article with title as "([^"]*)" should not have been published$/ do |arg1|
  m = Member.find_by(email: "robert@example.com")
  article = m.articles.select {|a| a.title == arg1 }.first
  assert article.draft?
  assert_equal(1, article.article_content.articles.size)
end

Then /^the article "([^\"]*)" should have been published in all programs$/ do |arg1|
  m = Member.find_by(email: "robert@example.com")
  article = m.articles.select {|a| a.title == arg1 }.first
  assert article.published?
end

Given /^there are no articles in "([^\"]*)":"([^\"]*)"$/ do |subdomain, prog_root|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  program = org.programs.find_by(root: prog_root)
  program.articles.destroy_all
end

Given /^"([^\"]*)" can author articles in "([^\"]*)"$/ do |email, prog_root|
  program = Program.find_by(root: prog_root)
  member = Member.find_by(email: email)
  user = member.users.in_program(program).first
  user.add_role(RoleConstants::MENTOR_NAME)
  assert user.reload.can_write_article?
end

When /^I go to the new article page$/ do
  visit new_article_path
end

When /^I create a new book and website article with the following details$/ do |article|
  step "I scroll and click the element \"div#a_list\" below my visibility"
  article_hash=article.rows_hash()
  step "I fill in \"article_article_content_title\" with \"#{article_hash['title']}\""
  if(!article_hash["website"].nil?)
    steps %{
      And I follow "Add a Website"
      Then I should see "Website URL"
      And I fill xpath "//label[contains(text(),'URL ')]/following-sibling::*/input" with "#{article_hash['website']}"
      And I fill xpath "//label[contains(text(),'Your comments')]/following-sibling::*/textarea" with "#{article_hash['website comments']}"
      And I follow "Add a Book"
      And I fill xpath "//*[contains(@class, 'ui-autocomplete-input')]" with "#{article_hash['book']}"
      Then I wait for ajax to complete
      Then I should see "Educated: A Memoir"
      Then I choose "Educated: A Memoir" in autocomplete
      And I fill xpath "//div[@id='article_list_items']/div[@id='new_list_item'][2]//*[contains(@rows, '5')]" with "#{article_hash['book comments']}"
    }
  end
  step "I fill xpath \".//*[@id='s2id_article_article_content_label_list']/ul/li/input\" with \"#{article_hash['label']}\""
  #And "I press_enter for xpath \"//*[@class='tagit-new']/input\""
  step "I press \"Post\""
end


When /^I edit a new book and website article with the following details$/ do |article|
  article_hash=article.rows_hash()
  step "I fill in \"article_article_content_title\" with \"#{article_hash['title']}\""
  if(!article_hash["website"].nil?)
    steps %{
      Then I should see "Website URL"
      And I fill xpath "//label[contains(text(),'URL ')]/following-sibling::*/input" with "#{article_hash['website']}"
      And I fill xpath "//label[contains(text(),'Your comments')]/following-sibling::*/textarea" with "#{article_hash['website comments']}"
      And I fill xpath "//*[contains(@class, 'ui-autocomplete-input')]" with "#{article_hash['book']}"
      Then I wait for ajax to complete
      Then I should see "Hello, Universe"
      Then I choose "Hello, Universe" in autocomplete
      And I fill xpath "//div[@id='article_list_items']/div[@class='panel panel-default article_list_item'][2]//*[contains(@rows, '5')]" with "#{article_hash['book comments']}"
    }
  end
  step "I fill xpath \".//*[@id='s2id_article_article_content_label_list']/ul/li/input\" with \"#{article_hash['label']}\""
  #And "I press_enter for xpath \"//*[@class='tagit-new']/input\""
  step "I press \"Update\""
end


Then /^I should see "([^\"]*)" in the xpath "([^\"]*)"$/ do |text, path|
  row = page.find(:xpath, path)
  within row do
    step "I should see \"#{text}\""
  end
end

Then /^I update the likes of the article "([^\"]*)"$/ do |title|
  article_content = ArticleContent.find_by(title: title)
  article_content.articles.first.update_attributes(helpful_count: 10)
  step "I wait for \"Article\" Elastic Search Reindex"
end

Then /^I update the views of the article "([^\"]*)"$/ do |title|
  article_content = ArticleContent.find_by(title: title)
  article_content.articles.first.update_attributes(view_count: 10)
  step "I wait for \"Article\" Elastic Search Reindex"
end