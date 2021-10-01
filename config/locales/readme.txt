== Globalization Guideliness

Prerequisites: 
==============
  Rails Internalization API(http://guides.rubyonrails.org/i18n.html)
  Read through our config/locales folder.

API
==============
  Instead of t('welcome_message') (or any other ways of translating) always use 'welcome_message'.translate format, ie, “key_string”.translate
  We will use DateTime.localize(time_obj) for date/time format localization.


Keys:
=====
  i.  Keys should be in lowercase if possible. Only if there is a chance that we are going to have same string
      in diferent cases - then we can use Capitals for the key
  ii. We should not give keyword (like 'other') as key. For eg, 'other' is used in pluralization.
      PS: 'zero', 'one' , 'two', 'few', 'many', 'other' are keywords used for pluralization.
  
  Avoid this: (if possible)
  -----------
  en:
    Login_Page: Login Page

  Correct way:
  -----------
  en:
    login_page: Login Page


Date Format:
==============
  To convert this: Time.now.strftime("%A, %B %d, %Y, %I:%M %P")

  datetime_formats.en.yml
  --------------------
  en:
    time:
      formats:
        full_display: "%A, %B %d, %Y, %I:%M %P"

  Usage:
  --------------------
  DateTime.localize(Time.now, format: :full_display)

Javascript Date Format:
=======================
  To pass the format string in JS do the following:

  datetime_formats.en.yml
  -----------------------
  en:
    time:
      formats:
        range: "%m/%d"
        range_js: "mm/dd"
  
  Where the 'range_js' is passed to javascript function for formatting.

Flash Messages:
==============
  flash_message.en.yml
  --------------------
  en:
    flash_message:
      article:
        succeeded: Article created successfully

  Usage
  --------------------
  ‘flash_message.article.succeeded’.translate

Custom Terminologies:
==============
  custom_terminology.en.yml
  --------------------
  en:
    custom_terminology:
      mentor: Mentor
      a_mentor: a mentor
      A_mentor: A mentor
  The helpers _mentor, _a_mentor, _A_mentor will make use of these keys for default values.


Forms:
==============
  activerecord.en.yml
  --------------------
  en:
    activerecord:
      attributes:
        user:
          address: Residential Address
          country: Country Name

  feature_terms.en.yml
  ---------------------
  en:
    feature:
      t_&_c:
        label:
          terms: Terms & Conditions
  Usage
  --------------------
    <%= f.label :name %> # Name
    <%= f.label :address %> # Residential Address
    <%= label_tag :country, User.human_attribute_name(:country) %>
    <%= label_tag :terms, "feature.t_&_c.label.terms".translate %>

Form Error Messages
==============
  Error messages are already rails aware. Please read Rails Internalization API

Error Messages in js, etc.
==========================
  Put them in activerecord.en.yml under custom_errors and follow the nesting there, i.e.,
  custom_errors:
    model_name:
      attribute_name:
        error_name: Attribute has this error

Pluralization
==============

  en.yml
  --------------------
  en:
    inbox:
      one: '1 message'
      other: '%{count} messages'

  Usage
  --------------------
  "inbox".translate(count: 2) # => '2 messages'
  "inbox".translate(count: 1) # => '1 message'

pluralize_only_text(count, singular, plural)
===================

  pluralize_only_text(1, _mentor, _montors) => _mentor
  pluralize_only_text(6, _mentor, _montors) => _mentors
  
Note: Use this function only for custom terminology, otherwise follow the same approach as pluralize

Categorization:
==============
  Split en.yml files to separate files keeping balance between the number of files & the number of keys within the files.
  Examples:
  flash_messages.yml
  active_record.yml
  feature_article.yml
  feature_milestone.yml


Testing:
==============
  Avoid this:  assert_equal 'flash_message.article.succeeded', flash[:notice]
  Correct way: assert_equal 'Article created successfully'   , flash[:notice]


Javascript Strings:
==============
  * Always use escape_javascript() or j() while using strings in javascript.
  * Keep in mind that js files are precompiled once and cannot behave differently for different locales.
  * In case if there are a lot of strings for translation in js file, you have to:
    1. Create partial in views/layouts/translations (you can find and example in here)
    2. Include that partial to views/layouts/translations/_js_translations.html.erb

  For app/views/goals/new.html.erb
  --------------------------------
  Avoid this:  button_object.value = '<%= "display_string.Submit".translate %>'
  Correct way: button_object.value = '<%= j("display_string.Submit".translate) %>'

  For app/assets/javascripts/goals.js
  -----------------------------------
  Avoid this:  function displayMessage(){alert('Welcome')}
  Avoid this:  function displayMessage(){alert('<%= "feature.message".translate %>')}

  Correct way: function displayMessage(message){alert(message)} 
               and pass the message in the view"
               :onclick => "displayMessage('j(#{'feature.message'.transalte})')"

Rails Constants:
==============
  Sometimes we define constants for re-usability. Example: User::WELCOME_MESSAGE = 'Welcome'
  Keep in mind that constants are loaded once and cannot behave differently for different locales.
  
  Avoid this: User::WELCOME_MESSAGE = 'user.welcome'.translate
  
  To translate this we have two options:
  1: Create a function
  --------------------
  def User.welcome_message
    'user.welcome'.translate 
  end

  2: Directly use the KEY
  --------------------
  'user.welcome'.translate 


HTML in keys:
=============
  Avoid this: (because translaters should not deal with html)
  -----------
  en:
    login_page:
      header: <b>Login</b>

  Correct way:
  -----------
  en:
    login_page:
      header: Login

  Usage: <b><%= 'login_page.header'.translate %></b>


Unicode Characters in yml files:
================================
  Avoid this:  see_more_raquo: see more »
  Correct way: see_more_raquo_html: see more &raquo;

Using locale values in logic
============================
  Avoid this:  $('#select_box').val() == 'Select...'        # The value 'Select...' is customizable.
  Correct way: $('#select_box').val() == defaultPromptText  # Pass the defaultPromptText from the rails view.

How to add globalization for a new language:
============================
1. Add that locale in the admin locale management
2. Buy translations for that language from Phrase App
3. Translate the images for that locale in 'app/assets/images/translations/'

DEV PROCESS:
============
The phraseapp login id for current project is 'apollodev@chronus.com'
Right now, we have only one project and all the instructions below should be followed for development environment and the changes made there will be taken for staging/production. The instructions will be changed once we add autosync logic.

1. Dev only needs to add keys for English nested under 'en' in config/locales/folder.
2. Editing: Should not edit existing keys like in the case of spell errors, etc. as phraseapp would not detect the change in existing keys from codebase.
   i) If one needs to change the value of a key, one should ADD A NEW key, maybe with v1, v2 etc suffix and use them. You need NOT edit/delete the existing keys.
   ii) It is not recommended, but if one needs to change just the key and not value, one should do it at all the places in codebase and all the projects in phraseapp.

