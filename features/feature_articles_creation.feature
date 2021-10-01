@javascript
Feature: Articles
  In order to guide the mentees in the system
  As a mentor
  I want to be able to write and manage articles

  Background: Start with the albers program
    Given the current program is "primary":"albers"

  Scenario: Publish a media article
    Given I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"
    And I scroll and click the element "div#a_media" below my visibility
    And I set the article title to "My new media article"
    And I set the article embed code to "This Youtube video"
    And I set the article content to "This is the video comment"
    And I publish the article
    Then I should see "My new media article"
    And I should see "My new media article"
    And I should see "This is the video comment"
    And I should not see "Mark as helpful"

  Scenario: Test back link article new page
    Given I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"
    And I scroll and click the element "div#a_media" below my visibility
    And I follow back link
    Then I should see "Write New Article"
    And I should see "Australia Kangaroo extinction"
    And I should see "India state economy"
 
  Scenario: Test back link article edit page
    Given I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    Then I should see "Australia Kangaroo extinction"
    When I follow "Australia Kangaroo extinction"
    Then I should see "Edit Article"
    When I follow "Edit Article"
    And I follow back link
    Then I should see "Write New Article"
    And I should see "Australia Kangaroo extinction"
    And I should see "India state economy"

  # This could not be tested anymore because of the extensive JS the page has
  Scenario: Publish a list article
    Given I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"
    And I scroll and click the element "div#a_list" below my visibility
    Then I should see "Add a Book"
    And I should see "Add a Website"
    
@cross_browser
  Scenario: Mentor should be able to save a text article draft, edit it and publish it
    # Start from scratch
    Given I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"

    # Save a draft
    And I scroll and click the element "div#a_text" below my visibility
    And I set the article title to "cucumber draft"
    And I set the general article content to "This is my new draft article"

    And I save the draft
    Then I should see the flash "Your draft has been saved. You can continue editing the article."
    And I should see "cucumber draft"
    And I should see "This is my new draft article" in the ckeditor "article_body"

    # Update the draft
    When I set the general article content to "This is my new draft article revision 2"
    And I save the draft
    Then I should see the flash "Your draft has been saved. You can continue editing the article."
    And I should see "cucumber draft"
    And I should see "This is my new draft article revision 2" in the ckeditor "article_body"
    
    # logout
    And I logout

    Given the current program is "primary":"albers"
    
    # Log in and go to users profile page
    When I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    And I follow "Write New Article"
    And I follow "2 article drafts"
    
    And I click on profile picture and click "View Profile"

    Then I should see "Articles (1)"    
    And I follow "Articles (1)"
    

    #Checking "Discard Draft" option
    Then I follow "Draft article"
    Then I should see "Draft article (draft)"
    And I follow "Discard Draft"
    Then I should see "Are you sure you want to discard this article draft? This cannot be undone."
    And I confirm popup
    Then I should see "Your draft has been discarded"
    And I should not see "Draft article"

    #Edit n publish a Draft
    Then I hover on tab "Advice"
    And I follow "Articles"
    And I follow "Write New Article"
    And I follow "1 article draft"
    #Try publishing the article and run into errors
    When I resume editing the article with title "cucumber draft"
    Then I should see "cucumber draft (draft)"

    # Try publishing the article and run into errors
    When I set the article title to ""
    And I publish the article
    Then I should see "can't be blank"
    
    And the article with title as "cucumber draft" should not have been published

    When I set the article title to "final article"
    And I publish the article
    Then I should see "final article"
    And the article "final article" should have been published in all programs

    # Update the published article
    When I follow "Edit Article"
    And I set the article title to "final article next"
    And I set the general article content to "final article body"
    Then I press "Update"
    Then I should see "final article next"
    And the article "final article next" should have been published in all programs
    And I should see the flash "Your article has been successfully published"

  @cross_browser  
  Scenario: Mentee should be able to view the existing articles, read one of them, mark it helpful and be able to comment on an article, view other articles written by the author in author profile
    Given I have logged in as "rahim@example.com"
    And There are a few articles in "primary"
    Then I hover on tab "Advice"
    When I follow "Articles"

    Then I should see articles listed

    When I follow "Australia Kangaroo extinction"
    Then I should be able to rate the current article
      
    Then I should see that I can revert back the rating

    When I post a new comment "Hi howdy"
    And I should see my comment "Hi howdy"

    When I click on the author of article "Australia Kangaroo extinction" of "primary":"albers"
    
    Then I should go to the profile of author of article "Australia Kangaroo extinction" of "primary":"albers"
    Then I should see other articles written by the author of article "Australia Kangaroo extinction"

  Scenario: Admin should be able to edit articles and comments
    Given I have logged in as "ram@example.com"
    And There are a few articles in "primary"
    And The first article has a few comments "primary":"albers"
    When I read the first article in the listing

    And I click "span.caret" within "div#comments_box"
    Then I should see "Delete"
    
    When I follow "Edit Article"
    And I set the article title to "New crazy title"
    And I press "Update"
    Then The title of the article should be "New crazy title"

