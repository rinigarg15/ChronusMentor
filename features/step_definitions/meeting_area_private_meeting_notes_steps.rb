# encoding: utf-8
Then /^I type the note text "([^\"]*)"$/ do |text|
  step "I fill in \"private_meeting_note_text\" with \"#{text}\""
end

And /^I submit the new note entry$/ do
  within "#cjs_meeting_note_form" do
    step "I press \"new_note_submit\""
  end
end

When /^I edit the note entry "([^\"]*)"$/ do |entry_text|
  note = PrivateMeetingNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  within "#note_#{note.id}" do
    steps %{
      Then I click ".dropdown_options_#{note.id}"
      And I follow "Edit"
    }
  end
end

When /^I give edit note text for "([^\"]*)" as "([^\"]*)"$/ do |entry_text, new_text|
  note = PrivateMeetingNote.find_by(text: entry_text)
  step "I should see \"Edit Note\""
  within "#cjs_edit_meeting_note_form_#{note.id}" do
    step "I fill in \"meeting_private_meeting_note_text_#{note.id}\" with \"#{new_text}\""
  end
end

When /^I cancel the note edit for "([^\"]*)"$/ do |entry_text|
  note = PrivateMeetingNote.find_by(text: entry_text)
  within "#cjs_edit_meeting_note_form_#{note.id}" do
    step "I follow \"Cancel\""
  end
end

Then /^I submit the note edit for "([^\"]*)"$/ do |entry_text|
  note = PrivateMeetingNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  within "#cjs_edit_meeting_note_form_#{note.id}" do
    step "I press \"Update\""
  end
end

When /^I delete "([^\"]*)" note$/ do |entry_text|
  note = PrivateMeetingNote.find_by(text: entry_text)
  within "#note_#{note.id}" do
    steps %{
      Then I click ".dropdown_options_#{note.id}"
      And I follow "Delete"
    }
  end
end

When /^there is a private note entry "([^\"]*)" for "([^\"]*)" with attachment named "(.*)"$/ do |entry_text, email, attachment_name|
  program = Program.find_by(root: 'albers')
  member = User.find_by_email_program(email, program).member
  member_meeting = member.member_meetings.last
  assert_difference 'PrivateMeetingNote.count' do
    PrivateMeetingNote.create!(
      :text => entry_text,
      :member_meeting => member_meeting,
      :attachment => fixture_file_upload(File.join('files', attachment_name), 'text/text')
    )
  end
end

Then /^I click on attach a note file for "([^\"]*)"$/ do |entry_text|
  note = PrivateMeetingNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  step "I click \"#meeting_private_meeting_note_attachment#{note.id}\""
end

When /^I remove the private note attachment for "([^\"]*)" note$/ do |entry_text|
  note = PrivateMeetingNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]

  within "#cjs_edit_meeting_note_form_#{note.id}" do
    check "remove_attachment_#{note.id}"
  end
end

When /^I set the private note attachment for "([^\"]*)" to "(.*)"$/ do |entry_text, updated_attachment_name|
  note = PrivateMeetingNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  file_path = Rails.root.to_s + "/test/fixtures/files/#{updated_attachment_name}"
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(file_path)
  end  
  page.attach_file("meeting_private_meeting_note_attachment#{note.id}",file_path, visible: false)
end

When /^I set the attachment for new note entry to "([^\"]*)"$/ do |new_attachment_name|
  file_path = Rails.root.to_s + "/test/fixtures/files/#{new_attachment_name}"
  if ENV['BS_RUN'] == 'true'
   remote_file_detection(file_path)
  end 
  page.attach_file("private_meeting_note_attachment",file_path, visible: false)
end

When /^I set an invalid attachment to the new note entry$/ do
  file_path = Rails.root.to_s + "/test/fixtures/files/test_pic.png"
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(file_path)
  end 
  page.attach_file("private_meeting_note_attachment",file_path, visible: false)
end

When /^I set an invalid attachment while editing note "([^\"]*)"$/ do |entry_text|
  note = PrivateMeetingNote.find_by(text: entry_text)
  file_path = Rails.root.to_s + "/test/fixtures/files/test_pic.png"
  steps %{
    Then I check "Remove attachment"
  }
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(file_path)
  end  
  page.attach_file("meeting_private_meeting_note_attachment#{note.id}",file_path, visible: false)
end

And /^"([^\"]*)" has no private meeting notes$/ do |arg1|
  program = Program.find_by(root: 'albers')
  member = User.find_by_email_program(arg1, program).member
  member.member_meetings.each{|mem|
    mem.private_meeting_notes.destroy_all
  }
  assert member.private_meeting_notes.empty?
end

When /private note attachment limit one byte/ do
  PrivateMeetingNote.class_eval do
    validates_attachment_size(
      :attachment,
      :less_than => 4.kilobytes,
      :message => "must be less than 20 MB in size."
    )
  end
end