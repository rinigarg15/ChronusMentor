require File.dirname(__FILE__) +'/ops_common_utils.rb'

def execute_cmd(cmd)
  cmdout = `#{cmd}`
  status = $?.success?
  raise "Error executing #{cmd}: #{status}" unless status
  return cmdout
end


def read_file_content(file_name)
  file_content = File.open(file_name, 'r') { |f| f.read }
  file_content = file_content.chomp if file_content
  return file_content
end


def curr_ts
  Time.now.strftime('%Y_%m_%d-%H_%M_%S')
end


# SSH-Key  functions 
def validate_ssh_private_key(private_key)
  private_key.start_with?("-----BEGIN RSA PRIVATE KEY-----") && private_key.end_with?("-----END RSA PRIVATE KEY-----")
end

def validate_ssh_public_key(public_key, key_name)
  public_key.start_with?("ssh-rsa") && public_key.end_with?(key_name)
end

# Creates a new keypair. Deletes if del is set to 1
def create_new_ssh_keypair(prefix)

  keypair_name = "#{prefix}-#{curr_ts}"

  new_private_key_file = "/tmp/id_key-#{keypair_name}"
  begin
    cmd = "ssh-keygen -q -t rsa -N \"\" -C #{keypair_name} -f #{new_private_key_file} 2>&1"
    execute_cmd(cmd)
    private_key = read_file_content(new_private_key_file)
    public_key = read_file_content("#{new_private_key_file}.pub")
    raise "Contents of keys generated are not as expected" unless validate_ssh_private_key(private_key) && validate_ssh_public_key(public_key, keypair_name)
  ensure
    FileUtils.rm_f(new_private_key_file)
    FileUtils.rm_f("#{new_private_key_file}.pub")
  end

  ssh_keypair_creds = {}
  ssh_keypair_creds["private_key"] = private_key
  ssh_keypair_creds["public_key"] = public_key
  ssh_keypair_creds["keypair_name"] = keypair_name

  return ssh_keypair_creds
end

def parse_deploy_yml
  config_path = File.dirname(__FILE__) +'/../../config/deploy.yml'
   YAML.load_file(config_path).delete_if{|key,value| key == "common"}
end

def app_sshkey_S3_path(env)
  "#{env}/app_#{env}/#{env}-#{APP_SSH_KEY_NAME_SUFFIX}"
end

def get_gateway_env
  read_file_content(GATEWAY_ENV_NAME_FILE)
end


# This function can be used to get the original user when a script is being run with super privileges. This function returns username, groupname
def get_original_user_details
  user_name = ENV['SUDO_USER']
  group_name = `id -gn #{user_name}`.chomp
  return user_name, group_name
end

def parse_aws_details(opts)
  if opts[:aws_key] then access_key=opts[:aws_key] else access_key=ENV['CM_IAM_ACCESS_KEY'] end
  if opts[:aws_secret_key] then secret_key=opts[:aws_secret_key] else secret_key=ENV['CM_IAM_SECRET_ACCESS_KEY'] end
  return access_key,secret_key, opts[:aws_user]
end

def initialize_aws(access_key,secret_key,region)
 AWS.config({
    :access_key_id => access_key,
    :secret_access_key => secret_key,
    :region => region 
  })
end
