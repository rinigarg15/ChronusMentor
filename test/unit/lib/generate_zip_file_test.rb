require_relative './../../test_helper.rb'

class GenerateZipFileTest < ActiveSupport::TestCase
	def test_generate_zip_file
		data = 'This is test data'
		file_name = "sample.csv"
    Zip::DOSTime.instance_eval do
		  def now ; Zip::DOSTime.new(Time.now.to_s) ; end
		end
		report_data = GenerateZipFile.generate_zip_file(data, file_name)
		assert_not_equal data, report_data
	end
end