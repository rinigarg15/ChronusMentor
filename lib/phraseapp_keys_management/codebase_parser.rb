module PhraseappKeysManagement
  class CodebaseParser
    attr_accessor :key_occurrence_map, :quote_array, :keys_found, :options
    LOG_FOLDER = "#{Rails.root}/tmp/key_logs"
    KEYS_TO_SKIP = ["display_string", "activemodel", "activerecord", "timezone", "errors", "tab_constants", "push_notification", "datetime", "date", "time", "simple_captcha", "support", "will_paginate"]
    INTERPOLATION_REGEX = ".*\#{.*\}.*"
    QUOTE_REGEX_PATTERNS = [/"([^"]*)/, /'([^']*)/]

    module MESSAGE
      LOG = "Found in log"
      SKIP = "Skipped"
      MISSING = "Missing"
      DIRECT = "Direct"
    end

    def initialize(options = {})
      self.keys_found = 0
      self.quote_array = []
      self.options = options
      self.key_occurrence_map = Dir.glob(Globalization::PhraseappUtils::LOCALE_PATHS).inject({}) do |key_occurrence_map, file_path|
        next key_occurrence_map if file_path.match Globalization::PhraseappUtils::EXCLUDE_PATH_REGEX
        keys_map = YAML.load(File.read(file_path))
        populate_key_occurrence_map(keys_map, file_path, key_occurrence_map)
      end
      compute_keys_missing_in_codebase unless self.options[:skip_keys_missing_from_codebase]
      skip_keys
    end

    def get_unused_keys
      compute_occurrences
      self.key_occurrence_map.reject{ |_, v| v[1] }.keys
    end

    private

    def compute_occurrences
      start_time = Time.now
      build_array_to_search
      compute_regex_matches
      compute_direct_matches
      search_logs unless self.options[:skip_log_search]
      puts "\nTime taken : #{Time.now - start_time} seconds"
    end

    def populate_key_occurrence_map(keys_map, file_path, key_occurrence_map, key_parts = [])
      keys_map.each_pair do |key_part, value|
        key_part_array = key_parts + [key_part]
        key = key_part_array[1..key_part_array.size].join(".")
        if value.is_a?(Hash)
          if value.size > 1 && (value.keys - ["zero", "one", "other"]).blank?
            key_occurrence_map[key] = [file_path, false, ""]
            next
          end
          key_occurrence_map = populate_key_occurrence_map(value, file_path, key_occurrence_map, key_part_array)
        else
          key_occurrence_map[key] = [file_path, false, ""]
        end
      end
      key_occurrence_map
    end

    def skip_keys
      puts "\nSkipping keys"
      keys_to_skip = KEYS_TO_SKIP.map{ |key_to_skip| /^#{key_to_skip}\./ }
      keys_to_skip += File.readlines("#{Rails.root}/lib/phraseapp_keys_management/keys_to_ignore.txt").map{ |key| Regexp.new(key.strip) }
      regex_to_skip = Regexp.union(keys_to_skip)
      self.key_occurrence_map.keys.grep(regex_to_skip).each do |translation_key|
        handle_found_key(translation_key, MESSAGE::SKIP) unless self.key_occurrence_map[translation_key][1]
      end
    end

    def build_array_to_search
      puts "\nBuilding array to search"
      regex = Regexp.union(%Q["], %Q['])
      get_files_to_search.each do |file_path|
        self.quote_array += File.foreach(file_path).grep(regex).map(&:strip)
      end
      self.quote_array = self.quote_array.uniq - File.readlines("#{Rails.root}/lib/phraseapp_keys_management/lines_to_omit.txt").map(&:strip)
    end

    def get_files_to_search
      FileList.new("#{Rails.root}/**/*.erb") do |file_list|
        file_list.add("#{Rails.root}/**/*.rb")
        file_list.add("#{Rails.root}/**/*.rake")
      end.exclude(self.options[:files_to_ignore])
    end

    def compute_direct_matches
      puts "\nComputing direct matches"
      QUOTE_REGEX_PATTERNS.each do |quote_pattern|
        print "."
        self.quote_array.grep(quote_pattern).each do |key_pattern_string|
          keys = key_pattern_string.scan(quote_pattern).flatten
          keys.each do |key|
            key_details = self.key_occurrence_map[key]
            next if !key_details || key_details[1] || key_details[2] == MESSAGE::MISSING
            handle_found_key(key, MESSAGE::DIRECT)
          end
        end
      end
    end

    def compute_regex_matches
      puts "\nComputing regex matches"
      key_patterns = get_key_patterns
      key_patterns.each do |key_pattern|
        print "."
        key_pattern_array = build_sub_array(key_pattern)
        key_pattern_array.each do |key_pattern_string|
          regex = construct_regex(key_pattern_string, key_pattern)
          self.key_occurrence_map.keys.grep(regex).each do |key|
            handle_found_key(key, regex) unless self.key_occurrence_map[key][1]  || self.key_occurrence_map[key][2] == MESSAGE::MISSING
          end
        end
      end
    end


    def get_key_patterns
      key_patterns = self.key_occurrence_map.keys.map{ |k| k.split(".").first }.uniq - KEYS_TO_SKIP
      key_patterns.map{ |key_pattern| "#{key_pattern}." }
    end

    def build_sub_array(key_pattern)
      key_pattern = "#{key_pattern}#{INTERPOLATION_REGEX}"
      regex = /\"#{key_pattern}\"|'#{key_pattern}'/
      self.quote_array.grep(regex)
    end

    def construct_regex(key_pattern_string, key_pattern)
      regex_matches = []
      regex = /(#{Regexp.escape(key_pattern)}.[^}]*.[^(\",')]*)/
      loop do
        start_index = key_pattern_string.index("#{key_pattern}")
        break unless start_index.present?
        regex_matches << key_pattern_string.scan(regex)
        key_pattern_string = key_pattern_string[start_index + key_pattern.length..key_pattern_string.length - 1]
      end
      if regex_matches.present?
        Regexp.union regex_matches.flatten.compact.uniq.map { |regex| /#{Regexp.escape(regex.gsub("\"|'", "")).gsub(/\\#\\{.*}/, ".*")}/ }
      end
    end

    def compute_keys_missing_in_codebase
      puts "\nComputing keys missing in codebase"
      user_auth_token = ENV['PHRASEAPP_APOLLODEV_ACCESS_TOKEN']
      project_id = ENV['PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP']
      keys_from_local = Globalization::PhraseappUtils.fetch_keys_from_local
      en_locale = Globalization::PhraseappUtils.fetch_supported_locales_from_phrase(user_auth_token, project_id).find{ |locale| locale["code"] == "en" }
      keys_from_phrase = Globalization::PhraseappUtils.fetch_keys_from_phrase(user_auth_token, project_id, en_locale)
      unused_keys_array = keys_from_phrase - keys_from_local
      unused_keys_array.each do |key|
        unless [key].grep(/phraseapp/).present?
          print "."
          self.key_occurrence_map[key] = ["", false, MESSAGE::MISSING]
        end
      end
    end

    def search_logs
      puts "\nSearching log files"
      files_to_search = Dir["#{LOG_FOLDER}/*"]
      files_to_search.each do |file_path|
        File.foreach(file_path) do |line|
          print "."
          translation_key = line.delete("\n")
          next if !self.key_occurrence_map[translation_key] || self.key_occurrence_map[translation_key][1]
          handle_found_key(translation_key, MESSAGE::LOG)
        end
      end
    end


    def export_result
      export("Found keys", self.key_occurrence_map.select{ |_, v| v[1] }, ["Key", "Location", "Occurrence", "Match"])
      export("Unused keys", self.key_occurrence_map.reject{ |_, v| v[1] }, ["Key", "Location", "Occurrence", "Match"])
    end

    def export(file_name, hash_map, headers)
      export_path = "#{Rails.root}/tmp/#{file_name.to_html_id}_#{Time.now.to_i}.csv"
      CSV.open(export_path, "w+") do |csv|
        csv << headers
        hash_map.each do |row|
          csv << row.flatten
        end
      end
      puts "\nExported #{file_name} to: " + export_path
    end

    def handle_found_key(key, message)
      key_details = self.key_occurrence_map[key]
      key_details[1] = true
      key_details[2] = message
      self.keys_found += 1
    end

  end
end