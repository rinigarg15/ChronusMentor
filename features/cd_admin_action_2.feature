@reindex @manage_career_development @javascript

Feature: Manage Career Development Portals
  In order to setup a Career Development Portal
  I want to create a portal as Super Admin and manage the portal as admin

  Background:
    Given the current program is "nch":""
    And I have logged in as "nch_admin@example.com"

Scenario: Super Admin should be able to customize term for Career Development for organizations where career development is enabled
    When I login as super user
    And I follow "Manage"
    Then I should see "Career Development Programs" in Career Development Programs Pane
    When I follow "Program Settings"
    Then I should see "Terminology"
    When I follow "Terminology"
    Then I should see "Term for Career development"
    When I fill the term for "Career development" with "Career Tracking"
    And I press "Save"
    Then I should see "Term for Career development"
    And I should see "The new terminology has been saved. Please also update the Program Overview pages to reflect the new terms."
    And the term for "Career development" should be "Career Tracking"
    When I follow "Manage"
    Then I should not see "Career Development Programs" in Career Tracking Programs Pane
    Then I should see "Career Tracking Programs" in Career Tracking Programs Pane
    When I follow "New Program" in Career Tracking Programs Pane
    Then I should see "Setup New Career Tracking Program"
    When I follow "Manage"
    And I follow "Program Settings"
    And I follow "Features"
    Then I should see "Career Tracking"
    When I logout
    And I follow "Programs"
    Then I should see "Career Tracking Program"

  Scenario: When admin customize the gloablization terms, career development related terms should be show appropriately
    Then I enable "language_settings" feature as a super user
    And I follow "Manage"
    Then I follow "Language Support"
    Then I should see "Nation Wide Children Hospital Org" within "#list_column"
    And I should see "Primary Career Portal" within "#list_column"
    And I should see "NCH Mentoring Program" within "#list_column"
    Then I click on text "Program Settings"
    Then I click on text "Terminology"
    And I should see "Career Development" within "#cjs_translation_table"
    Then I click on text "Primary Career Portal"
    Then I click on text "Program Settings"
    Then I click on text "Terminology"
    And I should not see "Matching Settings"
    And I should see "Employee" within "#cjs_translation_table"

    Then I disable the feature "career_development" as a super user
    And I follow "Manage"
    Then I follow "Language Support"
    Then I should see "Nation Wide Children Hospital Org" within "#list_column"
    And I should not see "Primary Career Portal" within "#list_column"
    And I should see "NCH Mentoring Program" within "#list_column"
    Then I click on text "Program Settings"
    Then I click on text "Terminology"
    And I should not see "Career Development" within "#cjs_translation_table"

  @javascript
  Scenario: When admin enable a new language for organization, the default content should be generated properly
    Given "Telugu" language is enabled for the organization "Nation Wide Children Hospital Org"
    Given "Hindi" language is not enabled for the organization "Nation Wide Children Hospital Org"
    Then I enable "language_settings" feature as a super user
    And I follow "Manage"
    Then I follow "Language Support"
    Then I should see "Telugu" within ".right_column"
    Then I click on text "Primary Career Portal"
    Then I should not see "Instructions" within "#list_column"
    Then I click on text "NCH Mentoring Program"
    Then I should see "Instructions" within "#list_column"
    Then I click on text "Instructions"
    And I should see "Mentor Request Instruction" within "#list_column"
    Then I hover over "my_programs_container"
    And I select "Primary Career Portal" from the program selector
    Then I follow "Manage"
    Then I follow "Program Settings"
    And I follow "Membership"
    And I maximize the window
    Then I change locale from "English" to "Telugu (Telugulu)"
    Then I should see "[[ Employees čáɳ šéťůƿ ťĥéíř čářééř ǧóáłš, čřéáťé ƿłáɳš, áɳď ťřáčǩ ťĥéíř ƿřóǧřéšš ťóŵářďš ářčĥíνíɳǧ ťĥé ǧóáłš íɳ ťĥé Career Development Program. ]]"
    Then I change locale from "Telugu (Telugulu)" to "English"
    Then I follow "Manage"
    Then I follow "Emails"
    When I select the "Enrollment and user management" category
    Then I change locale from "English" to "Telugu (Telugulu)"
    Then I should see "[[ Ϻéɱƀéřšĥíƿ řéƣůéšť šůƀɱíššíóɳ/ʲóíɳ ɳóťíƒíčáťíóɳ ťó ɱáɳáǧéř ]]"
    And I should see "[[ Ťĥíš šýšťéɱ-ǧéɳéřáťéď éɱáíł łéťš á ɱáɳáǧéř ǩɳóŵ ťĥáť á ďířéčť řéƿóřť ĥáš áƿƿłíéď ťó ʲóíɳ óř ĥáš ďířéčťłý ʲóíɳéď ťĥé program; íƒ ťĥé ɱáɳáǧéř ĥáš áɳý čóɳčéřɳš, ťĥéý čáɳ čóɳťáčť ťĥé administrator. ]]"
    Then I change locale from "Telugu (Telugulu)" to "English"

    Then I hover over "my_programs_container"
    And I select "Primary Career Portal" from the program selector
    And I follow "Advice"
    And I follow "Articles"
    Then I follow "Write New Article"
    Then I should see "Make a list of websites and books that you found useful in the past that could be helpful to the members of the program."
    Then I change locale from "English" to "Telugu (Telugulu)"
    Then I should see "[[ Ϻáǩé á łíšť óƒ ŵéƀšíťéš áɳď ƀóóǩš ťĥáť ýóů ƒóůɳď ůšéƒůł íɳ ťĥé ƿášť ťĥáť čóůłď ƀé ĥéłƿƒůł ťó ťĥé ɱéɱƀéřš óƒ ťĥé program. ]]"
    Then I change locale from "Telugu (Telugulu)" to "English"

    When I login as super user
    Given the current program is "nch":""
    Then I follow "Manage"
    And I follow "New Program" in Career Development Programs Pane
    Then I should see "Setup New Career Development Program"
    Then I change locale from "English" to "Telugu (Telugulu)"
    Then I should see "[[ Šéťůƿ Ѝéŵ Career Development Program ]]"
    Then I should see "[[ Ďéščříƿťíóɳ ]]"
    And I should see "[[ Ѝůɱƀéř óƒ łíčéɳšéš ]]"
    And I should see "[[ Ĥóŵ ɱáɳý ůšéřš ďó ýóů ťĥíɳǩ ŵóůłď ƀé ƿářť óƒ ťĥé program? ]]"
    And I should see "[[ Ůšé á šółůťíóɳ ƿáčǩ ]]"
    And I should see "[[ Í ŵíłł ďó íť áłł ƀý ɱýšéłƒ ]]"

    Then I change locale from "Telugu (Telugulu)" to "English"
    Then I hover over "my_programs_container"
    And I select "Primary Career Portal" from the program selector
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "General Settings"
    Then I change locale from "English" to "Telugu (Telugulu)"
    Then I should see "[[ Łóǧó ]]"
    And I should see "[[ Ɓáɳɳéř ]]"
    And I should see "[[ Ѝůɱƀéř óƒ Łíčéɳšéš ]]"

  Scenario: When super admin visit feature tab the career development feature should not disabled
    When I login as super user
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Features"
    Then I should see "Career Development"
    Then I hover over "my_programs_container"
    And I select "Primary Career Portal" from the program selector
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Features"
    Then I should see "Select the features that you want to enable for this program."
    Then I should not see "Career Development"
    Then I hover over "my_programs_container"
    And I select "NCH Mentoring Program" from the program selector
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Features"
    Then I should see "Select the features that you want to enable for this program."
    And I should not see "Career Development"

  Scenario: When super admin visit permission setting tabs the privacy settings should not be visible
    Then I logout
    When I have logged in as "nch_employee@example.com"
    Then I should not see "Employees" within "#side-menu"
    Then I logout 

    When I login as super user
    And I have logged in as "nch_admin@example.com"
    Then I hover over "my_programs_container"
    And I select "Primary Career Portal" from the program selector
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Permissions"
    And I should see "Privacy" within "#cjs_permission_privacy_settings"
    And I should see "Employees can view" within "#cjs_permission_privacy_settings"
    And I should see "Other employees"
    And I should not see "Irrespective of the above setting users will be able to view the profiles of other users whom they are already connected to."
    And I should not see "Allow users to message outside their connection"
    And I should not see "Administrator access to mentoring area"

    Then I check "Other employees"
    Then I press "Save"
    Then I logout

    When I have logged in as "nch_employee@example.com"
    Then I should see "Employees" within "#side-menu"
    Then I logout 

    
    When I login as super user
    And I have logged in as "nch_admin@example.com"
    Then I hover over "my_programs_container"
    And I select "Primary Career Portal" from the program selector
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Permissions"
    And I should see "Privacy" within "#cjs_permission_privacy_settings"
    #And I should see "Irrespective of the above setting users will be able to view the profiles of other users whom they are #already connected to."
    #And I should see "Allow users to message outside their connection"
    #And I should see "Administrator access to mentoring area"