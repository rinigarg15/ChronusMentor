@user
Feature: Guidance Popup for a mentee.

@javascript
Scenario: Student first login and sees welcome popup
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "student"
    Given the current program has no announcements for students
    When I have logged in as "ram@example.com"
    And I logout
    When Admin sends program invitation email to "sarat_student@example.com" as "student"
    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Student."
    Then I fill in "member_first_name" with "student"
    Then I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    And I press "Proceed" within "#general_profile"
    And I logout

    # logging in again should show the student profile edit page
    When I have logged in as "sarat_student@example.com"
    Then I answer the education experience questions for "sarat_student@example.com"
    And I press "Proceed"
    Then I answer the required questions for "sarat_student@example.com"
    And I press "Proceed"
    Then I visit home page with guidance popup experiment enabled
    Then I should see "Welcome, student me"
    Then I should see "Congratulations! You are just a few steps away from finding your mentor."
    Then I should see "1.Review Recommendations"
    Then I should see "Learn more about potential mentors by reviewing their profiles for compatibility with your preferences. Check out detailed profiles for as many mentors as you can to understand the options available to you. Around 10 to 15 is a good start."
    Then I should see "2.Connect with your Mentors"
    Then I should see "Students are 78% more likely to find the right mentor by sending out 3 or more requests. Reach out to atleast 3 mentors with a personalized greeting and a description of your needs and how they might be able to help."
    Then I should see "3.Build your Favorite Mentors List"
    Then I should see "Add a few mentors to your favorites list in case your first choice of mentors cannot accept your requests. Only you can see this list and mentors are not notified when you add them."
    Then I follow "Get Started"
    Then I should see "Mentors"

 @javascript
Scenario: Student goes to mentors listing and sees the guidance popup
    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I follow "Mentors"
    And I hover over class "cjs_guidance_popup"
    Then I should see "Click here for more information on finding a mentor"
    And I click ".cjs_guidance_popup"
    Then I should see "Welcome, student example"
    Then I should see "Congratulations! You are just a few steps away from finding your mentor."
    Then I should see "1.Review Recommendations"
    Then I should see "Learn more about potential mentors by reviewing their profiles for compatibility with your preferences. Check out detailed profiles for as many mentors as you can to understand the options available to you. Around 10 to 15 is a good start."
    Then I should see "2.Connect with your Mentors"
    Then I should see "Students are 78% more likely to find the right mentor by sending out 3 or more requests. Reach out to atleast 3 mentors with a personalized greeting and a description of your needs and how they might be able to help."
    Then I should see "3.Build your Favorite Mentors List"
    Then I should see "Add a few mentors to your favorites list in case your first choice of mentors cannot accept your requests. Only you can see this list and mentors are not notified when you add them."
    Then I follow "Get Started"
    Then I should see "Mentors"