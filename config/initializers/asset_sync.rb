if defined?(AssetSync) 
  s3_creds = YAML::load(ERB.new(File.read(File.dirname(__FILE__) + '/../s3.yml')).result)[Rails.env]

  if s3_creds["s3_assets_bucket"]
    AssetSync.configure do |config|
      config.fog_provider = 'AWS'
      # config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
      # config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
      # config.fog_directory = ENV['FOG_DIRECTORY']
      config.aws_iam_roles = true
      config.fog_directory = s3_creds["s3_assets_bucket"]

      # Increase upload performance by configuring your region
      config.fog_region = s3_creds["region"]
      #
      # Delete previously precompile files
      config.existing_remote_files = "delete"
      #
      # Don't delete files from the store
      # config.existing_remote_files = "keep"
      #
      # Automatically replace files with their equivalent gzip compressed version
      # config.gzip_compression = true
      config.gzip_compression = true
      # Switch off run_on_precompile to run the rake assets:precompile:nondigest before asset sync
      config.run_on_precompile = false
      #
      # Use the Rails generated 'manifest.yml' file to produce the list of files to 
      # upload instead of searching the assets directory.
      # config.manifest = true
      #
      # Fail silently.  Useful for environments such as Heroku
      # config.fail_silently = true
    end
  end
end