@cross_browser
  Scenario: Upload a file to the program and edit it
    When I have logged in as "mentor_3@example.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    And I follow "Write New Article"
    Then I should see "Upload Article"

     And I scroll and click the element "div#a_upload" below my visibility
    Then I should see the page title "Upload New Article"
    And I set the article title to "SVN HowTo"
    And I set the attachment field "attachment_browser" to "pic_2.png"
    And I publish the article
    Then I should see the flash "Your article has been successfully published"
    And I should see the page title "SVN HowTo"
    Then I follow "Edit Article"
    Then I should see "Edit Article"
    Then I should see "pic_2.png"
    And I follow "Edit"
    And I set the attachment field "attachment_browser" to "test_pic.png"
    And I press "Update"
    Then I should see "test_pic.png"
    Then I should not see "pic_2.png"
    And I logout

    When I have logged in as "student_3@example.com"
    And I visit article with title "SVN HowTo" in "albers"
    And I should see "mentor_d chronus"
    And I should be able to rate the current article

@cross_browser @not_run_on_tddium
Scenario: Adding books and website article

    Given I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"
    And I create a new book and website article with the following details
    | title            | Webite and book article    |
    | website          | http://chronus.com         |
    | book             | Educated                   |
    | website comments | chronus website            |
    | book comments    | Education books            |
    | label            | website and books          |
    Then I should see "Your list has been successfully published"
    Then I should see "Posted less than a minute ago"
    Then I should see "By Tara Westover"
    And I follow "Edit Article"
    And I edit a new book and website article with the following details
    | title            | Webite and book article edited   |
    | website          | http://chronus.com               |
    | book             | Hello                            |
    | website comments | chronus website edited           |
    | book comments    | Education books edited           |
    | label            | website and books                |
    Then I should see "By Erin Entrada Kelly"
    Then I should see "chronus website edited"
    And I logout
    
@cross_browser
Scenario: Mentee able to publish an upload type article

    Given I have logged in as "mkr@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I should not see "Write New Article"
    And I logout
    Then I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Permissions"
    And I check "mentees_publish_articles"
    And I press "Save"
    And I logout
    Then I have logged in as "mkr@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"
    And I scroll and click the element "div#a_upload" below my visibility
    Then I should see the page title "Upload New Article"
    And I set the article title to "Upload type article"
    And I publish the article
    And I should see "can't be blank"
    And I set the attachment field "attachment_browser" to "test_file.csv"
    And I publish the article
    Then I should see the flash "Attachment content type is not one of"
    And I set the attachment field "attachment_browser" to "test_pic.png"    
    And I publish the article
    Then I should see the flash "Your article has been successfully published"
    Then I follow "Home"
    Then I should see "Upload type article" within "div#recent_activities"
    And I logout

@cross_browser
Scenario: Check Sort and Labels in articles

    Given I update the likes of the article "Capital city"
    And I update the views of the article "Australia Kangaroo extinction"
    Given I have logged in as "mkr@example.com"
    Then I hover on tab "Advice"
    When I follow "Articles"
    Then I select "Most helpful" from "sort_by"
    Then I should see "Capital city" in the xpath "//div[@class='list-group']/div[1]"
    Then I select "Most viewed" from "sort_by"
    Then I should see "Australia Kangaroo extinction" in the xpath "//div[@class='list-group']/div[1]"
    Then I follow "locations" within "div#SidebarRightContainer"
    Then I should not see "Australia Kangaroo extinction"
    And I logout
