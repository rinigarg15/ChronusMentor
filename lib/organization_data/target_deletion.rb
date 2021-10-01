module OrganizationData
  class TargetDeletion
    # after destroy callbacks in the below models have to be invoked.
    MODELS_TO_DESTROY = ["User", "Program", "ThreeSixty::SurveyAnswer"]
    def initialize(ids, options={})
      @db_delete_errors = []
      @s3_delete_errors = []
      @db_objects_collect_file_path = options[:db_file_path] || "#{Rails.root}/tmp/db_objects_#{ids}.json"
      @s3_asset_collect_file_path = options[:s3_asset_file_path] || "#{Rails.root}/tmp/s3_assets_#{ids}.csv"
      @operation = options[:operation]
    end

    def delete_s3_objects
      ChronusS3Utils::S3Helper.authenticate_s3
      csv = CSV.read(@s3_asset_collect_file_path)
      # csv row will have bucket_name, attachment_path, parent_class_name, parent_id. Neglecting parent_class_name & parent_id as both are not needed here.
      #converting array of arrays to array of hashes - to remove duplicates
      s3_objects = csv.inject({}) do |hash, values|
        hash.merge!(values.second => values.first)
      end
      begin
        s3_objects.each do |s3_object,s3_bucket|
          ChronusS3Utils::S3Helper.delete(s3_bucket,s3_object)
          puts "deleted #{s3_object} from #{s3_bucket}"
        end
      rescue AWS::Errors::Base => e
        @s3_delete_errors << e.message
      end
    end

    def delete_db_objects
      json_text = File.read(@db_objects_collect_file_path)
      rows = JSON.parse(json_text)
      #Each row will contain model and its ids
      rows.each do |row|
        begin
          puts "Deleting #{row[1].count} records from #{row[0]}"
          sliced_object_ids = row[1].each_slice(10000)
          sliced_object_ids.each_with_index do |del_ids, index|
            puts "#{row[0]}: Index:#{index}"
            ActiveRecord::Base.transaction do
              to_be_deleted = row[0].constantize.unscoped.where(:id => del_ids)
              cloned_objects_for_callback = to_be_deleted.map(&:clone)
              to_be_deleted.delete_all
              # Depicting after_destroy for models in MODELS_TO_DESTROY
              have_destroy_callbacks = (@operation == OrganizationData::TargetCollection::OPERATION::COLLECT_FOR_PROGRAM_DELETION && MODELS_TO_DESTROY.include?(row[0]))
              cloned_objects_for_callback.map(&:handle_destroy) if have_destroy_callbacks
            end
          end
        rescue => error
          @db_delete_errors << error.message
        end
      end
    end

    def delete_db_data
      raise "No file present. Please collect data before deletion" unless File.exist?(@db_objects_collect_file_path)
      ActiveRecord::Base.transaction do
        DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
          delete_db_objects
        end
      end
    end

    def delete_s3_data
      raise "No file present. Please collect data before deletion" unless File.exist?(@s3_asset_collect_file_path)
      delete_s3_objects
    end

    def get_errors
      errors = []
      errors << "DB object deletion errors: #{@db_delete_errors}" if @db_delete_errors.present?
      errors << "S3 asset deletion errors: #{@s3_delete_errors}" if @s3_delete_errors.present?
      return errors
    end

    def self.fix_counter_culture_counts
      ApplicationEagerLoader.load
      models = ActiveRecord::Base.descendants
      visited_models = { Program.name => true }
      models.each do |model|
        # If counter_culture is called in base class then after_commit_counter_cache will be shown in child class too.
        next if (visited_models[model.name].present? || visited_models[model.superclass.name].present?)
        if model.send("after_commit_counter_cache").present?
          model.counter_culture_fix_counts
          visited_models[model.name] = true
        end
      end
    end
  end
end