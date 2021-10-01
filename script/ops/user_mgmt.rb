require 'rubygems'

require 'fileutils'
require 'aws-sdk-v1'
require 'yaml'
require_relative './user_mgmt_config.rb'
require_relative './../../lib/ops/user_mgmt_helpers.rb'

include CmIamConfig

class UserMgmt

  def initialize(user_name,access_key,secret_key)
    username_prefix = user_name.split("_").first
    convention =  USERNAME_CONVENTIONS[username_prefix]

    @iam_group_name = convention[:iam_group]
    @user_name = user_name
    @ubuntu_group = convention[:gateway_ubuntu_group]
    @env_ubuntu_group = convention[:env_ubuntu_group]

    AWS.config({
      :access_key_id => access_key,
      :secret_access_key => secret_key,
      :region => DEFAULT_AWS_REGION
    })

    @iam = AWS::IAM.new
    @groups = @iam.groups
    @users  = @iam.users

    @s3 = AWS::S3.new
    @creds_bucket_name = "#{CRED_STORE_BUCKET_PREFIX}-#{convention[:iam_creds_suffix]}"
    @user_creds_folder = "#{convention[:iam_creds_prefix]}_#{CREDS_DIR_TAG}/#{@user_name}/"

    rescue Exception => e
      error_log "UserMgmt initialize failed: #{e.message}"
      abort
  end

  def add_user(gw_env,envs,ssh_username)
    status_iam_user_created  = false
    status_gateway_user_created  = false 
    status_iam_user_created = add_iam_user

    # Provision on gateway only if everything else was successful
    status_gateway_user_created = add_gateway_user(gw_env)

  rescue Exception => e
    error_log "addUser failed with error #{e.message}"
    info_log "Rolling back.. "

    remove_iam_user if status_iam_user_created
    remove_gateway_user(gw_env) if status_gateway_user_created
  end


  def remove_user_on_local_machine
    execute_cmd "userdel -f #{@user_name} && rm -rf /home/#{@user_name}"
  end


  def add_user_on_local_machine
    # If the user doesn't exist already, create him
    execute_cmd "useradd #{@user_name} -m -s /bin/bash -g #{@ubuntu_group}"
  end

  def remove_gateway_user(env)

    # To remove the user
    remove_user_on_local_machine
    success_log "User account #{@user_name} successfully deleted on the gateway"

    # To remove the key from s3 creds folder
    obj_name = "env-gateway-#{env}"
    remove_s3_obj_for_user obj_name

    success_log "Successfully deleted the environment ssh key from the users creds S3 folder"

  rescue 
    error_log "Removing Gateway User failed"
  end


  def disable_gateway_user 

    authorized_keys_path = "/home/#{@user_name}/.ssh/authorized_keys"
    FileUtils.rm authorized_keys_path
    success_log "Successfully disabled the ssh access of the user"

  rescue Exception => e
    error_log " disable_gateway_user failed: #{e.message}"
  end

  def add_gateway_user(env)
    begin
      add_user_on_local_machine
      success_log "User Account successfully created on the gateway"
      rescue Exception => e
        error_log "User account creation on the gateway failed"
      raise e
    end
    begin
      laydown_deploy_dependencies(env)
    rescue Exception => e
      error_log "Laying down deploy dependecies failed: #{e.message}"
      remove_user_on_local_machine
      error_log "Removed the user account #{@user_name} on the gateway"
      raise e
    end
    return true
  end

 def sync_user

  begin
    # Laydown dev creds 
    laydown_dev_creds

    # Laydown keypair to access the production servers
    laydown_prod_keys

    # copy the google authenticator config file
    configure_google_authenticator 
  rescue Exception => e
    error_log "Sync user failed with error: #{e.message}"
    raise e
  end
 end

  # If the user doesn't exist, the execute cmds raises  exceptions. Deciding based on that!
  def check_gateway_user_status
    begin
      cmd = "id -u #{@user_name}"
      execute_cmd cmd
      success_log "User Account exists on Gateway"
    rescue 
      error_log "User Account doesnt exist on the Gateway" 
      return
    end
    begin
      authorized_keys_path = "/home/#{@user_name}/.ssh/authorized_keys"
      cmd = "ls -l #{authorized_keys_path}"
      execute_cmd cmd
      success_log "SSH Access is enabled on Gateway"
    rescue
      error_log "SSH Access is disabled on the Gateway" 
    end
  end

  def check_user(envs,ssh_username)
    check_iam_user_status
    check_gateway_user_status
  end

  def check_iam_user_status
    if @users.map(&:name).include? @user_name 
      success_log "IAM user #{@user_name} exists"
    else
      error_log "IAM user #{@user_name} doesnt exist"
    end
  rescue Exception => e
    error_log "check_iam_user_status failed: #{e.message}"
  end


  def provision_ssh_access_on_local_machine
    # Create a new keypair for the user
    keypair = create_new_ssh_keypair("#{@user_name}")

    #Put this keypair in the authorized keys for that user.
    add_to_authorized_keys(keypair)
    keypair
  end

  #Making the access keys inactive
  def disable_iam_user 
    access_keys = @iam.users[@user_name].access_keys
    access_keys.each do |key|
      key.deactivate!
    end
    success_log "Access keys inactived for the user #{@user_name}"
    rescue Exception => e
      error_log " disable_iam_user failed: #{e.message}"
      raise e
  end

  def disable_user(gw_env,envs,ssh_username)
    disable_iam_user 
    disable_gateway_user
    success_log "Disabled IAM access and SSH access in gateway"
    rescue Exception => e
      error_log "disable_user failed: #{e.message}"
    raise e
  end

  def remove_user(gw_env,envs,ssh_username)
    remove_gateway_user gw_env
    remove_iam_user
    success_log "Removed IAM user and removed user account #{@user_name} on all the environments"
    rescue Exception => e
      error_log "Removing User failed"
    raise e
  end

  # Creates if the iam user doesn't exist. Returns true on success
  def add_iam_user

    begin
      # Create the IAM user
      iam_user = @iam.users.create(@user_name)
      success_log "Successfully created IAM user: #{@user_name}"
    rescue Exception => e
      error_log "IAM User Creation failed: #{e.message}"
      raise e
    end

    status_s3_folders_created_for_user = false

    begin
      # Get the group
      iam_group = @groups[@iam_group_name]
      # Add user to the group
      iam_group.users.add(iam_user)

      success_log "Successfully Added the user to #{@iam_group_name} group"

      # Create s3 folders for the user, where his ssh keys are stored 
      status_s3_folders_created_for_user = create_s3_folders_for_user

      # Give permissions for the user to read his gateway creds bucket
      attach_required_policies_to_user

      # create aws creds for the user
      key = create_aws_access_keys

      access_key_data = "User '#{@user_name}' successfully created. Please note down the AWS access keys
      AWS_ACCESS_KEY: #{key.id}
      AWS_SECRET_KEY: #{key.secret}
      "
      iam_keys_s3obj = AWS::S3.new.buckets[TEMP_S3_BUCKET_FOR_GATEWAY_USER_KEYS].objects["tmp/gateway_keys/#{@user_name}"]
      iam_keys_s3obj.write(access_key_data, :server_side_encryption => :aes256)
      info_log "Access Keys URL: #{iam_keys_s3obj.url_for(:read, :expires => 3600, :signature_version => :v4)}"

    rescue Exception => e
      error_log "add_iam_user failed with reason: #{e.message}"
      remove_s3_folders_for_user if status_s3_folders_created_for_user
      iam_user.delete!
      error_log "Removed the IAM user #{@user_name}"
      raise e
    end
    return true
  end

  def remove_iam_user
    user = AWS::IAM::User.new(@user_name)
    remove_s3_folders_for_user
    user.delete!
    iam_keys_s3obj = AWS::S3.new.buckets[TEMP_S3_BUCKET_FOR_GATEWAY_USER_KEYS].objects["tmp/gateway_keys/#{@user_name}"]
    iam_keys_s3obj.delete if iam_keys_s3obj.exists?
    success_log "IAM User: #{@user_name} successfully deleted"
  rescue Exception => e
    error_log "Removing IAM user failed: #{e.message}"
    raise e
  end

  # This function has been changed such that it accepts folder name to which it will lay down the ssh keys.
  # It is the caller's responsibility to change the owner of the folder if required
  def laydown_user_env_keys(local_env_keys_folder)
    s3_folder_name = "#{@user_creds_folder}#{USER_ENV_KEYS_S3_FOLDER_NAME}/"

    bucket = @s3.buckets[@creds_bucket_name]
    objects_collection = bucket.objects.with_prefix("#{s3_folder_name}")

    FileUtils.rm_rf local_env_keys_folder
    FileUtils.mkdir_p local_env_keys_folder

    # Read the env keys S3 folder of the user and laydown in the home directory!
    objects_collection.each do |obj|
      # Get the file name. The key has the full object path
      file_name = obj.key.split("/").last
      # We get the foldername as one of the objects. We should skip it!
      next if file_name == USER_ENV_KEYS_S3_FOLDER_NAME

      file_path = "#{local_env_keys_folder}/#{file_name}"
      file_content = obj.read

      File.open(file_path, "w", 0600) { |io| io.write(file_content) }
    end
    success_log "Successfully laid down ssh keys of all the environments for the user: #{@user_name} in #{local_env_keys_folder}"
  rescue Exception => e
    error_log "laydown_user_env_keys failed: #{e.message}"
    raise e
  end

  private
  def configure_google_authenticator
    # Copy the google-authenticator file from deploy user
    deploy_ga_file = "/home/#{GATEWAY_DEPLOY_USER}/#{GOOGLE_AUTHENTICATOR_CONFIG_FILE}" 
    if !File.exist?(deploy_ga_file)
      info_log "Skipping Google Authenticator configuration as it is not enabled for deploy user"
      return
    end
    user_ga_file = "/home/#{@user_name}/#{GOOGLE_AUTHENTICATOR_CONFIG_FILE}"
    copy_file_and_change_ownership(deploy_ga_file, user_ga_file) 
    success_log "Updated Google Authenticator Config for the user: #{@user_name}"
  end

  def delete_s3_obj(obj_name)
    bucket = @s3.buckets[@creds_bucket_name]
    objects_collection = bucket.objects
    obj = objects_collection[obj_name]
    obj.delete
  end

  def remove_s3_obj_for_user(obj_name)
    abs_obj_path = "#{@user_creds_folder}#{obj_name}"
    delete_s3_obj abs_obj_path
  rescue Exception => e
    error_log "remove_s3_obj_for_user failed: #{e.message}"
    raise e
  end

  def remove_s3_folders_for_user
    abs_obj_path = @user_creds_folder

    # Deleting all the objects for this user!
    # Deleting the folder isn't removing all the files inside it. So, deleting using delete_all!
    bucket = @s3.buckets[@creds_bucket_name]
    objects_collection = bucket.objects.with_prefix(abs_obj_path)
    objects_collection.delete_all

  rescue Exception => e
    error_log "remove_s3_folders_for_user failed: #{e.message}"
    raise e
  end

  def create_aws_access_keys
    access_key = @iam.users[@user_name].access_keys.create
    success_log "Successfully created AWS keys"
    return access_key
  end


  def attach_required_policies_to_user
    user = @iam.users[@user_name]

    # policy to list the required chronus-mentor-ks-* bucket
    list_bucket_policy = AWS::IAM::Policy.new
    list_bucket_policy.allow(
      :actions => ['s3:ListBucket'],
      :resources => "arn:aws:s3:::#{@creds_bucket_name}"
    )
    user.policies['list_bucket'] = list_bucket_policy


    # policy to read the gateway keys
    read_gateway_keys_policy = AWS::IAM::Policy.new
    read_gateway_keys_policy.allow(
      :actions => ["s3:GetObject","s3:GetObjectAcl","s3:GetObjectVersion","s3:GetObjectVersionAcl"],
      :resources => "arn:aws:s3:::#{@creds_bucket_name}/#{@user_creds_folder}*"
    )

    user.policies['read_gateway_keys'] = read_gateway_keys_policy

    success_log "Successfully attached required policies to the user #{@user_name}"
  end

  


  # This function reads all the  dev creds for all the required environments
  def read_required_creds
    # Read the dev creds for all the environments and put it in the home directory 
    bucket_name = "#{CRED_STORE_BUCKET_PREFIX}-dev"
    bucket = @s3.buckets[bucket_name]
    creds = Hash.new
    DEPLOYMENT_ENVS.each do |env|
      env_user = "dev_#{env}"
      obj_path = "#{env}/#{env_user}/aws-creds"
      obj = bucket.objects[obj_path]
      creds["#{env}"] = YAML.load(obj.read)
    end
    return creds
  end

  def change_dir_ownership_to_user(dir)
    FileUtils.chown_R @user_name, @ubuntu_group, dir
  end

  def laydown_app_keys
    # We need to laydown the ssh key of the user account on the production servers. We are placing root account as of now
    bucket_name = "#{CRED_STORE_BUCKET_PREFIX}-app"
    bucket = @s3.buckets[bucket_name]

    app_keys_folder = "/home/#{@user_name}/#{APP_SSH_KEY_LOCAL_FOLDER_NAME}"
    FileUtils.mkdir app_keys_folder unless File.directory?(app_keys_folder)

    envs = parse_deploy_yml
    envs.each_pair do |env, env_params|
      begin
        obj_name = app_sshkey_S3_path env 
        obj = bucket.objects[obj_name]
        app_key = obj.read

        # laydown the app env key 
        key_file_name = obj_name.split("/").last
        final_path = "#{app_keys_folder}/#{key_file_name}"
        File.open(final_path, "w", 0600) { |io| io.write(app_key) }
        FileUtils.chown @user_name,@ubuntu_group,final_path
      rescue Exception => e
        error_log "Laying down app ssh key failed for #{env.upcase} with reason: #{e.message}"
        raise e
      end
    end
    success_log "Successfully laid down all app-ssh-keys"
  end

  
  # Lays down the keypair required for the gateway to access production servers while deploying
  def laydown_prod_keys
    laydown_app_keys

    local_env_keys_folder = "/home/#{@user_name}/#{USER_ENV_KEYS_LOCAL_FOLDER_NAME}"
    laydown_user_env_keys(local_env_keys_folder)
    # Change the permissions of the env ssh keys folder
    FileUtils.chown_R @user_name,@ubuntu_group,local_env_keys_folder
  end


  def laydown_dev_creds

    # Read the required creds
    creds = read_required_creds

    # Laydown the creds in the home/mentorks folder"

    creds_dir = "/home/#{@user_name}/chronus-mentor-ks"
    
    # Delete and recreate the creds dir 
    FileUtils.rm_rf creds_dir
    FileUtils.mkdir creds_dir


    creds.each  do |env, dev_creds|
      env_creds_dir = "#{creds_dir}/dev_#{env}"

      FileUtils.mkdir(env_creds_dir)


      # create the curr-aws-creds
      curr_creds = dev_creds['Current']
      final_path = "#{env_creds_dir}/#{CURR_AWS_CREDS_FILENAME}"
      str = "AWSAccessKeyId=#{curr_creds['AWSAccessKeyId']}\nAWSSecretKey=#{curr_creds['AWSSecretKey']}"
      File.open(final_path, "w") { |file| file.write(str) }

      # create the prev-aws-creds
      prev_creds = dev_creds['Previous']
      final_path = "#{env_creds_dir}/#{PREV_AWS_CREDS_FILENAME}"
      str = "AWSAccessKeyId=#{prev_creds['AWSAccessKeyId']}\nAWSSecretKey=#{prev_creds['AWSSecretKey']}"
      File.open(final_path, "w") { |file| file.write(str) }
      change_dir_ownership_to_user env_creds_dir
    end
    success_log "Successfully laid down dev proxy aws creds on the home folder"
  end


  def iam_group_exists?(gname)
    names = @groups.map(&:name)
    names.include? gname 
  end


  # pushes priv key to the users cred dir
  def push_ssh_key_to_users_creds_dir(keypair,obj_name,options={})

    abs_obj_path = "#{@user_creds_folder}#{obj_name}"
    bucket = @s3.buckets[@creds_bucket_name]
    objects_collection = bucket.objects

    privkey = keypair['private_key']
    objects_collection.create(abs_obj_path,privkey,options)

    success_log "Pushed the ssh keys to the user's creds folder"
  rescue Exception => e
    error_log "push_ssh_key_to_users_creds_dir failed: #{e.message}"
  end

  # Creates s3 folders for the user if they do not already exist
  # Returns true on success
  def create_s3_folders_for_user

    bucket = @s3.buckets[@creds_bucket_name]
    objects_collection = bucket.objects
    obj = objects_collection[@user_creds_folder]

    if obj.exists?
      info_log "S3 folders for the user already exist"
      return true
    end

    # Create the folder if not already existing
    objects_collection.create(@user_creds_folder,"")
    success_log "S3 Folders successfully created for #{@user_name}"
    return true

  rescue Exception => e
    error_log "Creation of S3 folders for the user failed with reason: #{e.message}"
    raise e
  end


  # Returns the sequence of comamnds to be executed - to put the pubkey in the authorized keys of the user
  def add_to_authorized_keys(keypair)
    public_key = keypair['public_key']

    # put the key in the users authorized keys file
    ssh_dir = "/home/#{@user_name}/.ssh"
    authorized_keys_path = "#{ssh_dir}/authorized_keys"

    File.open(authorized_keys_path, "w", 0600) { |io| io.write(public_key) }

    FileUtils.chown @user_name,@ubuntu_group,authorized_keys_path
  end

  def copy_file_and_change_ownership(src,dest)
    FileUtils.cp src,dest
    FileUtils.chown @user_name,@ubuntu_group,dest
  end
  
  def laydown_deploy_dependencies(env) 
    
    # creating the ssh directory for the user
    ssh_dir = "/home/#{@user_name}/.ssh"

    FileUtils.mkdir ssh_dir

    # put the ssh config from deploy user
    copy_file_and_change_ownership "/home/#{GATEWAY_DEPLOY_USER}/.ssh/config","#{ssh_dir}/config"

    # putting the ssh key required for git commands
    copy_file_and_change_ownership "/home/#{GATEWAY_DEPLOY_USER}/.ssh/id_rsa", "/home/#{@user_name}/.ssh"
    FileUtils.chmod 0600, "/home/#{@user_name}/.ssh/id_rsa"

    change_dir_ownership_to_user ssh_dir

    # Cloning the git code
    groups_path = "/home/#{@user_name}/groups"
    git_pull_cmd = "sudo su #{@user_name} -c 'git clone git@github.com:ChronusCorp/ChronusMentor.git #{groups_path}'"

    execute_cmd git_pull_cmd
    # change_dir_ownership_to_user groups_path

    # put down the bashrc and source it from profile 
    copy_file_and_change_ownership "/home/#{GATEWAY_DEPLOY_USER}/.bashrc", "/home/#{@user_name}/.bashrc"
    copy_file_and_change_ownership "/home/#{GATEWAY_DEPLOY_USER}/.profile", "/home/#{@user_name}/.profile"

    # Laydown dev creds 
    laydown_dev_creds

    # Laydown keypair to access the production servers
    laydown_prod_keys

    # copy the google authenticator config file
    configure_google_authenticator

    # Enable ssh access for the user
    keypair = provision_ssh_access_on_local_machine

    # Store the priv key in the user bucket / Replace if they already exist
    obj_name = "#{GATEWAY_ENV_KEYS_S3_FOLDER_NAME}/#{env}-#{GATEWAY_KEYS_SUFFIX}"
    # push the new key to the users creds dir
    push_ssh_key_to_users_creds_dir(keypair,obj_name,:server_side_encryption => :aes256)

    Dir.chdir(groups_path) do 
      system("git init")
      system("git config user.name 'deploy_user'")
      system("git config user.email 'deploy_user@chronus.com'")
    end
  end

end
