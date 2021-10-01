require_relative './../../test_helper.rb'

# DjSourcePriority will be reset in teardown defined in test_helper.rb
class DjSourcePriorityHelperTest < ActiveSupport::TestCase
  include DjSourcePriorityHelper

  def test_set_web_dj_priority
    set_web_dj_priority
    assert_equal DjSourcePriority::WEB, Delayed::Job.source_priority
  end

  def test_set_bulk_dj_priority
    set_bulk_dj_priority
    assert_equal DjSourcePriority::BULK, Delayed::Job.source_priority
  end

  def test_set_api_dj_priority
    set_api_dj_priority
    assert_equal DjSourcePriority::API, Delayed::Job.source_priority
  end

  def test_set_cron_dj_priority
    set_cron_dj_priority
    assert_equal DjSourcePriority::CRON, Delayed::Job.source_priority
  end

  def test_set_cron_high_dj_priority
    set_cron_dj_priority(true)
    assert_equal DjSourcePriority::CRON_HIGH, Delayed::Job.source_priority
  end
end