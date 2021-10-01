# Many of these shit has to go to CSV. How to avoid that?
module CmIamConfig
  # TODO: where to put this
  IAM_GROUPS = ["dev","ops"]
  IAM_MY_user_name = "ops_gautam"
  # todo: Remove this!
  CREDS_DIR_TAG = "auth"
  GATEWAY_KEYS_DIR_PREFIX = "gateway-keys"
  GATEWAY_SSH_PRIV_NAME = "gateway_key"
  # TODO: Change it back to home directory. Not working in cygwin
  DEPLOYMENT_ENVS = ["staging", "production","productioneu", "demo", "standby", "development", "test", "performance", "opstesting", "scanner", "training","releasestaging1","releasestaging2", "generalelectric", "veteransadmin", "nch"]
  CRED_STORE_BUCKET_PREFIX = "chronus-mentor-ks"
  GATEWAY_DEPLOY_USER = "deploy"
  PRODUCTION_APP_SSH_KEY_NAME = "chronus-ec2-keypair"
  PREV_AWS_CREDS_FILENAME = "prev-aws-creds"
  CURR_AWS_CREDS_FILENAME = "curr-aws-creds"
  GOOGLE_AUTHENTICATOR_CONFIG_FILE = ".google_authenticator"
  SUPPRESS_ERROR_STRING = "2>/dev/null || :"
  GOOGLE_AUTHENTICATOR_BIN_PATH = "/usr/local/bin/google-authenticator"
  REDIRECT_STDOUT_TO_STDERR = "1>&2"
  DEFAULT_AWS_REGION = "us-east-1"
  USERNAME_CONVENTIONS = {
    'dev' => {
      iam_group: "Developers",
      iam_creds_suffix: "dev",
      iam_creds_prefix: "dev",
      gateway_ubuntu_group: "dev",
      env_ubuntu_group: "sudo"

    },
    'ops' => {
      iam_group: "ops",
      iam_creds_suffix: "ops",
      iam_creds_prefix: "ops",
      gateway_ubuntu_group: "ops",
      env_ubuntu_group: "sudo"
    }
  }
  VALID_GATEWAY_ENVS = ["staging","production"]
  USER_ENV_KEYS_S3_FOLDER_NAME = "prodenv_ssh_keys"
  # The local folder would be in HOME dir
  USER_ENV_KEYS_LOCAL_FOLDER_NAME = USER_ENV_KEYS_S3_FOLDER_NAME
  APP_SSH_KEY_NAME_SUFFIX = "app-ssh-key"
  APP_SSH_KEY_LOCAL_FOLDER_NAME = "app_ssh_keys"
  GATEWAY_ENV_KEYS_S3_FOLDER_NAME = "gateway_ssh_keys"
  GATEWAY_KEYS_SUFFIX = "ssh-key"
  GATEWAY_ENV_NAME_FILE = "/cm_gateway_env_name"

  # The user management scripts exclude the below environments
  STAGING_ENVS = ["staging", "standby", "performance", "opstesting","training","releasestaging1","releasestaging2"]

  ENV_CREDS_S3_OBJ_NAME = "env-creds"
  SUPER_CONSOLE_PASS_PHRASE_NAME = "SUPER_CONSOLE_PASS_PHRASE"
  TEMP_S3_BUCKET_FOR_GATEWAY_USER_KEYS = "chronus-mentor-ks-ops"
end
