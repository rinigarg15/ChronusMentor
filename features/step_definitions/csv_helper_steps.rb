Then(/^the csv header must have the fields "(.*?)"$/) do |fields|
  if ENV['TDDIUM']
    file = Dir[DOWNLOAD_PATH+"/*"].last
  else
    file = Dir[DOWNLOAD_PATH.join('*')].last
  end
  verify_headers_for_csv(fields, file)
end

Then(/^the csv must only have "(.*?)" under "(.*?)"$/) do |value, column|
  if ENV['TDDIUM']
    file = Dir[DOWNLOAD_PATH+"/*"].last
  else
    file = Dir[DOWNLOAD_PATH.join('*')].last
  end
  verify_value_for_column(value, column, file)
end

Then(/^the csv must have one of the following values under "(.*?)"$/) do |column, values|
  if ENV['TDDIUM']
    file = Dir[DOWNLOAD_PATH+"/*"].last
  else
    file = Dir[DOWNLOAD_PATH.join('*')].last
  end
  values=values.raw.flatten
  verify_atleast_one_value_for_column(values, column, file)
end

Then(/^the csv must have the following row$/) do |values|
  if ENV['TDDIUM']
    file = Dir[DOWNLOAD_PATH+"/*"].last
  else
    file = Dir[DOWNLOAD_PATH.join('*')].last
  end
  table = values.rows_hash()
  verify_match_row(table, file)
end

Then(/^the csv must contain "(.*?)" under "(.*?)"$/) do |value, column|
  if ENV['TDDIUM']
    file = Dir[DOWNLOAD_PATH+"/*"].last
  else
    file = Dir[DOWNLOAD_PATH.join('*')].last
  end
  verify_column_contains(value, column, file)
end

Given /^I clear the downloads folder$/ do
  if ENV['TDDIUM']
    FileUtils.rm_f(Dir[DOWNLOAD_PATH + "/*"])
  else
    FileUtils.rm_f(Dir[DOWNLOAD_PATH.join('*')])
  end
end

Then /^the download folder must have "([^\"]*)"$/ do |file_name|
  if ENV['TDDIUM']
    file = DOWNLOAD_PATH + "/#{file_name}"
  else
    file = DOWNLOAD_PATH.join(file_name)
  end
  assert(File.file?(file.to_s), "No such file found")
end