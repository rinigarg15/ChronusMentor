require_relative './../../../test_helper.rb'

class AssetSyncOverridesTest < ActiveSupport::TestCase
  def test_asset_sync_upload_file_override
    assert_operator Gem::Version.new(get_gem_version('asset_sync')), :<, Gem::Version.new('2.2.0'), "The gem version is equal to or higher than 2.2.0. Please remove the asset_sync_overrides, if its not applicable anymore."
  end
end