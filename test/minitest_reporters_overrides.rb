Minitest::Reporters::JUnitReporter.class_eval do
  private

  def write_xml_file_for(suite, tests)
    suite_result = analyze_suite(tests)

    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct!

    xml.testsuite(name: suite, skipped: suite_result[:skip_count], failures: suite_result[:fail_count],
                  errors: suite_result[:error_count], tests: suite_result[:test_count],
                  assertions: suite_result[:assertion_count], time: suite_result[:time]) do
      tests.each do |test|
        xml.testcase(name: test.name, file: get_source_location(suite), classname: suite, assertions: test.assertions,
                     time: test.time) do
          xml << xml_message_for(test) unless test.passed?
        end
      end
    end
    File.open(filename_for(suite), "w") { |file| file << xml.target! }
  end

  def get_source_location(suite)
    guessed_file_path = suite.name.underscore
    all_test_file_paths = Dir.glob(["test/functional/**/*_test.rb", "test/unit/**/*_test.rb", "vendor/engines/*/test/**/*_test.rb"])
    matched_file_paths = all_test_file_paths.select { |file_path| file_path.match(guessed_file_path).present? }
    return matched_file_paths[0] if matched_file_paths.size == 1

    guessed_file_path = nil
    suite.methods_matching(/^test_/).find do |method|
      guessed_file_path = suite.instance_method(method).source_location.first
      matched_file_paths.find { |file_path| file_path.match(guessed_file_path).present? }
    end
    guessed_file_path.to_s.gsub("#{Rails.root}/", "")
  end
end