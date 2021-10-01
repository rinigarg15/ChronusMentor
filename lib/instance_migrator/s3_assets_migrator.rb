# options = {access_key: "", secret_key: "", source_region: "", target_region: "", target_bucket_name: "", source_common_bucket: "", target_common_bucket: "", source_org_id: ""}
#parameters = [source_environment, source_seed, s3_assets_csv, options]
#InstanceMigrator::S3AssetsMigrator.new(*parameters).migrate_assets
module InstanceMigrator
  class S3AssetsMigrator
    attr_accessor :source_environment, :source_seed, :s3_assets_csv, :buckets, :models, :source_s3, :target_s3, :target_bucket_name, :source_common_bucket, :target_common_bucket, :source_org_id
    def initialize(source_environment, source_seed, s3_assets_csv, options={})
      self.source_seed = source_seed
      self.source_environment = source_environment
      self.s3_assets_csv = s3_assets_csv
      self.source_s3 = get_s3_object(options[:access_key], options[:secret_key], options[:source_region])
      self.target_s3 = get_s3_object(options[:access_key], options[:secret_key], options[:target_region])
      self.target_bucket_name = options[:target_bucket_name]
      self.source_common_bucket = options[:source_common_bucket]
      self.target_common_bucket = options[:target_common_bucket]
      self.source_org_id = options[:source_org_id]
      self.buckets = new_hash
      self.models = new_hash
    end

    def migrate_assets
      raise "S3 Assets csv file is not present" unless File.exist?(s3_assets_csv)
      raise "Target bucket name should be present" unless target_bucket_name.present?
      processes = (Class.new.extend(Parallel::ProcessorCount).processor_count)/2
      csv_sets = create_csv_sets(s3_assets_csv, processes)
      @output_csv = CSV.open(get_output_csv, "w")
      Parallel.each(csv_sets, in_processes: processes) do |csv_set|
        csv_set.each do |source_bucket_name, source_key, model_name, source_id, attachment_key|
          target = models[model_name][get_source_audit_key(source_id, false)]
          (@output_csv << [source_bucket_name, target_bucket_name, source_key, nil, "target not found"]) && next unless target.present?
          target_id = target.try(:id)
          target_key = source_key.gsub("/#{source_id}/", "/#{target_id}/")
          model = (model_name.include?("::Translation") && model_name.constantize.reflect_on_all_associations(:belongs_to).select { |assoc| assoc.name == :globalized_model }.first.try(:class_name)) || model_name
          acl_permission = get_acl_permission(model, attachment_key, target)
          copy_s3_object_from_source_to_target(source_bucket_name, target_bucket_name, source_key, target_key, acl_permission)
        end
      end
      migrate_saml_files_in_s3
      @output_csv.close
    end

    private

    def create_csv_sets(file, processes)
      csv = CSV.read(file)
      visited_hash = {}
      cleaned_up_csv_rows = []
      # each row has source_bucket_name, source_key, model_name, source_id, attachment_key
      csv.each do |row|
        source_key = row[1]
        next if visited_hash[source_key].present?
        visited_hash[source_key] = true
        cleaned_up_csv_rows << row
      end
      populate_models_hash(cleaned_up_csv_rows)
      cleaned_up_csv_rows.each_slice((cleaned_up_csv_rows.count.to_f/processes).ceil).to_a
    end

    def get_acl_permission(model, attachment_key, target)
      Paperclip::AttachmentRegistry.definitions_for(model.constantize)[attachment_key.to_sym].try(:s3_permissions) || (model.constantize.subclasses.present? && Paperclip::AttachmentRegistry.definitions_for(target.type.constantize)[attachment_key.to_sym].try(:s3_permissions)) || :public_read
    end

    def migrate_saml_files_in_s3
      target_org = get_records_for_source_audit_keys("Organization", get_source_audit_key(source_org_id), { condition: "=" }).first
      return unless target_org.present? && target_org.has_saml_auth?
      copy_objects_with_prefix_from_source_to_target(source_org_id, target_org.id)
    end

    def get_output_csv
      File.join(File.dirname(s3_assets_csv), "#{File.basename(s3_assets_csv, File.extname(s3_assets_csv))}_processed#{File.extname(s3_assets_csv)}")
    end

    def get_records_for_source_audit_keys(model_name, source_audit_keys, options={})
      records = model_name.constantize.where("source_audit_key #{options[:condition]} #{source_audit_keys}")
      (options[:index].present? ? records.index_by(&:source_audit_key) : records)
    end

    def get_source_audit_key(source_id, quotes = true)
      source_audit_key = "#{source_environment}_#{source_seed}_#{source_id}"
      (quotes.present? ? "'#{source_audit_key}'" : source_audit_key)
    end

    def populate_models_hash(csv)
      # In a csv row, third column will be model name and last column will be id in source db
      source_audit_key_map = csv.inject({}) do |hash, row|
        # row[2] => model name, row[3] => id
        hash[row[2]] ||= []
        hash[row[2]] << get_source_audit_key(row[3])
        hash
      end
      source_audit_key_map.each do |model_name, source_audit_key_values|
        models[model_name] = get_records_for_source_audit_keys(model_name, "(#{source_audit_key_values.join(",")})", {condition: "IN", index: true})
      end
    end

    def get_bucket(s3_object, bucket_name)
      buckets[bucket_name] ||= s3_object.buckets[bucket_name]
    end

    def copy_s3_object_from_source_to_target(source_bucket_name, target_bucket_name, source_key, target_key, acl_permission)
      source_bucket = get_bucket(source_s3, source_bucket_name)
      target_bucket = get_bucket(target_s3, target_bucket_name)
      begin
        source_object = source_bucket.objects[source_key]
        target_object = target_bucket.objects[target_key]
        source_object.copy_to(target_object, acl: acl_permission)
        @output_csv << [source_bucket_name, target_bucket_name, source_key, target_key, "successfully copied"]
      rescue AWS::Errors::Base => e
        @output_csv << [source_bucket_name, target_bucket_name, source_key, target_key, e.message]
      end
    end

    def copy_objects_with_prefix_from_source_to_target(source_id, target_id)
      source_bucket = get_bucket(source_s3, source_common_bucket)
      source_objects = source_bucket.objects.with_prefix("#{SAML_SSO_DIR}/#{source_id}/")
      source_objects.each do |source_object|
        source_key = source_object.key
        target_key = source_key.gsub("/#{source_id}/", "/#{target_id}/")
        copy_s3_object_from_source_to_target(source_common_bucket, target_common_bucket, source_key, target_key, :authenticated_read)
      end
    end

    def new_hash
      return ActiveSupport::HashWithIndifferentAccess.new
    end

    def get_s3_object(access_key, secret_key, region)
      raise "Access_key, Secret_key, Source region and Target Region should be present" unless access_key.present? && secret_key.present? && region.present?
      AWS.config(:s3_server_side_encryption => :aes256) if defined?(ENABLE_S3_SERVER_SIDE_ENCRYPTION) && ENABLE_S3_SERVER_SIDE_ENCRYPTION
      AWS::S3.new(:access_key_id => access_key, :secret_access_key => secret_key, :region => region)
    end
  end
end
