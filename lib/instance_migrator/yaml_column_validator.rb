module InstanceMigrator
  class YAMLColumnValidator
    attr_accessor :output_csv, :newly_introduced_keys, :current_level_hash
    def initialize(csv_file_path = nil)
      self.output_csv = csv_file_path || "tmp/yaml_column_validator.csv"
      self.newly_introduced_keys = []
      self.current_level_hash = {}
    end

    def validate
      # Replace integers in the keys with %. For example: "request_1" should be stored as "request_%", "1" should be stored as "%".
      yaml_base_hash = YAML.load(IO.read(Rails.root.to_s + "/test/fixtures/files/instance_migrator/yaml_columns_base_hash.ym"))
      CSV.open(File.join(Rails.root, self.output_csv), "w") do |csv|
        csv << ["Model Name", "Model ID", "Newly Introduced Keys", "Current Level of Hash"]
        yaml_base_hash.each do |model, columns|
          puts "Validating #{model} ......"
          columns.each do |column, base_hash|
            model.constantize.pluck(:id, column).each do |record_id, column_value|
              next if column_value.blank?
              current_hash = column_value.is_a?(Hash) ? column_value : YAML.load(column_value)
              # reset items to be populated in csv
              self.newly_introduced_keys = []
              self.current_level_hash = {}
              result = compare_hashes(new_hash(current_hash), new_hash(base_hash))
              csv << [model, record_id, self.newly_introduced_keys, self.current_level_hash] unless result
            end
          end
        end
      end
    end

    private

    def compare_hashes(current_hash, base_hash)
      return true if current_hash.nil? || !current_hash.is_a?(Hash) || base_hash["SKIP_KEYS"].present?
      return false if check_newly_introduced_keys_available?(current_hash, base_hash)
      current_hash.each_key do |key|
        base_key = replace_integer_in_key(key)
        success = compare_hashes(current_hash[key], base_hash[base_key])
        # Stop the recursion at the current level when the current_hash have new keys.
        return false unless success
       end
      true
    end

    def new_hash(old_hash)
      ActiveSupport::HashWithIndifferentAccess.new(old_hash)
    end

    def replace_integer_in_key(key)
      key.to_s.gsub(/(\d)+$/, "%")
    end

    def replace_integer_in_all_keys(key_set)
      keys = key_set.is_a?(Hash) ? key_set.keys : key_set
      modified_keys = keys.map do |key|
        replace_integer_in_key(key)
      end
      modified_keys.uniq
    end

    def check_newly_introduced_keys_available?(current_hash, base_hash)
      current_hash_keys = replace_integer_in_all_keys(current_hash)
      base_hash_keys = base_hash.is_a?(Hash) ? replace_integer_in_all_keys(base_hash) : []
      self.newly_introduced_keys = (current_hash_keys - base_hash_keys)
      self.current_level_hash = current_hash
      self.newly_introduced_keys.present?
    end
  end
end