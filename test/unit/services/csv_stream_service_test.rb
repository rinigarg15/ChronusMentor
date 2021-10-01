require_relative './../../test_helper.rb'

class CSVStreamServiceTest < ActiveSupport::TestCase
  def test_setup
    modify_const(:UTF8_BOM, "utf8-bom") do
      response = OpenStruct.new
      response.headers = { 'Content-Length' => 12_123 }
      controller_instance = ApplicationController.new
      controller_instance.response = response
      csv_service = CSVStreamService.new(response)    
      csv_service.setup!('test.csv', controller_instance) do |stream|
        stream << "hello"
      end

      assert_equal 'text/csv', response.headers['Content-Type']
      assert_equal 'attachment; filename="test.csv"', response.headers["Content-disposition"]
      assert_equal 'no', response.headers['X-Accel-Buffering']
      assert_equal Time.now.httpdate.to_s, response.headers['Last-Modified']
      assert_false response.headers.has_key?("Content-Length")
      assert_equal HttpConstants::SUCCESS, controller_instance.status
      assert_equal Enumerator, controller_instance.response_body.class
      assert_equal ["utf8-bom", "hello"], controller_instance.response_body.each.to_a
    end
  end
end