3. Should not delete existing keys. If its really needed, delete from the codebase and for all the projects in Phraseapp.

HOW TO PLACE ORDER FOR NEW KEY TRANSLATIONS TO PHRASEAPP:
=========================================================
There are few steps.
1. Push the new keys to phraseapp(https://phraseapp.com/docs/installation/pushing-translations)
2. Order the new translation in phraseapp(https://phraseapp.com/docs/order_translations/how-to-order-translations)

1. To push new keys. Be in the latest develop branch, the run the follwing from terminal
  phrase push -R config/locales/ --tags=%{tag_name}

2. To order in phraseapp.
  Log in to phraseapp(Email: apollodev@chronus.com)
  Click on "Order Translations"
  Select source locale (Should be 'en')
  Select target locale (Should be 'fr-CA', for canadian-french)
  Select the tag you assigned while giving the order
  Select the quality (Mostly it should be Standard)
  Specify message/style guide as translation guidelines if required
  Complete the order


HOW TO GET NEW TRANSLATED KEYS FROM PHRASEAPP:
==============================================
Right now, we have only one project and all the instructions below should be followed for development environment and the changes made there will be taken for staging/production. The instructions will be changed once we add autosync logic.

We need to pull the latest keys from phrase app in development environment and merge to our codebase.
For eg, for canadian french, the steps to be followed are:
1. phrase pull "fr-CA" --target="config/locales/"
2. Check the diff for keys added for french translations and commit to codebase.

EMAILS:
=======
For new emails:
--------------
  Say you want to add a new email 'admin_test_notification':
  1. Make a translaion file in the config/locales/mails/ folder and name it as 'admin_test_notification.en.yml'. The example file format would be:

      ###### Example Translation File ###########
      en:
        email_translations:
          forgot_password:
            title: "Request to Reset Password"
            description: "Test Description"
            subject: "Test Subject"
            content_html: "<b>Dear User</b>, smaple content."
            tags:
              url_test:
                description: Url to the tests
      ############################################

  2. The view file for the email, i.e., 'app/mailers/views/admin_test_notification.html.erb', should just contain the key to the html content for teh email, i.e.,

      ###### Example View File ###########
        <%= "email_translations.admin_test_notification.content_html".translate %>
      ############################################

  3. For the mail ruby file, i.e., 'app/mailers/mails/admin_test_notification.rb', the subject, description, title amd tags for the mail would be coming from this files. All these needs to be translated and put in the corresponding translation file. These translations must be put in procs. The example will make it clear: 

      ###### Example Mail File ###########
      class AdminTestNotification < ChronusActionMailer::Base
        @mailer_attributes = {
          ...
          :title        => Proc.new{"email_translations.admin_test_notification.title".translate},
          :description  => Proc.new{"email_translations.admin_test_notification.description".translate},
          :subject      => Proc.new{"email_translations.admin_test_notification.subject".translate},
          ...
        }
        ..

          tag :url_test, :description => Proc.new{'email_translations.admin_test_notification.tags.url_test.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
            test_url
          end
        ..
      ############################################

To edit existing emails:
------------------------
  1. To edit the content of the email, say, admin_test_notification.
    i) Go to 'config/mails/admin_test_notification.en.yml'
    ii) Add a new key, content_v1_html(or v2 if v1 is already used and so on), if the last key was content_html and put the new email content there. Also change the email view file from where the key is being called to call the new key. Don't edit/delete the existing keys.
  2. Similarly, to edit the tag description/examples, add new keys with v1, v2 etc suffix and put the updated values there. Also change the mailer file from where the key is being called to call the new key. Don't edit/delete the existing keys.
