require 'populator'
module SalesDemo
  class SalesPopulator
    include ChronusS3Utils

    attr_accessor :organization_name, :subdomain, :referer_hash, :delta_date, :delta_month, :solution_pack_referer_hash, :data_file_name, :ckeditor_assets_old_base_url, :imported_ck_assets, :ckeditor_asset_column_names, :ckeditor_asset_rows

    LOCATION = "demo/data/"
    ATTACHMENT_FOLDER = Rails.root + LOCATION + "attachments/"
    CKEDITOR_FOLDER = ATTACHMENT_FOLDER + "ckeditor/"
    METADATA_FILE_PATH = Rails.root + LOCATION + "metadata.json"
    ES_INDEXING_BATCH_SIZE = 100
    FEATURE_POPULATOR_MAPPING = [
      "OrganizationPopulator",
      "SecuritySettingPopulator",
      "ProgramPopulator",
      "ProgramAssetPopulator",
      "NotificationSettingPopulator",
      "OrganizationFeaturePopulator",
      "MemberPopulator",
      "UserPopulator",
      "MembershipRequestPopulator",
      "SolutionPackSettingPopulator",
      "AdminViewPopulator",
      "AdminViewColumnPopulator",
      "OrganizationResourcePopulator",
      "MentoringModelTemplatePopulator",
      "ProfilePicturePopulator",
      "ProfileAnswerPopulator",
      "UserSettingPopulator",
      "GroupPopulator",
      "ObjectRolePermissionPopulator",
      "MentoringModelMilestonePopulator",
      "MentoringModelGoalPopulator",
      "MentoringModelTaskPopulator",
      "ScrapPopulator",
      "ScrapReceiverPopulator",
      "MeetingRequestPopulator",
      "MeetingPopulator",
      "MemberMeetingPopulator",
      "SurveyAnswerPopulator",
      "MemberMeetingResponsePopulator",
      "ActivityLogPopulator",
      "MentoringModelActivityPopulator",
      "GroupCheckinPopulator",
      "UserStateChangePopulator",
      "GroupStateChangePopulator",
      "PagePopulator",
      "PageTranslationPopulator",
      "ProgramInvitationPopulator",
      "CampaignMessageAnalyticsPopulator",
      "AdminMessagePopulator",
      "AdminMessageReceiverPopulator",
      "CampaignEmailPopulator",
      "RecentActivityPopulator",
      "ConnectionActivityPopulator"
    ]

    ElasicsearchSalesDemoHash = {
      "GroupStateChange" => { column_name: :group_id, referer_keys: [:group] },
      "Group" =>           { column_name: :id, referer_keys: [:group]},
      "UserStateChange" => { column_name: :user_id, referer_keys: [:user]},
      "User" =>            { column_name: :id, referer_keys: [:user]},
      "Member" =>          { column_name: :id, referer_keys: [:member]},
      "AbstractMessage" => { column_name: :id, referer_keys: [:admin_message, :scrap]},
      "Meeting" =>         { column_name: :id, referer_keys: [:meeting]},
      "MeetingRequest" =>  { column_name: :id, referer_keys: [:meeting_request]},
      "SurveyAnswer" =>    { column_name: :id, referer_keys: [:survey_answer]},
      "Resource" =>        { column_name: :id, referer_keys: [:resource] }
    }

    def initialize(options)
      self.organization_name = options[:organization_name]
      self.subdomain = options[:subdomain]
      self.referer_hash = {}
      self.solution_pack_referer_hash = {}
      self.imported_ck_assets = {}
      self.data_file_name = "data_#{Time.now.to_i.to_s}.zip"
      download_data_file
      SolutionPack.create_if_not_exist_with_permission(Rails.root + LOCATION, 0777)
      SolutionPack::ExportImportCommonUtils.unzip_file(Rails.root + "demo/#{self.data_file_name}", "data/")
      set_delta_dates(File.read(Rails.root + LOCATION + "extracted_date.txt").to_time)
      read_metadata
    end

    def populate
      begin
        initialize_ckeditor_assets
        DelayedEsDocument.skip_es_delta_indexing do
          FEATURE_POPULATOR_MAPPING.each do |populator|
            populator = "SalesDemo::#{populator}".constantize
            populator.new(self).copy_data
          end
        end
        creation_success = true
        SalesDemo::SalesPopulator.delay.reindex_es(self.referer_hash)
        Matching.perform_organization_delta_index_and_refresh_later(get_organization_from_referer_hash)
      rescue Exception => e
        if self.referer_hash[:organization].present?
          get_organization_from_referer_hash.destroy
        end
        creation_success = false
        Airbrake.notify(e)
        raise e
      ensure
        FileUtils.rm_rf(Rails.root + LOCATION)
        FileUtils.rm_rf(Rails.root + "demo/#{self.data_file_name}")
        send_email_notification(creation_success)
      end
    end

    def initialize_ckeditor_assets
      ckeditor_assets = self.parse_file("ckeditor_assets")
      self.ckeditor_asset_column_names = ckeditor_assets.first.keys
      self.ckeditor_asset_rows = ckeditor_assets.collect(&:values)
    end

    def handle_ck_editor_import(content, organization = nil)
      return "" unless content.present?

      organization ||= get_organization_from_referer_hash
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import_without_solution_pack(self.ckeditor_assets_old_base_url, content, self.imported_ck_assets, self.ckeditor_asset_column_names, self.ckeditor_asset_rows, SalesDemo::SalesPopulator::CKEDITOR_FOLDER, organization, is_sales_demo: true)
    end

    def parse_file(model_name)
      file_name = Rails.root + LOCATION + "#{model_name}.yml"
      YAML.load_file(file_name)
    end

    def populate_solution_pack_id_mappings
      self.solution_pack_referer_hash ||= {}
      id_mappings = YAML.load_file(Rails.root + SalesPopulator::LOCATION + "id_mappings.yml")
      id_mappings.each do |key, value|
        self.solution_pack_referer_hash[key] ||= {}
        self.solution_pack_referer_hash[key].merge!(value)
      end
    end

    def self.reindex_es(referer)
      ElasicsearchSalesDemoHash.each do |model_name, holder|
        includes_list = ElasticsearchConstants::INDEX_INCLUDES_HASH[model_name] || []
        column_name = holder[:column_name]
        column_values = holder[:referer_keys].collect {|referer_key| referer[referer_key].values if referer[referer_key]}.flatten.compact
        if column_values.present?
          model = model_name.constantize
          record_ids = model.where(column_name => column_values).pluck(:id)
          record_ids.each_slice(ES_INDEXING_BATCH_SIZE).each do |batch|
            DelayedEsDocument.delayed_bulk_index_es_documents(model, batch)
          end
        end
      end
    end

    private

    def send_email_notification(creation_success)
      initial_state = ActionMailer::Base.perform_deliveries
      ActionMailer::Base.perform_deliveries = true
      begin
        InternalMailer.sales_demo_organization_creation_status_notification_to_chronus(creation_success, organization_name: self.organization_name, organization_subdomain: self.subdomain).deliver_now
      ensure
        ActionMailer::Base.perform_deliveries = initial_state
      end
    end

    def download_data_file
      bucket_name = APP_CONFIG[:chronus_mentor_common_bucket]
      objects_withprefix = S3Helper.get_objects_with_prefix(bucket_name,SALES_DEMO_DIR)
      objects = objects_withprefix.select{|o| File.basename(o.key).match("data.zip")}
      raise Exception.new("File not found") if objects.blank?
      File.open(Rails.root + "demo/#{self.data_file_name}", "w") { |f| f.write(objects.first.read.force_encoding("UTF-8")) }
    end

    def read_metadata
      return unless File.exists?(METADATA_FILE_PATH)

      file = File.read(METADATA_FILE_PATH)
      metadata_hash = ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(file))
      self.ckeditor_assets_old_base_url = metadata_hash[:ckeditor].try(:[], :assets_base_url)
    end

    def set_delta_dates(extracted_date)
      time_now = Time.now
      self.delta_date = (time_now - extracted_date).to_i

      delta_years = time_now.year - extracted_date.year
      self.delta_month = ((delta_years * 12) + (time_now.month - extracted_date.month)).months
    end

    def get_organization_from_referer_hash
      Organization.find(self.referer_hash[:organization].values.first)
    end
  end
end
