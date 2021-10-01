Given %r{^I requested connections list as "(xml|json)" with "(valid|invalid)" key$} do |format, key_valid|
  step %{I requested "api/v2/connections.#{format}" with "#{key_valid}" using "GET"}
end

Given %r{^I requested connection as "(xml|json)" with "(valid|invalid)" key$} do |format, key_valid|
  step %{I requested "api/v2/connections/1.#{format}" with "#{key_valid}" using "GET"}
end

Given %r{^I requested connection creation as "(xml|json)" with "(valid|invalid)" key$} do |format, key_valid|
  step %{I requested "api/v2/connections.#{format}" with "#{key_valid}" using "POST" with "mentor_email=userrobert@example.com&mentee_email=mkr@example.com"}
end

Given %r{^I requested connection update as "(xml|json)" with "(valid|invalid)" key$} do |format, key_valid|
  step %{I requested "api/v2/connections/1.#{format}" with "#{key_valid}" using "PUT" with "name=New group name"}
end

Given %r{^I requested connection deletion as "(xml|json)" with "(valid|invalid)" key$} do |format, key_valid|
  step %{I requested "api/v2/connections/1.#{format}" with "#{key_valid}" using "DELETE"}
end
