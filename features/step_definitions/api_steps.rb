class ApiTester
  cattr_accessor :host, :root
end

World(Rack::Test::Methods)

Given %r{the current program for api is "([^"]+)":"([^"]+)"$} do |program, root|
  ApiTester.host = "#{program}.#{DEFAULT_HOST_NAME}"
  ApiTester.root = "p/#{root}"
end

Given %r{^I requested "([^"]+)" with "([^"]+)" using "(GET|POST|PUT|DELETE)"(?: with "([^"]+)")?$} do |path, key, method, params|
  # find member and enable API for him
  m = Member.where(email: "ram@example.com").first
  m.enable_api!
  # params
  attributes = {
    api_key: "valid" == key ? m.api_key : "some-invalid-key"
  }
  unless params.blank?
    params.split("&").each do |pair|
      k, v = pair.split("=")
      attributes.merge!(k => v)
    end
  end
  request_params = {
    "REQUEST_METHOD" => method,
    "HTTP_HOST" => ApiTester.host,
    params: attributes,
  }
  request "/#{ApiTester.root}/#{path}", request_params
end

Then %r{^response should be "(success|unauthorized)"$} do |response|
  responses = {
    "success" => 200,
    "unauthorized" => 403,
  }
  assert_equal responses[response], last_response.status
end

Then %r{^I should receive "(xml|json)" response$} do |format|
  format_to_type = {
    "xml" => /application\/xml/,
    "json" => /application\/json/,
  }
  assert_match format_to_type[format], last_response.header["Content-Type"]
end

Then %r{^I should see xml-tag "([^"]+)"$} do |tag|
  xml_doc = Nokogiri::XML(last_response.body)
  elements = xml_doc.xpath(tag)
  assert elements.any?, "could not find #{tag} in xml response"
end

Then %r{^I should see xml-tags$} do |tags|
  tags.raw.each do |tag|
    step "I should see xml-tag \"#{tag[0]}\""
  end
end

Then %r{^I should receive json array$} do
  json_data = JSON.parse(last_response.body)
  assert_instance_of Array, json_data
end

Then %r{^I should receive json array containing object$} do
  json_data = JSON.parse(last_response.body)
  json_data.each do |obj|
    assert_instance_of Hash, obj
  end
end

Then %r{^I should receive json array containing object with$} do |keys|
  json_data = JSON.parse(last_response.body)
  keys.raw.each do |key|
    assert json_data.any? { |obj| obj.has_key?(key[0]) }, "noone of received json objects contains '#{key}'"
  end
end

Then %r{^I should receive json object$} do
  json_data = JSON.parse(last_response.body)
  assert_instance_of Hash, json_data
end

Then %r{^I should receive json object with$} do |fields|
  json_data = JSON.parse(last_response.body)
  fields.raw.each do |field|
    assert json_data.has_key?(field[0]), "expected json object to has a field #{field}"
  end
end

