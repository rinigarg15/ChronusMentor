require 'yaml'

class MissingCustomTerms
  @@root_dir  = "#{File.dirname(__FILE__)}/../.." 
  @@ignore_list_file = File.read(@@root_dir + "/lib/ChronusTerminologyVerifier/ignore_list.txt")
  @@yaml_dir = "/config/locales/*.en.yml"
  # @@yaml_test_dir = "/test/fixtures/files/terminology_testfiles/"
  @@match_terms = ["mentor", "mentee", "mentoring connection", "meeting", "resource", "mentoring" "article"]

  def self.catch_terms_not_customized(search_dir = nil, of_mails = false)
    result_hash = {}
    if search_dir.nil?
      search_dir = @@yaml_dir
    end
    Dir.glob(@@root_dir + search_dir) do |file|
      yaml_file = YAML.load_file(file)
      file_hash = {}
      dotted_hash = {}
      to_shallow_hash(yaml_file.to_a).sort.map do |key,value|
        dotted_hash[key] = value
      end
      # Check each key
      dotted_hash.each do |parent, node|
        parent_split = parent.split('.')
        yaml_key = parent_split[parent_split.length-1]
        is_a_tag = parent_split.include?('tags')
        if of_mails
          if (is_a_tag || ((!yaml_key.starts_with? 'title') && (!yaml_key.starts_with? 'description')))
            next
          end
        end
        if dotted_hash.has_key?(get_next_version(parent))
          next
        end
        #Match terms
        node = node.to_s
        node.gsub!(/%{(.+?)}/, '')
        match_list = Regexp.new(Regexp.union(@@match_terms).source, Regexp::IGNORECASE)
        if node.gsub("chronus-mentor-assets", "").match(match_list)
          file_hash[parent] = node
        end
      end
      #Ignore pairs which are in Ignore_List
      self.ignore_whitelisted_files!(file_hash, file)
      if !file_hash.empty?
        result_hash[file] = file_hash
      end
    end
    result_hash
  end

  private
  def self.to_shallow_hash(hash)
    hash.inject({}) do |shallow_hash, (key, value)|
      if value.is_a?(Hash)
        to_shallow_hash(value).each do |sub_key, sub_value|
          shallow_hash[[key, sub_key].join(".")] = sub_value
        end
      else
        shallow_hash[key.to_s] = value
      end
      shallow_hash
    end
  end

  def self.get_next_version(key)
    p_key = key.chomp("_html")# returns x for x_html
    is_html = key.end_with?("_html")
    version = 0
    match_str =  /.*_v(\d{1,})/.match(p_key)
    version = match_str.captures[0] if !match_str.nil? # returns 0, 1 for x, x_v1
    next_key = p_key.gsub(/_v\d{1,}$/,'') + "_v" + (version.to_i + 1).to_s # returns x_v1, x_v2 for x, x_v1
    is_html ? next_key = next_key + "_html" : next_key # returns x_html for x if is_html = true
  end

  # Ignore pairs which are in Ignore_List
  def self.ignore_whitelisted_files!(file_hash, file)
    file_hash.each do |key, value|
      if @@ignore_list_file.include? (File.basename(file) + "||" + key + "||" + value)
        file_hash.delete(key)
      end
    end  
  end
end
