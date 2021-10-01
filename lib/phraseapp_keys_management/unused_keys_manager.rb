# This module implements 2 steps:
# 1. Removes unused keys from PhraseApp
# 2. Reconstructs locale files after removing the keys deleted in step 1

module PhraseappKeysManagement
  class UnusedKeysManager
    attr_accessor :unused_key_occurrence_map, :key_errors_map, :deletion_details

    module PROJECT_ID
      CONTENT_DEVELOP = ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
      PRODUCTION = ENV['PHRASEAPP_PROJECT_ID_PRODUCTION']
    end
    USER_AUTH_TOKEN = ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']

    PROJECT_ID_NAME_MAPPING = {
      PROJECT_ID::CONTENT_DEVELOP => "content develop",
      PROJECT_ID::PRODUCTION => "production"
    }

    def initialize(key_occurrence_map)
      self.key_errors_map = {}
      self.deletion_details = { PROJECT_ID_NAME_MAPPING[PROJECT_ID::CONTENT_DEVELOP] => 0, PROJECT_ID_NAME_MAPPING[PROJECT_ID::PRODUCTION] => 0 }
      self.unused_key_occurrence_map = key_occurrence_map.select { |_, v| v[1] == false }
    end

    def handle_unused_keys
      delete_from_phraseapp
      reconstruct_locale_files
      log_errors
    end

    private

    def delete_from_phraseapp
      self.unused_key_occurrence_map.keys.each_with_index do |key, i|
        puts "Deleting key #{i+1} : #{key}\n\n"
        delete_key(key, PROJECT_ID::CONTENT_DEVELOP)
        delete_key(key, PROJECT_ID::PRODUCTION)
      end
    end

    def delete_key(key, project_id)
      begin
        key_id = get_key_id(key, project_id)
        project_name = PROJECT_ID_NAME_MAPPING[project_id]
        command = "curl 'https://api.phraseapp.com/api/v2/projects/#{project_id}/keys' -d '{\"q\":\"ids:#{key_id}\"}' -u #{USER_AUTH_TOKEN}: -X DELETE -H 'Content-Type: application/json'"
        response = JSON.parse(Globalization::PhraseappUtils.send(:system_call, command))
        self.deletion_details[project_name] += response["records_affected"].to_i
        handle_error_in_deletion(key, response["message"]) if(response["records_affected"] != 1)
      rescue => e
        puts "Failed to delete key : #{key} from #{project_name}"
        handle_error_in_deletion(key, e.message)
      end
    end

    def get_key_id(key, project_id)
      command = "curl -u #{USER_AUTH_TOKEN}: 'https://api.phraseapp.com/api/v2/projects/#{project_id}/keys?q=#{key}' -H 'Content-Type: application/json'"
      response = JSON.parse(Globalization::PhraseappUtils.send(:system_call, command))
      response.each do |key_details|
        return key_details["id"] if key_details["name"] == key
      end
      raise "Key not found in #{PROJECT_ID_NAME_MAPPING[project_id]}"
    end

    def handle_error_in_deletion(key, message)
      self.key_errors_map[key] ||= []
      self.key_errors_map[key] << message
    end

    def reconstruct_locale_files
      self.unused_key_occurrence_map.select!{ |_, v| v[0].present? }
      file_path_to_deleted_keys_map = get_file_path_to_deleted_keys_map
      file_path_to_deleted_keys_map.each do |file_path, deleted_keys|
        keys_map = YAML.load(File.open(file_path, "r"))
        deleted_keys.each do |deleted_key|
          hash_traversal_path = deleted_key.split(".")
          leaf_to_delete = hash_traversal_path.pop
          remove_nested_key_from_hash(keys_map, hash_traversal_path, leaf_to_delete)
        end
        if keys_map.present?
          File.open(file_path, "w") { |file| file.write keys_map.to_yaml(line_width: -1).gsub(/^---\n/, "") }
        else
          FileUtils.rm file_path
        end
      end
    end

    def get_file_path_to_deleted_keys_map
      file_path_to_deleted_keys_map = {}
      file_path_to_unused_key_details_map = self.unused_key_occurrence_map.group_by { |_, details| details[0] }

      file_path_to_unused_key_details_map.each do |file_path, unused_key_details|
        file_path_to_deleted_keys_map[file_path] = unused_key_details.map{ |detail| "en.#{detail.first}" } - self.key_errors_map.keys
      end
      file_path_to_deleted_keys_map
    end

    def remove_nested_key_from_hash(keys_map, hash_traversal_path, leaf_to_delete)
      return keys_map.except!(leaf_to_delete) if hash_traversal_path.empty?

      inner_hash_key = hash_traversal_path.shift
      remove_nested_key_from_hash(keys_map[inner_hash_key], hash_traversal_path, leaf_to_delete)
      keys_map.except!(inner_hash_key) if keys_map[inner_hash_key].blank?
    end

    def log_errors
      return if self.key_errors_map.blank?

      error_file_path = "/tmp/unused_keys_manager_error_log_#{Time.now.to_i}.csv"
      CSV.open(error_file_path, "w+") do |csv|
        self.key_errors_map.each_pair { |key, error_message| csv << [key, error_message] }
      end
      puts "Errors occurred while deleting some keys. Find details at: #{error_file_path}".red
    end
  end
end