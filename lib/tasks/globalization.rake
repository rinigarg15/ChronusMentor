#Globalization related rake tasks
namespace :globalization do

  desc "Place order for any missing keys on phraseapp. DEMO_USAGE: bundle exec rake globalization:place_order_in_phraseapp GITHUB_USER_EMAIL=<email>"
  task :place_order_in_phraseapp => :environment do
    github_email = ENV['GITHUB_USER_EMAIL'] || raise("Github user email not given.")
    Globalization::PhraseappUtils.place_order(github_email)
  end

  desc "Fetch Untranslated keys of local branch from phraseApp. DEMO_USAGE: bundle exec rake globalization:fetch_untranslated_keys_in_local"
  task :fetch_untranslated_keys_in_local => :environment do
    Globalization::PhraseappUtils.fetch_untranslated_keys
  end

  desc "Fetch and mail keys which are present in phraseapp but are not used anymore. DEMO_USAGE: bundle exec rake globalization:notify_unused_keys"
  task notify_unused_keys: :environment do
    Globalization::PhraseappUtils.notify_unused_keys
  end

  desc "Pull latest translations from the phrase project, sync them with prod and upload to s3. DEMO_USAGE: bundle exec rake globalization:bakup_latest_translations_for_deployment_and_sync_with_prod"
  task :bakup_latest_translations_for_deployment_and_sync_with_prod => :environment do
    Globalization::PhraseappUtils.sync_production_with_content_develop_and_push_to_s3
  end

  desc "Pull latest translations from the s3 bucket to the target path. DEMO_USAGE: bundle exec rake globalization:pull_translations_from_s3_bucket TARGET_PATH=<target_path>"
  task :pull_translations_from_s3_bucket => :environment do
    target_path = ENV['TARGET_PATH']
    Globalization::PhraseappUtils.pull_translations_from_s3_bucket_to_local(target_path)
  end

  desc 'Remove unused keys from phraseapp and reconstruct locale files. DEMO_USAGE_1: bundle exec rake globalization:remove_unused_keys KEYS="feature.project_request.status.closed". DEMO_USAGE_2: bundle exec rake globalization:remove_unused_keys FILE_PATH="tmp/keys_to_delete"'
  task remove_unused_keys: :environment do
    keys_to_delete = if ENV["FILE_PATH"].present?
      file_path = ENV["FILE_PATH"]
      File.readlines(file_path).map{ |key| key.strip.presence }.compact
    elsif ENV["KEYS"].present?
      ENV["KEYS"].split(",").map(&:strip)
    end
    raise "No keys to delete" if keys_to_delete.blank?
    raise "Delete 100 or lesser keys at a time" if keys_to_delete.size > 100

    codebase_parser = PhraseappKeysManagement::CodebaseParser.new(skip_log_search: true)
    keys_to_delete_hash = codebase_parser.key_occurrence_map.select{ |key| keys_to_delete.include?(key) }
    keys_to_delete -= keys_to_delete_hash.keys
    keys_to_delete.each{ |key| keys_to_delete_hash[key] = ["", false] }
    unused_keys_manager = PhraseappKeysManagement::UnusedKeysManager.new(keys_to_delete_hash)
    unused_keys_manager.handle_unused_keys

    is_success = true
    message = unused_keys_manager.deletion_details.map do |project_name, number_of_keys_deleted|
      is_success = false if number_of_keys_deleted != keys_to_delete_hash.count
      "#{number_of_keys_deleted} key(s) deleted from #{project_name}"
    end.join("\n")
    is_success ? Common::RakeModule::Utils.print_success_messages(message) : Common::RakeModule::Utils.print_error_messages(message)
  end

  desc "Add language"
  task add_language: :environment do
    language_name = ENV['LANGUAGE_NAME']
    unless Language.find_by(language_name: language_name).present?
      Language.create!(title: ENV['TITLE'], display_title: ENV['DISPLAY_TITLE'], language_name: language_name, enabled: ENV['ENABLED'].to_s.to_boolean)
      Common::RakeModule::Utils.print_success_messages("Language added successfully")
    else
      Common::RakeModule::Utils.print_error_messages("Language #{language_name} already exists")
    end
  end
end