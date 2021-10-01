require_relative './../../../test_helper'

class CodebaseParserTest < ActiveSupport::TestCase

  def test_initialize_codebase_parser
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:compute_keys_missing_in_codebase).once
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:skip_keys).once
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new
    assert_equal 0, codebase_parser.keys_found
    assert_equal [], codebase_parser.quote_array
    assert_equal ({}), codebase_parser.options
  end

  def test_initialize_codebase_parser_with_options
    options = { skip_keys_missing_from_codebase: true }
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:compute_keys_missing_in_codebase).never
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:skip_keys).once
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(options)
    assert_equal 0, codebase_parser.keys_found
    assert_equal [], codebase_parser.quote_array
    assert_equal options, codebase_parser.options
  end

  def test_get_unused_keys
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:compute_keys_missing_in_codebase).twice
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:skip_keys).twice
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:compute_direct_matches).twice
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:compute_regex_matches).twice
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:build_array_to_search).twice
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:search_logs).once
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new
    assert_equal codebase_parser.key_occurrence_map.keys, codebase_parser.get_unused_keys

    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(skip_log_search: true)
    codebase_parser.key_occurrence_map.each{ |_, value| value[1] = true }
    assert_equal [], codebase_parser.get_unused_keys
  end

  def test_skip_keys
    keys_in_skip_list = ["activerecord.test.key", "verify_organization_page.label.install_android_app", "date.test.key"]
    keys_not_in_skip_list = ["feature.test.key", "feature.test.key_2"]
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(skip_keys_missing_from_codebase: true)
    codebase_parser.key_occurrence_map = {}
    (keys_in_skip_list + keys_not_in_skip_list).each do |key|
        codebase_parser.key_occurrence_map[key] = ["", false]
    end
    codebase_parser.send :skip_keys
    keys_in_skip_list.each do |key|
      assert_equal ["", true, PhraseappKeysManagement::CodebaseParser::MESSAGE::SKIP], codebase_parser.key_occurrence_map[key]
    end
    keys_not_in_skip_list.each do |key|
      assert_equal ["", false], codebase_parser.key_occurrence_map[key]
    end
  end

  def test_compute_occurrences
    direct_match_keys = ["feature.test.key", "feature.test_email.key_1"]
    regex_match_keys = ["feature.test.key_1", "feature.test.email.key"]
    keys_with_no_match = ["feature.test_1.key.test_key", "feature.test_email.key"]
    matched_regex = { "feature.test.key_1" => /feature\.test\.key_.*/, "feature.test.email.key" => /feature\.test\..*/ }

    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(skip_keys_missing_from_codebase: true)
    codebase_parser.quote_array = ["\"feature.test.key\"", "feature.test_1.key.test_key", "'feature.test.key_\#{key_numer}'", "\"feature.test.\#{key_value}\"", "'feature.test_email.key_1'"]
    codebase_parser.key_occurrence_map = {}
    (direct_match_keys + regex_match_keys + keys_with_no_match).each do |key|
      codebase_parser.key_occurrence_map[key] = ["", false]
    end

    codebase_parser.send :compute_direct_matches
    direct_match_keys.each do |key|
      assert_equal ["", true, PhraseappKeysManagement::CodebaseParser::MESSAGE::DIRECT], codebase_parser.key_occurrence_map[key]
    end
    codebase_parser.send :compute_regex_matches
    regex_match_keys.each do |key|
      assert_equal ["", true, matched_regex[key]], codebase_parser.key_occurrence_map[key]
    end
    keys_with_no_match.each do |key|
      assert_equal ["", false], codebase_parser.key_occurrence_map[key]
    end
  end

  def test_construct_regex
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(skip_keys_missing_from_codebase: true)
    assert_equal Regexp.union(/feature\.test\..*/, /feature\.test\.key_.*/), codebase_parser.send(:construct_regex,  "\"feature.test.\#{key_value}\" and 'feature.test.key_\#{key_number}'", "feature")
  end

  def test_build_array_to_search
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:get_files_to_search).returns([File.join(Rails.root, 'test/fixtures/files/', "strings_for_codebase_parser.txt")])
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(skip_keys_missing_from_codebase: true)
    codebase_parser.send :build_array_to_search
    assert_equal_unordered ["main_translation_key = 'email_translations.\#{mail_klass.name.underscore}'", "main_translation_key = 'email_translations.\#{mail_klass.name.underscore}'.translate", "\"email_translations.announcement.email\""], codebase_parser.quote_array
  end

  def test_compute_keys_missing_in_codebase
    Globalization::PhraseappUtils.expects(:fetch_keys_from_local).returns(["feature.test.key"]).once
    Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).returns([{ "code" => "en" }]).once
    Globalization::PhraseappUtils.expects(:fetch_keys_from_phrase).returns(["feature.test.key", "feature.test.key_1"]).once
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new
    codebase_parser.send :export_result
    assert_equal ["", false, PhraseappKeysManagement::CodebaseParser::MESSAGE::MISSING], codebase_parser.key_occurrence_map["feature.test.key_1"]
  end

  def test_search_logs
    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(skip_keys_missing_from_codebase: true)
    Dir.expects(:[]).returns([File.join(Rails.root, 'test/fixtures/files/', "strings_for_codebase_parser.txt")]).once
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:handle_found_key).with("feature.email.header.emails_v1", PhraseappKeysManagement::CodebaseParser::MESSAGE::LOG).once
    codebase_parser.send :search_logs
  end
end