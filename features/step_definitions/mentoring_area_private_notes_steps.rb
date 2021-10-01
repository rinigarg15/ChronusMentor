# encoding: utf-8
When /^I type the journal text "([^\"]*)"$/ do |text|
  step "I fill in \"note_text_box\" with \"#{text}\""
end

When /^I submit the new entry$/ do
  step "I press \"new_note_submit\""
end

When /^I edit the entry "([^\"]*)"$/ do |entry_text|
  note = Connection::PrivateNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  within "#note_#{note.id}" do
    steps %{
      Then I click ".dropdown_options_#{note.id}"
      And I follow "Edit"
    }
  end
end

When /^I give edit text for "([^\"]*)" as "([^\"]*)"$/ do |entry_text, new_text|
  note = Connection::PrivateNote.find_by(text: entry_text)
  step "I should see \"Edit Note\""
  within "#edit_note_#{note.id}" do
    step "I fill in \"connection_private_note_text_#{note.id}\" with \"#{new_text}\""
  end
end

When /^I cancel the edit for "([^\"]*)"$/ do |entry_text|
  note = Connection::PrivateNote.find_by(text: entry_text)
  within "#edit_note_#{note.id}" do
    step "I follow \"Cancel\""
  end
end

Then /^I submit the edit for "([^\"]*)"$/ do |entry_text|
  note = Connection::PrivateNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  within "#edit_note_#{note.id}" do
    step "I press \"Update\""
  end
end

When /^I delete "([^\"]*)"$/ do |entry_text|
  note = Connection::PrivateNote.find_by(text: entry_text)
  within "#note_#{note.id}" do
    steps %{
      Then I click ".dropdown_options_#{note.id}"
      And I follow "Delete"
    }
  end
end

When /^there is a journal entry "([^\"]*)" for "([^\"]*)" with attachment named "(.*)"$/ do |entry_text, email, attachment_name|
  program = Program.find_by(root: 'albers')
  user = User.find_by_email_program(email, program)
  g = user.groups.first
  membership = g.membership_of(user)

  assert_difference 'Connection::PrivateNote.count' do
    Connection::PrivateNote.create!(
      :text => entry_text,
      :connection_membership => membership,
      :attachment => fixture_file_upload(File.join('files', attachment_name), 'text/text')
    )
  end
end

Then /^I click on attach a note file for "([^\"]*)"$/ do |entry_text|
  note = Connection::PrivateNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  step "I click \"#connection_private_note_attachment#{note.id}\""
end

When /^I remove the attachment for "([^\"]*)"$/ do |entry_text|
  note = Connection::PrivateNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]

  within "#edit_note_#{note.id}" do
    check "remove_attachment_#{note.id}"
  end
end

When /^I set the attachment for "([^\"]*)" to "(.*)"$/ do |entry_text, updated_attachment_name|
  note = Connection::PrivateNote.all.select{|pn| pn.text.match(/#{entry_text}/)}[0]
  file_path = Rails.root.to_s + "/test/fixtures/files/#{updated_attachment_name}"
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(file_path)
  end  
  page.attach_file("connection_private_note_attachment#{note.id}",file_path, visible: false)
end

When /^I set an invalid attachment while editing "([^\"]*)"$/ do |entry_text|
  note = Connection::PrivateNote.find_by(text: entry_text)
  file_path = Rails.root.to_s + "/test/fixtures/files/test_pic.png"
  steps %{
    Then I check "Remove attachment"
    Then I follow "new_attachment_#{note.id}"
  }
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(file_path)
  end  
  page.attach_file("connection_private_note_attachment#{note.id}",file_path, visible: false)
end

When /^I set the attachment for new entry to "([^\"]*)"$/ do |new_attachment_name|
  file_path = Rails.root.to_s + "/test/fixtures/files/#{new_attachment_name}"
  if ENV['BS_RUN'] == 'true'
   remote_file_detection(file_path)
  end 
  page.attach_file("new_note_attachment",file_path, visible: false)
end

When /^I set an invalid attachment to the new entry$/ do
  file_path = Rails.root.to_s + "/test/fixtures/files/test_pic.png"
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(file_path)
  end 
  page.attach_file("new_note_attachment",file_path, visible: false)
end
Given /^the private notes for "([^\"]*)" is "([^\"]*)"$/ do |email, note|
  program = Program.find_by(root: 'albers')
  user = User.find_by_email_program(email, program)
  assert_difference('Connection::PrivateNote.count') do
    note = Connection::PrivateNote.new_for(user.groups.first, user, {:text => note})
    note.save!
  end
end


When /^"([^\"]*)" has only one closed connection$/ do |arg1|
  program = Program.find_by(root: 'albers')
  user = User.find_by_email_program(arg1, program)
  assert_equal 1, user.groups.length
  group = user.groups.first
  group.terminate!(program.admin_users.first, 'some reason')
end

When /^"([^\"]*)" has only one expired connection$/ do |arg1|
  program = Program.find_by(root: 'albers')
  user = User.find_by_email_program(arg1, program)
  assert_equal 1, user.groups.length
  g = user.groups.first
  Timecop.travel(2.days.ago)
  g.expiry_time = 1.day.from_now
  g.save!
  Timecop.return
end

When /^there are "(\d+)" journal entries for "([^\"]*)"$/ do |arg1, arg2|
  user = User.find_by_email_program(arg2, Program.find_by(root: 'albers'))
  g = user.groups.first
  membership = g.membership_of(user)

  arg1.to_i.times do |i|
    Connection::PrivateNote.create!(
      :text => "text_#{i}",
      :connection_membership => membership
    )
  end
end

When /^"([^\"]*)" has no private notes$/ do |arg1|
  program = Program.find_by(root: 'albers')
  user = User.find_by_email_program(arg1, program)
  user.connection_memberships.each{|conn|
      conn.private_notes.destroy_all
  }
  assert user.private_notes.empty?
end

When /note attachment limit is one byte/ do
  Connection::PrivateNote.class_eval do
    validates_attachment_size(
      :attachment,
      :less_than => 4.kilobytes,
      :message => "must be less than 20 MB in size."
    )
  end
end

When /^I visit the mentoring connection of "([^\"]*)"$/ do |email|
  program = Program.find_by(root: 'albers')
  user = User.find_by_email_program(email, program)
  visit group_path(user.groups.first, :root => "albers")
end

When /^I give confidentiality reason as "([^\"]*)"$/ do |reason|
  step "I fill in \"confidentiality_audit_log_reason\" with \"#{reason}\""
  step "I press \"Proceed »\""
end
