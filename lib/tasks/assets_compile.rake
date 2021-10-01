# In Rails3 after precompiling the assets, both digested asset and original asset will be present in assets folder, whereas in Rails4 only digested assets will be present. In plugins like Kendo the non-digested assets are used so we need the original image files to be available in s3.Some helpful links are below.
# https://bibwild.wordpress.com/2014/10/02/non-digested-asset-names-in-rails-4-your-options/
# https://github.com/rails/sprockets-rails/issues/49#issuecomment-21316365
# https://gist.github.com/ryana/6049833#file-sprockets-patch-rb
Rake::Task["assets:precompile"].enhance do
  Rake::Task["assets:precompile:nondigest"].invoke
  Rake::Task["assets:sync"].invoke if defined?(AssetSync) && !AssetSync.config.run_on_precompile
end

namespace "assets:precompile" do
  desc "Copy non-digested assets to assets folder"
  task :nondigest => :environment  do
    manifest_path = Dir.glob(File.join(Rails.root, 'public/assets/.sprockets-manifest-*.json')).first
    manifest_data = JSON.load(File.new(manifest_path))

    manifest_data["assets"].each do |logical_path, digested_path|
      logical_pathname = Pathname.new logical_path
      full_digested_path    = File.join(Rails.root, 'public/assets', digested_path)
      full_nondigested_path = File.join(Rails.root, 'public/assets', logical_path)
      if File.exist?(full_digested_path)
        puts "Copying to #{full_nondigested_path}"

        # Use FileUtils.copy_file with true third argument to copy
        # file attributes (eg mtime) too, as opposed to FileUtils.cp
        FileUtils.copy_file full_digested_path, full_nondigested_path, true
      end
    end
  end
end