Then /^the pdf file should have been downloaded with name "([^\"]*)"$/ do |name|
  if ENV['TDDIUM']
    file = Dir[DOWNLOAD_PATH+"/*"].last
  else
    file = Dir[DOWNLOAD_PATH.join('*')].last
  end
  assert_match(/#{name}/, file)
end