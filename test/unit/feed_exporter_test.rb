require_relative './../test_helper.rb'

class FeedExporterTest < ActiveSupport::TestCase

  def test_validate_organization
    export = FeedExporter.new
    assert_false export.valid?
    assert_equal_hash( { program_id: ["can't be blank"] }, export.errors.messages)
  end

  def test_validate_frequency
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :frequency do
      FeedExporter.create!(program_id: programs(:org_primary).id, frequency: 2.days.to_i, sftp_account_name: "test")
    end
  end

  def test_validate_organization_uniqueness
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :program_id do
      2.times { FeedExporter.create!(program_id: programs(:org_primary).id, sftp_account_name: "test") }
    end
  end

  def test_create_success
    organization = programs(:org_primary)
    feed_exporter = nil

    assert_difference 'FeedExporter.count', 1 do
      feed_exporter = FeedExporter.create!(program_id: organization.id, frequency: 7.days.to_i, sftp_account_name: "test")
    end
    assert_equal organization, feed_exporter.organization
  end

  def test_weekly_and_daily_scope
    weekly = FeedExporter.create!(program_id: programs(:org_primary).id, sftp_account_name: "test")
    daily = FeedExporter.create!(program_id: programs(:org_anna_univ).id, sftp_account_name: "test", frequency: FeedExporter::Frequency::DAILY)
    assert_equal [weekly], FeedExporter.weekly
    assert_equal [daily], FeedExporter.daily
  end

  def test_export_and_upload
    feed_exporter = FeedExporter.create!(program_id: programs(:org_primary).id, sftp_account_name: "test")
    Organization.any_instance.stubs(:members).returns(Member.where(id: members(:f_mentor)))

    mem_config = FeedExporter::MemberConfiguration.new(feed_exporter: feed_exporter, enabled: true)
    mem_config.set_config_options!(headers: ["member_id", "first_name", "last_name", "email"], profile_question_texts: ["Gender"])
    mem_config.save!
    mem_config.load_configurations
    feed_exporter.reload
    members_data = mem_config.get_data
    assert_equal 1, members_data.count
    ChronusS3Utils::S3Helper.expects(:transfer).returns(true).at_least(1)
    feed_exporter.export_and_upload

    Organization.any_instance.unstub(:members)
    feed_exporter.expects(:generate_csv).once
    feed_exporter.export_and_upload
  end
end