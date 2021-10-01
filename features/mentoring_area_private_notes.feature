Feature: Mentoring Connection Journal
In order to log their personal notes
Connected members should be able to add/remove/edit journal entries

Background: Enable admin audit logs
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout

@javascript  @cross-browser
Scenario: Mentee visits empty journal page and posts the first journal
  Given the current program is "primary":"albers" 
  When I have logged in as "mkr@example.com"
  When note attachment limit is one byte
  And I follow "name & madankumarrajan"
  And "mkr@example.com" has no private notes
  And I follow "Journal"
  Then I should see "You can use this section to add notes to your private journal, track your progress towards the goals, attach files, or record offline conversations with the mentor."
  And I should see "Add New Note"
  And I should not see "This page is private between you and the above people." 

  # First journal entry
  And I follow "Add New Note"
  When I type the journal text "I met my mentor yesterday. We discussed about the goals."
  And I submit the new entry
  And I should see "Add New Note"
  And I should see "I met my mentor yesterday. We discussed about the goals."
  And I should not see "You do not have any personal notes"

  # Second journal entry
  And I follow "Add New Note"
  When I type the journal text "This is my second note. It's awesome!"
  And I set the attachment for new entry to "handbook_test_1.txt"
  And I submit the new entry
  And I should see "Add New Note"
  And I should see "I met my mentor yesterday. We discussed about the goals."
  And I should see "handbook_test_1.txt"

  # Third journal entry. But, invalid attachment
  And I follow "Add New Note"
  When I type the journal text "This is my thrid note. Let me attach my hard drive backup!"
  And I set an invalid attachment to the new entry
  And I submit the new entry
  Then I should see "Attachment file size must be less than 20 MB in size" within ".toast-message"
  And I should not see "This is my thrid note. Let me attach my hard drive backup!"

  # Mentor should not see the mentee's journal entry in the mentoring connection
  When I logout
  And I have logged in as "robert@example.com"
  And I follow "name & madankumarrajan"
  And I follow "Journal"
  Then I should not see "This is my thrid note. Let me attach my hard drive backup"
  And I should see "Add New Note"

@javascript @cross-browser
Scenario: Mentor visits the journal page and posts the first journal
  Given the current program is "primary":"albers" 
  When I have logged in as "robert@example.com"
  And I follow "name & madankumarrajan"
  And "robert@example.com" has no private notes
  And I follow "Journal"
  And I follow "Add New Note"
  Then I should see "You can use this section to add notes to your private journal about the student(s), attach files, or record offline conversations with the student(s)."
  And I should see "Add New Note"

  When I type the journal text "The mentee asked me good questions."
  And I submit the new entry
  And I should see "Add New Note"
  And I should see "The mentee asked me good questions."
  And I should not see "You do not have any personal notes"
  And I should see "1 - 1 of 1"
  # Mentee logs in and sees only his journal.
  When I logout
  And I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"
  And I follow "Journal"
  And I should see "1 - 3 of 3"
  Then I should not see "You do not have any personal notes"
  Then I should see "I did the assignment yesterday; it was tough"

@javascript
Scenario: Mentee edits a journal entry
  Given the current program is "primary":"albers" 
  When I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"
  And I follow "Journal"
  Then I should see "I did the assignment yesterday; it was tough"
  And I should see "My second note."
  And I should see "My third note."

  # Click on edit and cancel it.
  When I edit the entry "I did the assignment yesterday; it was tough"
  And I give edit text for "I did the assignment yesterday; it was tough" as "Some random text"
  And I cancel the edit for "I did the assignment yesterday; it was tough"
  Then I should see "I did the assignment yesterday; it was tough"
  And I should not see "Some random text"

  # Try again
  When I edit the entry "I did the assignment yesterday; it was tough"
  Then I should see "I did the assignment yesterday; it was tough"
  And I give edit text for "I did the assignment yesterday; it was tough" as "Cricket"
  And I submit the edit for "I did the assignment yesterday; it was tough"
  Then I should see "Cricket"
  And I should not see "I did the assignment yesterday; it was tough"

  # After refreshing, should see the updated note, not the old one.
  Then I should not see "Private Journal" within "#SidebarRightContainer"

@javascript @cross-browser
Scenario: Mentor edits a journal entry and attachment
  Given the current program is "primary":"albers" 
  When I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"
  When there is a journal entry "Hello" for "mkr@example.com" with attachment named "handbook_test.txt"
  And I follow "Journal"
  Then I should see "Hello"

  # Update the attachment.
  When I edit the entry "Hello"
  And I give edit text for "Hello" as "Bowling"
  And I remove the attachment for "Hello"
  And I submit the edit for "Hello"
  
  Then I should see "Bowling"
  And I should not see "Hello"
  And I should not see "handbook_test.txt"

  # Add another attachment.
  When I edit the entry "Bowling"
  
  And I set the attachment for "Bowling" to "handbook_test.txt"
  And I submit the edit for "Bowling"
  Then I should see "Bowling"
  And I should see "handbook_test.txt"

  # Update the attachment.
  When I edit the entry "Bowling"
  When I remove the attachment for "Bowling"
  When I set the attachment for "Bowling" to "handbook_test_1.txt"
  And I submit the edit for "Bowling"
  Then I should see "Bowling"
  And I should see "handbook_test_1.txt"
  And I should not see "handbook_test.txt"

@javascript @not_run_on_tddium
Scenario: Error while updating entry
  When note attachment limit is one byte
  When there is a journal entry "Hello" for "mkr@example.com" with attachment named "handbook_test.txt"
  
  Given the current program is "primary":"albers" 
  When I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"
  And I follow "Journal"
  Then I should see "Hello"

  # Update attachment error.
  When I edit the entry "Hello"
  When I give edit text for "Hello" as "Bowling"
  And I set an invalid attachment while editing "Hello"
  And I submit the edit for "Hello"
  Then I should see "Attachment file size must be less than 20 MB in size"

  # Update text error.
  When I edit the entry "Hello"
  When I give edit text for "Hello" as ""
  And I submit the edit for "Hello"
  Then I should see "Note can't be blank"

  # Fix it now
  When I edit the entry "Hello"
  When I give edit text for "Hello" as "Proper text"
  And I submit the edit for "Hello"
  Then I should see "Proper text"
  And I should not see "Hello"

@javascript @cross-browser
Scenario: Mentor deletes a journal entry
  Given the current program is "primary":"albers" 
  When I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"
  And I follow "Journal"
  Then I should see "I did the assignment yesterday; it was tough"
  And I should see "My second note."
  And I should see "My third note."
  When I delete "My second note."
  And I confirm popup
  Then I should see the flash "The note has been deleted"
  And I should not see "My second note."

@javascript @cross-browser
Scenario: Read-only journal mode for closed connection
  Given the current program is "primary":"albers"
  And the private notes for "student_4@example.com" is "I did the assignment yesterday; it was tough"
  When I have logged in as "student_4@example.com"
  And I follow "Closed"
  And I follow "Visit Mentoring Connection"
  And I follow "Journal"
  Then I should see "I did the assignment yesterday; it was tough"

  # New entry form should not be there.
  But I should not see "Add New Note"

  # Editing should not be supported.
  And I should not see "Edit" within "#private_notes"
  And I should not see "Delete" within "#private_notes"

