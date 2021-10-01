require_relative './../test_helper.rb'

class FeedImportConfigurationTest < ActiveSupport::TestCase

  def setup
    super
    @organization = programs(:org_primary)
    @feed_import = @organization.create_feed_import_configuration!(frequency: 1.day.to_i, enabled: true, sftp_user_name: "org")
  end

  def test_validations
    assert_equal programs(:org_primary), @feed_import.organization
    @feed_import.frequency = nil
    assert_false @feed_import.valid?
    assert_equal ["is not included in the list"], @feed_import.errors[:frequency]
    @feed_import.frequency = 4.days.to_i
    assert_false @feed_import.valid?
    assert_equal ["is not included in the list"], @feed_import.errors[:frequency]
    @feed_import.frequency = 1.day.to_i
    assert @feed_import.valid?
    @feed_import.sftp_user_name = nil
    assert_false @feed_import.valid?
    assert_equal ["can't be blank"], @feed_import.errors[:sftp_user_name]
    @feed_import.organization = nil
    assert_false @feed_import.valid?
    assert_equal ["can't be blank"], @feed_import.errors[:organization]
  end

  def test_scopes
    assert_equal programs(:org_primary), @feed_import.organization

    enabled_feeds = FeedImportConfiguration.enabled
    assert_equal FeedImportConfiguration.where(enabled: true).count, enabled_feeds.count
    assert enabled_feeds.all?(&:enabled)

    assert_equal FeedImportConfiguration.count, enabled_feeds.count+FeedImportConfiguration.where(enabled: false).count

    daily_feeds = FeedImportConfiguration.daily
    weekly_feeds = FeedImportConfiguration.weekly

    assert_equal FeedImportConfiguration.where(frequency: 1.day.to_i).count, daily_feeds.count
    daily_feeds.each do |feed_import|
      assert_equal 1.day.to_i, feed_import.frequency
      assert_not_includes weekly_feeds, feed_import
    end

    assert_equal FeedImportConfiguration.where(frequency: 1.week.to_i).count, weekly_feeds.count
    weekly_feeds.each do |feed_import|
      assert_equal 1.week.to_i, feed_import.frequency
      assert_not_includes daily_feeds, feed_import
    end
  end

  def test_enable_disable
    @feed_import.enable!
    assert @feed_import.enabled
    @feed_import.disable!
    assert_false @feed_import.enabled
  end

  def test_frequency
    @feed_import.set_frequency!(1.day.to_i)
    assert_equal 1.day.to_i, @feed_import.frequency
  end

  def test_config_options
    config_options = {"A"=>"Amazon", "B"=>"Bbva", "C"=>"Chronus"}
    @feed_import.set_config_options!(config_options)
    assert_equal config_options, @feed_import.get_config_options

    config_options = {"secondary_questions_map" => {8 => "Location", 19 => "Manager"}, "A"=>"Amazon"}
    @feed_import.set_config_options!(config_options)
    expected_config_options = {"secondary_questions_map" => {"8" => "Location", "19" => "Manager"}, "A"=>"Amazon"}
    assert_equal expected_config_options, @feed_import.get_config_options
    assert_equal expected_config_options["secondary_questions_map"], @feed_import.get_config_options[:secondary_questions_map]

    config_options = {secondary_questions_map: {8 => "Location", 19 => "Manager"}, A: "Amazon"}
    @feed_import.set_config_options!(config_options)
    expected_config_options = {"secondary_questions_map" => {"8" => "Location", "19" => "Manager"}, "A"=>"Amazon"}
    assert_equal expected_config_options, @feed_import.get_config_options
    assert_equal expected_config_options["secondary_questions_map"], @feed_import.get_config_options[:secondary_questions_map]
  end

  def test_config_options_as_hash_with_indifferent_access
    config_options = {"A"=>"Amazon", B: "Bbva"}
    @feed_import.set_config_options!(config_options)
    new_config_options = @feed_import.get_config_options
    assert_equal config_options["A"], new_config_options[:A]
    assert_equal config_options["A"], new_config_options["A"]
    assert_equal config_options[:B], new_config_options["B"]
    assert_equal config_options[:B], new_config_options[:B]

  end

  def test_source_options
    source_options = {"A"=>"Amazon", "B"=>"Bbva", "C"=>"Chronus"}
    @feed_import.set_source_options!(source_options)
    assert_equal source_options, @feed_import.get_source_options
  end

end