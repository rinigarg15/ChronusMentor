require 'aws-sdk-v1'
require 'erb'
require_relative './deployment_constants'
require_relative './deployment_module_helper'
require_relative './deployment_helper'

class DeploymentS3Logs
  include DeploymentConstants
  include DeploymentModuleHelper

  def get_credentials(env_name)
    uploader_config_file = "#{File.dirname(__FILE__)}/deployment_s3_logs.yml"
    yaml_file = File.read(uploader_config_file)
    erb_result = ERB.new(yaml_file).result
    YAML::load(erb_result)[env_name]
  end

  def authenticate_s3(credentials)
    AWS.config(:region => credentials["s3_bucket_region"], :s3_server_side_encryption => :aes256)
  end

  def upload_logs_s3(env_name, timestamp, tag_name)
    destination_file = "logs/#{tag_name}_logs/#{tag_name}-#{env_name}-#{timestamp}.log"
    source_file = DeploymentHelper.get_log_path(env_name, timestamp, tag_name)
    credentials = self.get_credentials(env_name)
    bucket_name = credentials["bucket"]
    retry_when_exception("Failed to upload files to s3. Check /tmp/ folder of the file and upload it manually"){
      self.authenticate_s3(credentials)
      AWS::S3.new.buckets[bucket_name].objects[destination_file].write(:file => File.open(source_file,'r',encoding: "UTF-8"))
    }
  end
end