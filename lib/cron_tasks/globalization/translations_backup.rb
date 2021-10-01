# Pull latest translations from the PhraseApp project and upload to S3.
module CronTasks
  module Globalization
    class TranslationsBackup
      include Delayed::RecurringJob

      def perform
        return if APP_CONFIG[:phrase_backup_project_id].blank?

        time_now = Time.now.to_i / (24 * 60 * 60)
        target_path = File.join(Rails.root, "tmp", "backup_phraseapp", time_now.to_s)
        output_path = "#{target_path}/#{time_now}.yml"
        FileUtils.mkdir_p(target_path)
        File.chmod(0777, target_path)
        begin
          ::Globalization::PhraseappUtils.backup_translations(target_path, output_path, time_now)
        ensure
          FileUtils.rm_rf(File.join(Rails.root, "tmp", "backup_phraseapp"))
        end
      end
    end
  end
end