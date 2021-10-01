require_relative './../../../test_helper'

class UnusedKeysManagerTest < ActiveSupport::TestCase

  def test_initialize_unused_key_manager
    unused_key_occurrence_map = { "feature.test.key" => ["", false] }
    key_occurrence_map = unused_key_occurrence_map.merge({ "feature.test.used_key" => ["", true] })
    unused_key_manager = PhraseappKeysManagement::UnusedKeysManager.new(key_occurrence_map)
    assert_equal unused_key_occurrence_map, unused_key_manager.unused_key_occurrence_map
    assert_equal ({}), unused_key_manager.key_errors_map
  end

  def test_handle_unused_keys
    PhraseappKeysManagement::UnusedKeysManager.any_instance.expects(:delete_key).with("feature.test.key", ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']).once
    PhraseappKeysManagement::UnusedKeysManager.any_instance.expects(:delete_key).with("feature.test.key", ENV['PHRASEAPP_PROJECT_ID_PRODUCTION']).once
    PhraseappKeysManagement::UnusedKeysManager.any_instance.expects(:reconstruct_locale_files).once
    PhraseappKeysManagement::UnusedKeysManager.any_instance.expects(:log_errors).once
    unused_key_manager = PhraseappKeysManagement::UnusedKeysManager.new({ "feature.test.key" => ["", false] }).handle_unused_keys
  end

  def test_delete_key
    project_id = ENV['PHRASEAPP_PROJECT_ID_PRODUCTION']
    user_auth_token = ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']
    key_id = 1
    command = "curl 'https://api.phraseapp.com/api/v2/projects/#{project_id}/keys' -d '{\"q\":\"ids:#{key_id}\"}' -u #{user_auth_token}: -X DELETE -H 'Content-Type: application/json'"
    Globalization::PhraseappUtils.expects(:system_call).with(command).returns("{\"records_affected\":2}").once
    PhraseappKeysManagement::UnusedKeysManager.any_instance.expects(:get_key_id).with("feature.test.key", project_id).returns(key_id).once
    PhraseappKeysManagement::UnusedKeysManager.any_instance.expects(:handle_error_in_deletion).with("feature.test.key", nil).once
    unused_key_manager = PhraseappKeysManagement::UnusedKeysManager.new({})
    unused_key_manager.send :delete_key, "feature.test.key", project_id
    unused_key_manager.send :log_errors
    assert_equal 2, unused_key_manager.deletion_details["production"]
  end

  def test_get_key_id
    user_auth_token = ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']
    project_id = ENV['PHRASEAPP_PROJECT_ID_PRODUCTION']
    key = "feature.test.key"
    command = "curl -u #{user_auth_token}: 'https://api.phraseapp.com/api/v2/projects/#{project_id}/keys?q=#{key}' -H 'Content-Type: application/json'"
    Globalization::PhraseappUtils.expects(:system_call).with(command).returns("[{\"name\":\"#{key}\",\"id\":123},{\"name\":\"feature.test.KEY\",\"id\":14}]").once
    unused_key_manager = PhraseappKeysManagement::UnusedKeysManager.new({})
    assert_equal 123, unused_key_manager.send(:get_key_id, key, project_id)
  end

  def test_reconstruct_locale_files
    file_path = File.join(Rails.root, 'test/fixtures/files/', "test_keys_to_delete")
    original_content = YAML.load(File.open(file_path)).to_yaml
    PhraseappKeysManagement::UnusedKeysManager.any_instance.expects(:get_file_path_to_deleted_keys_map).returns({file_path => ["feature.test.key", "feature.test_keys.b"] }).once
    unused_key_manager = PhraseappKeysManagement::UnusedKeysManager.new({ "feature.test.key" => [file_path, false], "feature.test_keys.b" => [file_path, false] })
    unused_key_manager.send(:reconstruct_locale_files)
    assert_equal ({ "feature" => { "test" => { "key_1" => "Testing key" } } }), YAML.load(File.open(file_path))
    File.open(file_path, 'w'){ |f| f << original_content }
  end

  def test_get_file_path_to_deleted_keys_map
    key_occurrence_map = { "feature.test.key" => ["file_path_1", false], "feature.test.key1" => ["file_path_1", false], "feature.test.key2" => ["file_path_2", false], "feature.test.key4" => ["file_path_2", false], "feature.test.key5" => ["file_path_1", false] }
    unused_key_manager = PhraseappKeysManagement::UnusedKeysManager.new(key_occurrence_map)
    assert_equal ({ "file_path_1" => ["en.feature.test.key", "en.feature.test.key1", "en.feature.test.key5"], "file_path_2" => ["en.feature.test.key2", "en.feature.test.key4"] }), unused_key_manager.send(:get_file_path_to_deleted_keys_map)
  end
end