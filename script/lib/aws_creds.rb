require 'rubygems'
require 'aws-sdk-v1'
require 'yaml'
require 'erb'
require 'fileutils'

module AWSCredential
  class Manager

    CRED_STORE_FILE_NAME = "aws-creds"
    CRED_STORE_BUCKET_PREFIX = "chronus-mentor-ks"

    DEFAULT_USER = "dev"
    DEFAULT_USER_CRED_DIR = "#{Dir.home}/#{CRED_STORE_BUCKET_PREFIX}"

    DEFAULT_USER_ENV_NAME = "AWS_DEPLOY_USER"
    DEFAULT_USER_CRED_DIR_ENV_NAME = "AWS_DEPLOY_USER_CRED_DIR"

    CREDS_TYPE_ACCESS_KEYS = "access-keys" # aws access keys
    CREDS_TYPE_ENV_CREDS = "env-creds" # application config variables which need to be modeled as environment variables.
    CREDS_TYPE_PROD_API_ACCESS_KEYS = "prod-api-access-keys" # aws access keys which has access only to aws product api service

    DEPLOYMENT_ENVS = ["staging", "production", "demo", "standby", "development", "test", "performance", "opstesting","scanner", "training","releasestaging1","releasestaging2","productioneu","generalelectric", "veteransadmin", "nch"]

    # variable names in RESERVED_ENV_VARS list is used for naming the aws access keys
    RESERVED_ENV_VARS = ['S3_KEY', 'S3_SECRET', 'AWS_PROD_API_KEY', 'AWS_PROD_API_SECRET', 'AWS_ES_ACCESS_KEY', 'AWS_ES_SECRET_KEY']

    attr_accessor :creds_dir
    attr_accessor :user

    def initialize(user = nil, creds_dir = nil)
      init_user(user)
      init_creds(creds_dir)
    end

    #
    # Rotates the access keys for the given user in IAM and credential store.
    #
    def rotate_access_keys(user)

      validate_username(user)

      # Fetch current credential set
      curr_store_credentials = get_store_creds(user, CREDS_TYPE_ACCESS_KEYS)
      iam_credentials = get_iam_access_keys(user)

      return false unless validate_access_keys(curr_store_credentials, iam_credentials)

      # Remove Previous key from iam

      previous_cred = curr_store_credentials.delete "Previous"
      return false unless remove_iam_access_key(user, previous_cred["AWSAccessKeyId"])

      # Copy Current key as Previous cred
      current_cred = curr_store_credentials.delete "Current"
      new_store_credentials = {}
      new_store_credentials["Previous"] = current_cred

      # Generate new key from iam and copy as Current cred
      new_cred = new_iam_access_key(user)
      new_store_credentials["Current"] = new_cred

      # Save the rotated key set
      put_store_creds(user, CREDS_TYPE_ACCESS_KEYS, new_store_credentials)

      puts "Credentials for #{user} successfully rotated"
      return true
    end

    #
    # Fetches the current access key of the given user
    #
    def get_access_keys(user)
      validate_username(user)
      get_store_creds(user, CREDS_TYPE_ACCESS_KEYS)["Current"]
    end

    #
    # Fetches the current access key which can be used with AWS product API. Currently IAM is not supported with AWS product API.
    # This access key is actually the access key of a separate aws account(opseng@chronus.com) subscribed only to AWS Product API service.
    # Hence treating it separately. This is a temporary HACK till the IAM support is available.
    #
    def get_aws_prod_api_creds(user)
      validate_username(user)
      get_store_creds(user, CREDS_TYPE_PROD_API_ACCESS_KEYS)["Current"]
    end

    #
    # Stores the value of access key which can be used with AWS product API. Currently IAM is not supported with AWS product API.
    # Hence we have created a separate AWS account which was subscribed only to AWS Product API service . This is a temporary HACK
    # till the IAM support is available. The creds is stored in the root level of bucket used for storing app credentials.
    #
    def put_aws_prod_api_creds(user, credential_list)
      put_store_creds(user, CREDS_TYPE_PROD_API_ACCESS_KEYS, credential_list)
    end

    #
    # Updates the local credentials store (directory) of the current user with access keys from remote credential store (s3).
    #
    def sync_self_access_keys
      sync_user_access_keys(@user, @creds_dir)
    end

    #
    # Updates the local credentials store (directory) of the given user with access keys from remote credential store (s3).
    #
    def sync_user_access_keys(user, local_cred_dir)

      validate_username(user)

      raise "Credential directory : #{local_cred_dir} : is not a directory or doesn't exist" unless Dir.exist?(local_cred_dir)
      archive_dir = "#{local_cred_dir}/.archive"
      Dir.mkdir(archive_dir) unless Dir.exist?(archive_dir)

      # Fetch current credential set
      curr_store_credentials = get_store_creds(user, CREDS_TYPE_ACCESS_KEYS)
      iam_credentials = get_iam_access_keys(user)

      raise "Credential set is not valid in IAM/credential store." unless validate_access_keys(curr_store_credentials, iam_credentials)

      # Backup credential set of local directory
      ts = curr_ts
      FileUtils.mv("#{local_cred_dir}/prev-aws-creds", "#{archive_dir}/prev-aws-creds.#{ts}") if File.exist?("#{local_cred_dir}/prev-aws-creds")
      FileUtils.mv("#{local_cred_dir}/curr-aws-creds", "#{archive_dir}/curr-aws-creds.#{ts}") if File.exist?("#{local_cred_dir}/curr-aws-creds")

      save_cred_to_file(curr_store_credentials["Previous"], "#{local_cred_dir}/prev-aws-creds")
      save_cred_to_file(curr_store_credentials["Current"], "#{local_cred_dir}/curr-aws-creds")

      # Reinitialize connection to store using the new credentials if the target user is same as current user
      init_cred_store_conn if user == @user

      puts "Credentials successfully synchronized at #{local_cred_dir}"
    end

    #
    # Initializes access keys for the given user in IAM and credential store.
    #
    # NOTE : Should be used only when the access keys are lost or when a new application user is created.
    #  This will erase the current values in credential store.
    #
    def bootstrap_access_keys(user)

      validate_username(user)

      credential_list = {}

      iam_credentials = get_iam_access_keys(user)

      unless iam_credentials.empty?
        puts "The below credentials still exist in IAM. Remove them using remove_iam_access_key(user, key) and re-run bootstrap_creds"
        puts "#{iam_credentials}"
        return credential_list
      end

      prev_cred = new_iam_access_key(user)
      return if prev_cred.empty?
      cur_cred = new_iam_access_key(user)
      return if cur_cred.empty?

      credential_list["Previous"] = prev_cred
      credential_list["Current"] = cur_cred

      put_store_creds(user, CREDS_TYPE_ACCESS_KEYS, credential_list)
      return credential_list
    end

    #
    # Removes the access key of the given user from IAM.
    #
    # Sucessfull removal will return empty string.
    #
    def remove_iam_access_key(user, key)
      validate_username(user)
      iam = AWS::IAM::Client.new
      begin
        iam.delete_access_key(:user_name => user, access_key_id: key)
      rescue AWS::IAM::Errors => e
        raise "Error: #{e.message}"
      end
      return true
    end

    #
    # Validates the given user name.
    #
    def validate_username(user)
      extract_user_prefix(user)
      extract_user_suffix(user)
      return true
    end

    #
    # Add the given config variable along with its value to the user's deployment environment.
    # Note : deployment environment is inferred from the user suffix.
    #
    def add_env_var(user, var_name, value='')
      validate_username(user)
      validate_env_vars(var_name)
      env_creds = get_store_creds(user, CREDS_TYPE_ENV_CREDS)
      env_creds[var_name] = value
      put_store_creds(user, CREDS_TYPE_ENV_CREDS, env_creds)
    end

    #
    # Get the value of the given config variable.
    #
    def get_env_var(user, var_name)
      validate_username(user)
      env_creds = list_env_vars(user)
      return env_creds[var_name]
    end

    #
    # Remove the value of the given config variable.
    #
    def remove_env_var(user, var_name)
      validate_username(user)
      validate_env_vars(var_name)
      env_creds = get_store_creds(user, CREDS_TYPE_ENV_CREDS)
      deleted = env_creds.delete var_name
      put_store_creds(user, CREDS_TYPE_ENV_CREDS, env_creds) unless deleted.nil?
      return !deleted.nil?
    end


    def list_dev_keys
      dev_env_list = {}
      dev_env_list['S3_KEY'] = @dev_aws_access_key
      dev_env_list['S3_SECRET'] = @dev_aws_secret_access_key
      dev_env_list
    end

    #
    # Get the list of config variables for the given user's deployment environment
    #
    def list_env_vars(user)
      validate_username(user)
      env_list = get_store_creds(user, CREDS_TYPE_ENV_CREDS)

      s3_env_list = {}

      s3_env_list.merge!(get_s3_access_keys_hash(user)) if user.include?("development")
      s3_env_list.merge!(get_prod_api_access_keys_hash(user))
      #s3_env_list.merge!(get_aws_es_access_keys_hash(user))

      env_list.merge(s3_env_list)
    end

    def get_s3_access_keys_hash(user)
      access_key = get_access_keys(user)
      access_keys_hash = {}
      unless access_key.nil? || access_key.empty?
        access_keys_hash['S3_KEY'] = access_key['AWSAccessKeyId']
        access_keys_hash['S3_SECRET'] = access_key['AWSSecretKey']
      end
      access_keys_hash
    end

    def get_prod_api_access_keys_hash(user)
      prod_api_access_key = get_aws_prod_api_creds(user)
      prod_api_access_keys_hash = {}
      unless prod_api_access_key.nil? || prod_api_access_key.empty?
        prod_api_access_keys_hash['AWS_PROD_API_KEY'] = prod_api_access_key['AWSAccessKeyId']
        prod_api_access_keys_hash['AWS_PROD_API_SECRET'] = prod_api_access_key['AWSSecretKey']
      end
      prod_api_access_keys_hash
    end

    # Elastic search user is get from extracting the environment from app_user.
    def get_aws_es_access_keys_hash(user)
      aws_es_access_key = get_access_keys(get_aws_es_user(user))
      aws_es_access_keys_hash = {}
      unless aws_es_access_key.nil? || aws_es_access_key.empty?
        aws_es_access_keys_hash['AWS_ES_ACCESS_KEY'] = aws_es_access_key['AWSAccessKeyId']
        aws_es_access_keys_hash['AWS_ES_SECRET_KEY'] = aws_es_access_key['AWSSecretKey']
      end
      aws_es_access_keys_hash
    end

    def push_env_vars(user, env_file)
      validate_username(user)
      env_list = read_env_list(env_file)
      put_store_creds(user, CREDS_TYPE_ENV_CREDS, env_list)
    end

    def pull_env_vars(user, env_file)
      validate_username(user)
      env_list = list_env_vars(user)
      write_env_list(env_file, env_list)
    end

    private

    attr_accessor :dev_aws_access_key
    attr_accessor :dev_aws_secret_access_key

    def validate_creds_dir(creds_dir)
      raise "Credential directory : #{creds_dir} : is not a directory or doesn't exist" unless Dir.exist?(creds_dir)

      raise "Specified Credential directory doesn't contain expected file : #{creds_dir}/prev-aws-creds" unless File.exist?("#{creds_dir}/prev-aws-creds")
      raise "Specified Credential directory doesn't contain expected file : #{creds_dir}/curr-aws-creds" unless File.exist?("#{creds_dir}/curr-aws-creds")

      archive_dir = "#{creds_dir}/.archive"
      Dir.mkdir(archive_dir) unless Dir.exist?(archive_dir)
    end

    def load_keystore_creds(creds_file)
      @dev_aws_access_key, @dev_aws_secret_access_key = nil, nil
      creds=File.open(creds_file).read
      creds.gsub!(/\r\n?/,"\n")
      creds.each_line do |line|
        credkey, credval = line.split '='
        @dev_aws_access_key = credval.chomp if credkey == "AWSAccessKeyId"
        @dev_aws_secret_access_key = credval.chomp if credkey == "AWSSecretKey"
      end

      raise "Credential file #{creds_file} didn't contain valid value for AWSAccessKeyId" if @dev_aws_access_key.nil? || @dev_aws_access_key.empty?
      raise "Credential file #{creds_file} didn't contain valid value for AWSSecretKey" if @dev_aws_secret_access_key.nil? || @dev_aws_secret_access_key.empty?

      [@dev_aws_access_key, @dev_aws_secret_access_key]
    end

    def init_user(user)
      unless user
        user = ENV[DEFAULT_USER_ENV_NAME] if ENV[DEFAULT_USER_ENV_NAME]
        user = DEFAULT_USER if user.nil? || user.empty?
      end
      validate_username(user)
      @user = user
    end

    def init_cred_store_conn
      dev_aws_access_key, dev_aws_secret_access_key = load_keystore_creds("#{@creds_dir}/curr-aws-creds")
      AWS.config({
      :access_key_id => dev_aws_access_key,
      :secret_access_key => dev_aws_secret_access_key,
      :region => "us-east-1",
      :server_side_encryption => :aes256
      })

      return
    end

    def init_creds(creds_dir)
      unless creds_dir
        creds_dir = ENV[DEFAULT_USER_CRED_DIR_ENV_NAME] if ENV[DEFAULT_USER_CRED_DIR_ENV_NAME]
        creds_dir = "#{DEFAULT_USER_CRED_DIR}/#{@user}" if creds_dir.nil? || creds_dir.empty?
      end
      validate_creds_dir(creds_dir)
      @creds_dir = creds_dir
      init_cred_store_conn
      @s3 = AWS::S3.new
    end

    #
    # Fetches credential info (keys along with status) for the given user from IAM.
    #
    # Sample success output =>
    #   AKIABBBBWXUCNUOZFP3A
    #   Active
    #   AKIAIO2HSSSS6JMSR7VQ
    #   Active
    #   IsTruncated: false
    #
    # In the case where the user doesn't have any credentials output will be below
    #   IsTruncated: false
    #
    def get_iam_access_keys(user)
      iam = AWS::IAM::Client.new
      begin
        access_key_metadata = iam.list_access_keys(user_name: user)[:access_key_metadata]
      rescue AWS::IAM::Errors => e
        raise "Error: #{e.message}"
      end
      creds = {}
      access_key_metadata.each{|metadata| creds[metadata[:access_key_id]] = metadata[:status]}
      return creds
    end

    #
    # Creates a new credential (access key and secret key) for the given user in IAM.
    #
    # Sample success output =>
    #   AKIAJQNFFFF3SN6RCJ4Q
    #   2wh2M1mQQXK1Kh1234sYv7UUPK4y5678gXJS0FfA
    #
    def new_iam_access_key(user)
      iam = AWS::IAM::Client.new
      begin
        creds = iam.create_access_key(:user_name => user)[:access_key]
      rescue AWS::IAM::Errors => e
        raise "Error: #{e.message}"
      end
      new_creds = {"AWSAccessKeyId" => creds[:access_key_id], "AWSSecretKey" => creds[:secret_access_key], "Status" => creds[:status]}
      return new_creds
    end

    #
    # Validates whether the given credential pair (IAM and credential store) are in sync.
    #
    def validate_access_key(cred, cred_name, iam_cred_list)
      cred_valid = false
      if cred
        cred_access_id = cred['AWSAccessKeyId']
        puts "AWSAccessKeyId of #{cred_name} credentials is missing from key store" unless cred_access_id
        cred_secret_key = cred['AWSSecretKey']
        puts "AWSSecretKey of #{cred_name} credentials is missing from key store" unless cred_secret_key
        cred_status = cred['Status']
        puts "Status of #{cred_name} credentials is missing from key store" unless cred_status
        if cred_access_id && cred_secret_key && cred_status
          iam_cred_status = iam_cred_list[cred_access_id]
          if iam_cred_status
            if iam_cred_status != cred_status
              puts "Status value mismatch for AWSAccessKeyId : #{cred_access_id} {cred store : #{cred_status}, iam : #{iam_cred_status}}"
            else
              cred_valid = true
            end
          else
            puts "AWSAccessKeyId : #{cred_access_id} of #{cred_name} credentials is missing from AWS IAM"
          end
        end
      else
        puts "#{cred_name} credentials is missing from key store"
      end
      return cred_valid
    end

    #
    # Validates whether the credential list in IAM and credential store are in sync.
    #
    def validate_access_keys(key_store_creds, iam_creds)
      prev_aws_credential_key = key_store_creds["Previous"]
      curr_aws_credential_key = key_store_creds["Current"]
      return validate_access_key(prev_aws_credential_key, "Previous", iam_creds) && validate_access_key(curr_aws_credential_key, "Current", iam_creds)
    end

    #
    # Exracts the prefix of the given user.
    #
    def extract_user_prefix(user)
      user_parts = user.split "_"
      user_prefix = user_parts.first
      valid_user_name_prefixes = ["admin", "dev", "app", "ops", "es", "ubuntu"]
      unless valid_user_name_prefixes.include?(user_prefix)
        raise "Invalid user name : #{user}. user name must start with one of the prefixes #{valid_user_name_prefixes}"
      end

      return user_prefix
    end

    #
    # Exracts the deploy environment suffix if present in the given application user name.
    #
    def extract_user_suffix(user)
      valid_deployment_envs = DEPLOYMENT_ENVS
      valid_app_user_suffixes = valid_deployment_envs.collect {|x| "_" + x}
      user_prefix = extract_user_prefix(user)
      user_suffix = ""
      raise "Invalid user name : #{user}. user name must not end with _" if user.end_with?("_")
      user_suffix = case user_prefix
        when "app"
          validate_and_extract_common_user_suffix(user, valid_deployment_envs, valid_app_user_suffixes, "application")
        when "es"
          validate_and_extract_common_user_suffix(user, valid_deployment_envs, valid_app_user_suffixes, "elasticsearch")
        else
          validate_and_extract_common_user_suffix(user, valid_deployment_envs, valid_app_user_suffixes)
        end
      return user_suffix
    end

    def validate_and_extract_common_user_suffix(user, valid_deployment_envs, valid_app_user_suffixes, user_type=nil)
      # sample user: dev_staging, app_staging, es_staging
      user_parts = user.split "_"
      user_name_str = user_type ? "#{user_type} user name": "user name"
      unless user_parts.size < 2
        user_suffix = user_parts.last
        unless valid_deployment_envs.include?(user_suffix)
          raise "Invalid #{user_name_str} : \"#{user}\".#{user_name_str} must end with one of the suffixes : #{valid_app_user_suffixes}"
        end
      end
      user_suffix
    end

    #
    # Derives the bucket name which holds the credentials of the given user
    #
    def cred_store_bucket_name(user)
      "#{CRED_STORE_BUCKET_PREFIX}-#{extract_user_prefix(user)}"
    end

    #
    # Derives the credential file name of given user
    #
    def cred_store_file_name(user, creds_type)
      user_deploy_env = extract_user_suffix(user)

      case creds_type
      when CREDS_TYPE_ACCESS_KEYS
        file_name = "aws-creds"
      when CREDS_TYPE_ENV_CREDS
        file_name = "env-creds"
      when CREDS_TYPE_PROD_API_ACCESS_KEYS
        file_name = "aws_prod_api_aws-creds"
      else
        raise "Invalid credential type : #{creds_type}"
      end

      path_name = file_name
      unless creds_type == CREDS_TYPE_PROD_API_ACCESS_KEYS
        path_name = user_deploy_env.empty? ? "#{user}/#{file_name}" : "#{user_deploy_env}/#{user}/#{file_name}" unless creds_type == CREDS_TYPE_PROD_API_ACCESS_KEYS
      end

      return path_name
    end

    #
    # Fetches credential list info (keys, secret access key and status) for the given user from credential store.
    #
    # Sample output =>
    #   {"Previous"=>{"AWSAccessKeyId"=>"AKIAJBIUPLEB7VXXSYRA", "AWSSecretKey"=>"MWPD6WrnhOovEcAqmPZ5GG3MB6PoxvDilOFAATrj", "Status"=>"Active"},
    #     "Current"=>{"AWSAccessKeyId"=>"AKIAJ5RXXXVDLGJY75KQ", "AWSSecretKey"=>"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", "Status"=>"Active"}}
    #

    def get_s3_object(bucket_name, object_key)
      @s3.buckets[bucket_name].objects[object_key]
    end

    def get_store_creds(user, creds_type)
      aws_credentials_list = {}
      begin
        aws_credentials_data = get_s3_object(cred_store_bucket_name(user),cred_store_file_name(user, creds_type)).read
        aws_credentials_list = YAML.load(aws_credentials_data)
      rescue AWS::S3::Errors => e
      end
      return aws_credentials_list
    end

    #
    # Saves the specified credentials for the given user in credential store.
    #
    # NOTE : This will erase the current values in credential store.
    #
    def put_store_creds(user, creds_type, credential_list)
      get_s3_object(cred_store_bucket_name(user),cred_store_file_name(user, creds_type)).write(credential_list.to_yaml)
    end

    def save_cred_to_file(cred, cred_file_name)
      File.open(cred_file_name, 'w') do |f|
        cred.each do |k,v|
          f.puts "#{k}=#{v}" unless k == "Status"
        end
      end
      puts "Creds saved to #{cred_file_name}"
    end

    def curr_ts
      Time.now.strftime('%Y_%m_%d-%H_%M_%S')
    end

    # Validate whether the variable name is one of those reserved variables.
    # variable names in RESERVED_ENV_VARS list is used for naming the aws access keys
    def validate_env_vars(var_name)
      raise "#{var_name} is a reserved variable" if RESERVED_ENV_VARS.include?(var_name)
    end

    # Read the content of the specified file in .env format into hash.
    # .env format is a series of name=value pairs separated by newlines
    def read_env_list(env_file)
      File.read(env_file).split("\n").inject({}) do |hash, line|
        if line =~ /\A([A-Za-z0-9_]+)=(.*)\z/
          key, value = $1, $2
          if RESERVED_ENV_VARS.include?(key)
            puts "#{key} is a reserved variable. Ignoring"
          else
            hash[key] = value
          end
        end
        hash
      end
      rescue
      {}
    end

    # Writes a hash to the specified file in .env format.
    # .env format is a series of name=value pairs separated by newlines
    def write_env_list(env_file, env_list)
      File.open(env_file, "w") do |file|
        env_list.keys.sort.each do |key|
          file.puts "#{key}=#{env_list[key]}"
        end
      end
    end

    def get_aws_es_user(user)
      user_suffix = extract_user_suffix(user)
      "es_#{user_suffix}"
    end

  end
end