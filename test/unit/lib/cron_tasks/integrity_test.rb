require_relative './../../../test_helper'

class CronTasks::IntegrityTest < ActiveSupport::TestCase

  def test_respond_to_schedule
    cron_tasks = YAML::load(ERB.new(File.read("#{Rails.root}/config/cron_tasks.yml")).result).values.map do |cron_tasks|
      cron_tasks.keys
    end.flatten.uniq.map(&:constantize)

    cron_tasks.each do |cron_task|
      assert cron_task.respond_to?(:schedule)
      assert cron_task.respond_to?(:schedule!)
      assert cron_task.respond_to?(:scheduled?)
    end
  end

  def test_schedule_config
    assert_equal "76e8734b44b10c126252a2094cc9cb8a", `cat #{File.join(Rails.root, 'config', 'cron_tasks.yml')} | md5sum`.split[0]
  end
end