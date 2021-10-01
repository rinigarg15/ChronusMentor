require 'rest_client'
require 'yaml'

class Globalization::PhraseappUtils
  include ChronusS3Utils

  BACKUP_LOCATION = "phraseapp_backup_files"
  DEPLOYMENT_FILES_LOCATION = "phraseapp_deployment_files"
  MAX_DAYS_TO_KEEP_BACKUP = 30
  LOCALE_PATHS = [
    "#{Rails.root}/config/locales/**/*.yml",
    "#{Rails.root}/vendor/engines/campaign_management/config/locales/**/*.yml"
  ]
  EXCLUDE_PATH_REGEX = 'phrase.*.yml'

  module NokogiriObj
    ERROR = -1
    WARNING = 0
    VALID = 1
  end

  # Places order in content develop phraseapp project for all the supported locales
  def self.place_order(user_email, options = {})
    content_develop_project_id = options[:content_develop_project_id] || ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
    user_auth_token = options[:user_auth_token] || ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']
    time = Time.now.strftime("%d_%m_%Y_%H_%M_%S")
    tag = "#{user_email.gsub(/[^a-zA-Z0-9\s\-:]/, '_')}_#{time}"
    all_en_yml_file = "#{Rails.root.to_s}/tmp/phrase.en.yml"

    locales = self.fetch_supported_locales_from_phrase(user_auth_token, content_develop_project_id)
    locale_ids = locales.collect{|hsh| hsh["id"]}
    english_locale_id = self.get_locale_id_for_english(locales)
    locale_ids = locale_ids - [english_locale_id]

    self.merge_locales_to_single_yaml(nil, all_en_yml_file)
    self.push_translation_file(all_en_yml_file, tag, english_locale_id, user_auth_token, content_develop_project_id)
    sleep_time = 15
    puts "--- After uploading the latest keys, phraseapp takes some time to create the keys. So added a delay here. Sleeping for #{sleep_time} seconds..."
    sleep(sleep_time) #the tag is created on phraseapp after a delay. In next line we are looking the tag info. so added a delay.
    tag_info = self.get_tag_info(user_auth_token, content_develop_project_id, tag)
    raise "Tag info not available" if tag_info.nil?

    if tag_info["keys_count"] > 0
      self.create_and_confirm_order(user_auth_token, content_develop_project_id, locale_ids, tag)
    else
      puts "--- looks like there are no new keys to place order for."
    end
  end

  # Merges all the locale files in the specified locale path into a single locale file in the output path.
  def self.merge_locales_to_single_yaml(locale_path = nil, output_path = nil, nested_keys = true, exclude_path = EXCLUDE_PATH_REGEX)
    keys_set = {}
    locale_path ||= LOCALE_PATHS
    output_path ||= "/tmp/phrase_new.yml"
    Dir.glob(locale_path).each do |file|
      unless exclude_path.present? && file.match(exclude_path)
        keys_set.deep_merge!(YAML.load(File.read(file)))
      end
    end
    unless nested_keys
      keys_set = recursive_hash_to_yaml_string("", keys_set, {}, "")
      keys_set = Hash[keys_set.sort]
    end
    File.open(output_path, "wb+") {|f| f.write keys_set.to_yaml}
  end

  # Pushed translation file to phraseapp with default locale - en
  def self.push_translation_file(file_path, tag, locale_id, user_auth_token, project_id)
    command ="curl 'https://api.phraseapp.com/api/v2/projects/#{project_id}/uploads' -u #{user_auth_token}: -X POST -F file=@#{file_path} -F locale_id=#{locale_id} -F tags=#{tag}"
    result = self.system_call(command)
  end

  # Fetches details about the tag - tag_name from the phraseapp project
  def self.get_tag_info(user_auth_token, project_id, tag)
    command = "curl 'https://api.phraseapp.com/api/v2/projects/#{project_id}/tags/#{tag}' -u #{user_auth_token}:"
    response = self.system_call(command)
    response = JSON.parse(response)
    if response["keys_count"].nil?
      return nil
    else
      return response
    end
  end

  # Fetches all supported locales from the phraseapp project
  def self.fetch_supported_locales_from_phrase(user_auth_token, project_id)
    command = "curl -sS 'https://api.phraseapp.com/api/v2/projects/#{project_id}/locales' -u #{user_auth_token}:"
    response = self.system_call(command)
    return JSON.parse(response)
  end

  # Creates and confirms phraseapp order as a user for the specified project with target locales and tags.
  def self.create_and_confirm_order(user_auth_token, project_id, target_locale_ids, tag, options = {})
    locales = self.fetch_supported_locales_from_phrase(user_auth_token, project_id)
    locale_ids = locales.collect{|hsh| hsh["id"]}
    english_locale_id = self.get_locale_id_for_english(locales)
    lsp = options[:lsp] || "gengo"
    source_locale_id = options[:source_locale_id] || english_locale_id
    translation_type = options[:translation_type] || "standard"
    styleguide_code = options[:styleguide_code] || ENV['PHRASEAPP_STYLEGUIDE_CODE']
    order_options = '{"lsp":"'+"#{lsp}"+'","source_locale_id":"'+"#{source_locale_id}"+'","translation_type":"'+"#{translation_type}"+'","tag":"'+"#{tag}"+'","styleguide_id":"'+"#{styleguide_code}"+'","target_locale_ids":'+"#{target_locale_ids}"+'}'
    command = "curl 'https://api.phraseapp.com/api/v2/projects/#{project_id}/orders' -u #{user_auth_token}: -X POST -d '#{order_options}' -H 'Content-Type: application/json'"
    response = self.system_call(command)
    response = JSON.parse(response)
    if response["errors"] || response["tag_name"] != tag
      raise "Unable to place order with phraseapp. Response received: #{response}"
    end

    order_code = response["id"]
    command = "curl https://api.phraseapp.com/api/v2/projects/#{project_id}/orders/#{order_code}/confirm -X PATCH -u #{user_auth_token}:"
    response = self.system_call(command)
    response = JSON.parse(response)
    if response["errors"] || response["state"] != "confirmed"
      raise "Unable to confirm order with phraseapp. Response received: #{response}"
    else
      puts "--- Order confirmed. Response: #{response}"
    end
    return order_code
  end

  # Fetches all untranslated keys in non-english locales from local with supported languages from phraseApp
  def self.untranslated_keys_in_local(user_auth_token=nil, content_develop_project_id=nil, local_path = nil)
    user_auth_token ||= ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']
    content_develop_project_id ||= ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
    local_path ||= LOCALE_PATHS
    all_keys_hash = {}
    untranslated_keys_hash = {}

    Dir.glob(local_path).each do |file|
      hash = YAML.load(File.read(file))
      all_keys_hash.deep_merge!(hash)
    end

    locales = self.fetch_supported_locales_from_phrase(user_auth_token, content_develop_project_id)
    locales = locales.collect{|hsh| hsh["code"]}
    english_keys_set = recursive_hash_to_yaml_string("", all_keys_hash["en"], {}).keys
    (locales - ["en"]).each do |locale|
      current_locale_key_hash = all_keys_hash[locale] || {}
      local_keys_set = recursive_hash_to_yaml_string("", current_locale_key_hash, {}).keys
      untranslated_keys_for_locale = english_keys_set - local_keys_set
      untranslated_keys_hash[locale] = untranslated_keys_for_locale if untranslated_keys_for_locale.present?
    end
    return untranslated_keys_hash
  end

  # Fetches all keys which do not have translations in phraseApp including english
  def self.fetch_untranslated_keys(user_auth_token=nil, project_id=nil, locale_path = nil, exclude_regex = nil)
    user_auth_token ||= ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']
    project_id ||= ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
    keys_from_local = self.fetch_keys_from_local(locale_path, exclude_regex)
    locales = self.fetch_supported_locales_from_phrase(user_auth_token, project_id)
    untranslated_hash = {}
    mismatch_count = 0
    locales.each do |locale|
      untranslated_hash[locale["code"]] = []
      keys_from_phrase = self.fetch_keys_from_phrase(user_auth_token, project_id, locale)
      untranslated_hash[locale["code"]] = keys_from_local-keys_from_phrase
      mismatch_count += untranslated_hash[locale["code"]].size
    end
    raise "#{untranslated_hash} translations are missing for the keys" unless mismatch_count == 0
    return untranslated_hash
  end

  # Gets the list of all keys from the locale path
  def self.fetch_keys_from_local(locale_path = nil, exclude_regex = nil)
    keys_set = []
    locale_path ||= LOCALE_PATHS
    exclude_regex ||= EXCLUDE_PATH_REGEX
    Dir.glob(locale_path).each do |file|
      unless file.match(exclude_regex)
        keys_set += self.yaml_to_keys(file).keys
      end
    end
    keys_set
  end

  # Gets the list of all keys from the phraseapp project
  def self.fetch_keys_from_phrase(user_auth_token, project_id, locale, target_path = "/tmp")
    new_keys_set = []
    locale_file = "#{target_path}/phrase.#{locale["id"]}.yml"

    self.delete_if_exist(locale_file)
    self.pull_locale_from_phrase(user_auth_token, project_id, locale["id"], target_path)

    if (File.exists?(locale_file))
      new_keys_set = self.yaml_to_keys(locale_file, locale["code"]).keys
    end
    new_keys_set
  end

  # Gets the list of all keys that are either updated/removed in the local into a csv in /tmp/diff.csv
  def self.unused_keys(local_path, phrase_path)
    local_keys_set = {}
    Dir.glob(local_path).each do |file|
      new_keys = self.yaml_to_keys(file)
      local_keys_set.merge!(new_keys)
    end

    phrase_keys_set = {}
    Dir.glob(phrase_path).each do |file|
      new_keys = self.yaml_to_keys(file)
      phrase_keys_set.merge!(new_keys)
    end

    removed_keys = []
    updated_keys = []
    csv_file_name = "/tmp/diff.csv"
    CSV.open(csv_file_name, 'wb') do |row|
      row << ["Key Value",  "In PhraseApp", "In Local"]
      phrase_keys_set.each do |key, value|
        if !local_keys_set[key].present?
          removed_keys << key
        elsif phrase_keys_set[key] != local_keys_set[key]
          updated_keys << key
          row << [key, phrase_keys_set[key], local_keys_set[key]]
        end
      end
    end
    [removed_keys, updated_keys]
  end

  # Sync production phraseapp project with the content develop phraseapp project
  def self.sync_production_with_content_develop_and_push_to_s3(options = {})
    source_project_id = options[:source_project_id] || ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
    target_project_id = options[:target_project_id] || ENV['PHRASEAPP_PROJECT_ID_PRODUCTION']
    user_auth_token = options[:user_auth_token] || ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']

    time_now = (Time.now.to_i / ((24*60*60)))
    target_path = File.join(Rails.root.to_s, "tmp", "latest_phraseapp", time_now.to_s)
    FileUtils.mkdir_p(target_path, mode: 0777)
    File.chmod(0777, target_path)

    begin
      source_locales = Globalization::PhraseappUtils.fetch_supported_locales_from_phrase(user_auth_token, source_project_id)
      source_locale_ids = source_locales.collect{|hsh| hsh["id"]}
      english_locale_id = Globalization::PhraseappUtils.get_locale_id_for_english(source_locales)
      supported_locale_ids = source_locale_ids - [english_locale_id]

      target_locales = Globalization::PhraseappUtils.fetch_supported_locales_from_phrase(user_auth_token, target_project_id)
      locale_mappings = Globalization::PhraseappUtils.get_locale_mappings(source_locales, target_locales)
      supported_locale_ids.each do |locale|
        Globalization::PhraseappUtils.pull_locale_from_phrase(user_auth_token, source_project_id, locale, target_path)
        Globalization::PhraseappUtils.push_locale_to_phrase(user_auth_token, target_project_id, locale_mappings[locale], locale, target_path)
      end
      S3Helper.delete_all(APP_CONFIG[:chronus_mentor_common_bucket], Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION)
      Dir.glob(File.join(target_path, "**", "*.yml")).each do |file|
        S3Helper.transfer(file, Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION, APP_CONFIG[:chronus_mentor_common_bucket])
      end
      FileUtils.rm_rf(target_path)
    rescue => e
      FileUtils.rm_rf(target_path)
      raise e
    end
  end

  # Pull list of all translations from the phraseapp project to local
  def self.pull_translations_from_phrase_to_local(path, exclude_en = true, options = {})
    project_id = options[:project_id] || ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
    user_auth_token = options[:user_auth_token] || ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']

    locales = self.fetch_supported_locales_from_phrase(user_auth_token, project_id)
    supported_locales = locales.collect{|hsh| hsh["id"]}
    english_locale_id = self.get_locale_id_for_english(locales)
    supported_locales = supported_locales - [english_locale_id] if exclude_en
    supported_locales.each do |locale|
      self.pull_locale_from_phrase(user_auth_token, project_id, locale, path)
    end
  end

  def self.get_keys_having_corrupted_translations(options = {})
    project_id = options[:project_id] || ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
    user_auth_token = options[:user_auth_token] || ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']
    target_path = "#{Rails.root}/tmp/phraseapp/#{rand(10000).to_s}"
    FileUtils.rm_r(target_path) if File.exist?(target_path)
    FileUtils.mkdir_p(target_path, mode: 0777)
    self.pull_translations_from_phrase_to_local(target_path, true, {user_auth_token: user_auth_token, project_id: project_id})
    locales = self.fetch_supported_locales_from_phrase(user_auth_token, project_id)
    locales = locales.select{|hsh| hsh["code"] != "en"}

    all_en_yml_file = "#{target_path}/phrase.en.yml"
    self.merge_locales_to_single_yaml(nil, all_en_yml_file)
    en_hash = self.yaml_to_keys(all_en_yml_file)
    problematic_interpolation_keys, problematic_html_keys, warning_html_keys = [], [], []
    locales.each do |locale|
      locale_hash = self.yaml_to_keys("#{target_path}/phrase.#{locale["id"]}.yml", locale["code"])
      locale_hash.each do |key, value|
        if en_hash[key].nil?
          next # problematic_interpolation_keys << {key: key, en: "translation not available", other: locale_hash[key], locale: locale}
        elsif en_hash[key].is_a?(Array) || locale_hash[key].is_a?(Array)
          problematic_interpolation_keys << {key: key, en: en_hash[key], other: locale_hash[key], locale: locale["code"]} if en_hash[key].class != locale_hash[key].class || en_hash[key].count != locale_hash[key].count
        else
          problematic_interpolation_keys << {key: key, en: en_hash[key], other: locale_hash[key], locale: locale["code"]} if !validate_interpolation_tags_for_key(en_hash[key], locale_hash[key])
          html_tags_valid = validate_html_tags_for_key(en_hash[key], locale_hash[key])
          problematic_html_keys << {key: key, en: en_hash[key], other: locale_hash[key], locale: locale["code"]} if html_tags_valid == NokogiriObj::ERROR
          warning_html_keys << {key: key, en: en_hash[key], other: locale_hash[key], locale: locale["code"]} if html_tags_valid == NokogiriObj::WARNING
        end
      end
    end
    FileUtils.rm_r(target_path)
    return {problematic_interpolation_keys: problematic_interpolation_keys, problematic_html_keys: problematic_html_keys, warning_html_keys: warning_html_keys}
  end

  # Pull list of all translations from the s3 chronus_mentor_common_bucket to local
  def self.pull_translations_from_s3_bucket_to_local(path)
    S3Helper.get_objects_with_prefix(APP_CONFIG[:chronus_mentor_common_bucket],Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION).each do |obj|
      if obj.key.starts_with?("#{Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION}/phrase.")
        file_name = File.basename(obj.key)
        File.open(File.join(path, file_name), "wb+") {|f| f.write obj.read}
      end
    end
  end

  def self.get_locale_id_for_english(locales)
    en_locale = locales.select{|hsh| hsh["code"] == "en"}.first
    return en_locale["id"]
  end

  def self.get_locale_mappings(source_locales, target_locales)
    locale_mappings = {}
    source_locales.each do |source_locale|
      target_locales.each do |target_locale|
        if source_locale["code"] == target_locale["code"]
          locale_mappings[source_locale["id"]] = target_locale["id"]
        end
      end
    end
    return locale_mappings
  end

  def self.notify_untranslated_strings
    untranslated_keys = untranslated_keys_in_local
    InternalMailer.notify_untranslated_strings(untranslated_keys).deliver_now if untranslated_keys.any?
  end

  def self.notify_unused_keys
    unused_keys = PhraseappKeysManagement::CodebaseParser.new(skip_log_search: true, skip_keys_missing_from_codebase: true).get_unused_keys
    InternalMailer.notify_unused_keys(unused_keys).deliver_now if unused_keys.present?
  end

  def self.notify_corrupted_translations
    problematic_keys = get_keys_having_corrupted_translations
    InternalMailer.notify_corrupted_translations(problematic_keys).deliver_now if problematic_keys[:problematic_interpolation_keys].count + problematic_keys[:problematic_html_keys].count + problematic_keys[:warning_html_keys].count > 0
  end

  def self.backup_translations(target_path, output_path, time_now)
    pull_translations_from_phrase_to_local(target_path, false, {project_id: APP_CONFIG[:phrase_backup_project_id]})
    merge_locales_to_single_yaml(File.join(target_path, "**", "*.yml"), output_path, true, nil)
    S3Helper.transfer(output_path, BACKUP_LOCATION, APP_CONFIG[:chronus_mentor_common_bucket], {url_expires: 2.minutes})
    S3Helper.get_objects_with_prefix(APP_CONFIG[:chronus_mentor_common_bucket], BACKUP_LOCATION).each do |obj|
      filename = Pathname.new(obj.key).basename.to_s
      basename = File.basename(filename, File.extname(filename))
      obj_age = time_now - basename.to_i
      if obj_age > MAX_DAYS_TO_KEEP_BACKUP
        obj.delete
      end
    end
  end

  private

  def self.yaml_to_keys(file_path, locale = "en")
    hash = YAML.load(File.read(file_path))
    recursive_hash_to_yaml_string("", hash, {}, locale)
  end

  def self.recursive_hash_to_yaml_string(prefix = "", hash = {}, keys_list = {}, locale = "en")
    hash.keys.each do |key|
      tprefix = [prefix, key].reject(&:empty?).join(".")
      value = hash[key]
      if value.is_a?(String) || value.is_a?(Array)
        if locale.present?
          keys_list[tprefix.gsub(/^#{locale}./, '')] = value
        else
          keys_list[tprefix] = value
        end
      elsif value.is_a?(Hash)
        recursive_hash_to_yaml_string(tprefix, value, keys_list, locale)
      end
    end
    keys_list
  end

  def self.delete_if_exist(locale_file)
    if (File.exists?(locale_file))
      self.system_call("rm #{locale_file}")
    end
  end

  def self.pull_locale_from_phrase(user_auth_token, project_id, locale, target_path)
    command ="curl -sS 'https://api.phraseapp.com/api/v2/projects/#{project_id}/locales/#{locale}/download?file_format=yml' -u #{user_auth_token}:"
    response = self.system_call(command)
    File.open(target_path+"/phrase.#{locale}.yml", "wb+") {|f| f.write response}
  end

  def self.push_locale_to_phrase(user_auth_token, project_id, target_locale, source_locale,source_path)
    file_name = "phrase.#{source_locale}.yml"
    file_path = "#{source_path}/#{file_name}"
    command ="curl -sS 'https://api.phraseapp.com/api/v2/projects/#{project_id}/uploads' -u #{user_auth_token}: -X POST -F file=@#{file_path} -F locale_id=#{target_locale}"
    result = self.system_call(command)
  end

  def self.system_call(command)
    `#{command}`
  end

  def self.get_type_1_interpolations(key)
    key.scan(/(?<=\{\{)(.*?)(?=\}\})/).flatten
  end

  def self.get_type_2_interpolations(key)
    key.scan(/(?<=\%\{)(.*?)(?=\})/).flatten
  end


  def self.validate_html_tags_for_key(english_value, other_locale_value)
    nokogiri_eng_object = Nokogiri::HTML::DocumentFragment.parse(english_value)
    nokogiri_locale_object = Nokogiri::HTML::DocumentFragment.parse(other_locale_value)
    return self.validate_nokogiri_objs(nokogiri_eng_object, nokogiri_locale_object)
  end

  def self.validate_interpolation_tags_for_key(english_value, other_locale_value)
    tags_type_1_en = self.get_type_1_interpolations(english_value)
    tags_type_2_en = self.get_type_2_interpolations(english_value)
    tags_type_1_locale = self.get_type_1_interpolations(other_locale_value)
    tags_type_2_locale = self.get_type_2_interpolations(other_locale_value)
    return (tags_type_1_locale - tags_type_1_en).empty? && (tags_type_1_en - tags_type_1_locale).empty? && (tags_type_2_locale - tags_type_2_en).empty? && (tags_type_2_en - tags_type_2_locale).empty?
  end

  def self.get_all_elements(obj)
    return [] unless obj.present?
    result = []
    obj.traverse do |child|
      next if child.class != Nokogiri::XML::Element
      attr_hash = {}
      child.attributes.each do |key, attribute|
       attr_hash[key] = attribute.value.delete(" ")
      end
      result << [ child.name, attr_hash ]
    end
    result.sort! do |first, second|
      name1, hash1 = first
      name2, hash2 = second
      if name1 == name2
        hash1.to_a.sort <=> hash2.to_a.sort
      else
        name1 <=> name2
      end
    end
    return result
  end

  def self.validate_nokogiri_objs(obj1, obj2)
    if self.get_all_elements(obj1) == self.get_all_elements(obj2)
      return NokogiriObj::VALID
    else
      return NokogiriObj::ERROR
    end
  end

end
