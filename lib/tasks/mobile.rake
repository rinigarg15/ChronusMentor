# rake mobile:move_cordovajs_s3
namespace :mobile do
  desc "Move cordova js files to s3 public folder"
  task :move_cordovajs_s3 => [:environment] do
    ["ios", "android"].each do |platform|
      filepath = "#{Rails.root.to_s}/app/assets/javascripts/cordova/#{platform}/cordova.js"
      ChronusS3Utils::S3Helper.transfer(filepath, "mobile/#{platform}", APP_CONFIG[:chronus_mentor_common_bucket], {file_name: "cordova.js", publicaccess: true, content_type: "text/javascript", discard_source: false})
    end
  end
end