require_relative './../../../../test_helper'

class CronTasks::Globalization::TranslationsBackupTest < ActiveSupport::TestCase

  def test_perform
    modify_const(:APP_CONFIG, phrase_backup_project_id: "abc123") do
      Timecop.freeze do
        time_now = Time.now.to_i / 86400
        target_path = File.join(Rails.root, "tmp", "backup_phraseapp", time_now.to_s)
        output_path = "#{target_path}/#{time_now}.yml"

        File.expects(:chmod).with(0777, target_path).once
        FileUtils.expects(:mkdir_p).with(target_path).once
        FileUtils.expects(:rm_rf).with(File.join(Rails.root, "tmp", "backup_phraseapp")).once
        Globalization::PhraseappUtils.expects(:backup_translations).with(target_path, output_path, time_now).once
        CronTasks::Globalization::TranslationsBackup.new.perform
      end
    end
  end

  def test_perform_with_config_disabled
    Globalization::PhraseappUtils.expects(:backup_translations).never
    CronTasks::Globalization::TranslationsBackup.new.perform
  end
end