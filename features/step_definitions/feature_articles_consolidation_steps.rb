Then /^I visit article with title "([^\"]*)" in "([^\"]*)"$/ do |title, root|
  article_content = ArticleContent.find_by(title: title)
  article = article_content.articles.last
  visit article_path(article, root: root)
end

Then /^I go the "([^"]*)" listing page$/ do |arg1|
  visit articles_path
end

Then /I delete the first comment/ do
  within ("div#comments_section") do
    step "I click \"span.caret\""
  end
  step "I follow \"Delete\""
end