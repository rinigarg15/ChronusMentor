require_relative './../test_helper.rb'

class TzInfoTest < ActionView::TestCase
  def test_tzinfo_data_gem_version
    assert_gem_version("tzinfo-data", "1.2016.9", "'tzinfo-data' gem seems to be changed, please run 'rake tz:handle_tzinfo_update' to handle new timezones.")
  end

  def test_obsolete_timezones_yml_integrity
    tz_yml_file_name = Dir.glob("#{Rails.root}/app/files/obsolete_timezones_*.yml").first
    hash_in_file_name = File.basename(tz_yml_file_name,".yml").split("_").last
    calculated_md5_hash = `cat #{tz_yml_file_name} | md5sum`.split[0]
    assert_equal(hash_in_file_name, calculated_md5_hash, "Don't change the (app/files/obsolete_timezones_*.yml) file manually, please run 'rake tz:handle_tzinfo_update' to update the obsolete timezones list")
  end
end